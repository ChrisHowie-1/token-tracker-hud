#!/usr/bin/env python3
"""
Official Antigravity Quota Sync & Dual-Stack LAN Daemon
Queries the official Antigravity CLI (`agy -p "/usage" --output-format json`) for exact
live quotas (Gemini + Claude/GPT pools) at zero token cost, updates local_ai_stats.json
atomically under flock, and serves telemetry + macOS app auto-updates over dual-stack LAN (port 9587).
"""

import datetime
import fcntl
import glob
import hashlib
import http.server
import json
import os
import re
import shutil
import socket
import subprocess
import tempfile
import threading
import time

SOURCE_STATS = "/Users/chrishowie/.gemini/antigravity/local_ai_stats.json"
TRANSCRIPTS_GLOB = "/Users/chrishowie/.gemini/antigravity/brain/*/.system_generated/logs/transcript.jsonl"
PROJECT_BUILD_DIR = "/Users/chrishowie/Antigravity/Personal/Misc/TokenTrackerHUD/build"
APP_BINARY_PATH = os.path.join(PROJECT_BUILD_DIR, "TokenTrackerHUD.app", "Contents", "MacOS", "TokenTrackerHUD")
APP_ZIP_PATH = os.path.join(PROJECT_BUILD_DIR, "TokenTrackerHUD.app.zip")
AGY_BIN = os.environ.get("AGY_BIN", "/Users/chrishowie/.local/bin/agy")
PORT = 9587

_APP_HASH_LOCK = threading.Lock()
_APP_HASH_CACHE = {
    "mtime": 0.0,
    "size": 0,
    "sha256": "",
}
_TRANSCRIPT_CACHE = {
    "path": "",
    "mtime": 0.0,
    "model": "",
    "pool": "gemini",
}


def fetch_official_quota():
    """Fetch official quota summary via `agy -p /usage --output-format json` (zero-token CLI call)."""
    agy_path = AGY_BIN if os.path.isfile(AGY_BIN) else shutil.which("agy")
    if not agy_path:
        return None
    env = os.environ.copy()
    env.setdefault("HOME", "/Users/chrishowie")
    try:
        res = subprocess.run(
            [agy_path, "-p", "/usage", "--output-format", "json"],
            capture_output=True,
            text=True,
            timeout=20,
            env=env,
        )
        if res.returncode != 0 or not res.stdout:
            return None
        payload = json.loads(res.stdout)
        if payload.get("status") != "SUCCESS":
            return None
        cmd_data = payload.get("command", {}).get("data")
        if cmd_data and cmd_data.get("groups"):
            return cmd_data
    except Exception:
        pass
    return None


def _parse_reset_ts(reset_iso):
    if not reset_iso:
        return None
    try:
        dt = datetime.datetime.fromisoformat(reset_iso.replace("Z", "+00:00"))
        return dt.timestamp()
    except Exception:
        return None


def _parse_countdown(desc):
    if not desc:
        return ""
    m = re.search(r"refresh(?:es)? in ([^.]+)", desc)
    if m:
        return m.group(1).strip()
    return ""


def _atomic_update_stats(updates: dict):
    os.makedirs(os.path.dirname(SOURCE_STATS), exist_ok=True)
    lock_file = SOURCE_STATS + ".lock"
    try:
        with open(lock_file, "a") as lock_f:
            fcntl.flock(lock_f, fcntl.LOCK_EX)
            try:
                live_data = {}
                if os.path.exists(SOURCE_STATS):
                    try:
                        with open(SOURCE_STATS, "r") as f:
                            live_data = json.load(f)
                    except Exception:
                        live_data = {}
                live_data.update(updates)
                live_data["last_updated"] = time.time()
                stats_dir = os.path.dirname(SOURCE_STATS)
                fd, tmp_path = tempfile.mkstemp(dir=stats_dir, suffix=".tmp")
                try:
                    with os.fdopen(fd, "w") as tmp_f:
                        json.dump(live_data, tmp_f, indent=2)
                    os.replace(tmp_path, SOURCE_STATS)
                except Exception:
                    if os.path.exists(tmp_path):
                        os.unlink(tmp_path)
                    raise
            finally:
                fcntl.flock(lock_f, fcntl.LOCK_UN)
    except Exception:
        pass


def detect_active_pool() -> tuple:
    """Detect active Antigravity model and quota pool ('gemini' vs '3p') from newest transcript tail."""
    try:
        paths = glob.glob(TRANSCRIPTS_GLOB)
        if not paths:
            return _TRANSCRIPT_CACHE["pool"], _TRANSCRIPT_CACHE["model"]

        newest_path = ""
        newest_mtime = -1.0
        for p in paths:
            try:
                mt = os.path.getmtime(p)
                if mt > newest_mtime:
                    newest_mtime = mt
                    newest_path = p
            except OSError:
                continue

        if not newest_path:
            return _TRANSCRIPT_CACHE["pool"], _TRANSCRIPT_CACHE["model"]

        if newest_path == _TRANSCRIPT_CACHE["path"] and newest_mtime == _TRANSCRIPT_CACHE["mtime"]:
            return _TRANSCRIPT_CACHE["pool"], _TRANSCRIPT_CACHE["model"]

        detected_model = ""
        with open(newest_path, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            f.seek(max(0, size - 32768))
            chunk = f.read().decode("utf-8", errors="replace")

        for line in reversed(chunk.splitlines()):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            m_val = obj.get("model")
            if isinstance(m_val, str) and m_val.strip():
                detected_model = m_val.strip()
                break

        if detected_model:
            lower_m = detected_model.lower()
            pool = "3p" if any(tok in lower_m for tok in ("claude", "gpt", "opus", "sonnet")) else "gemini"
        else:
            pool = _TRANSCRIPT_CACHE["pool"]
            detected_model = _TRANSCRIPT_CACHE["model"]

        _TRANSCRIPT_CACHE["path"] = newest_path
        _TRANSCRIPT_CACHE["mtime"] = newest_mtime
        _TRANSCRIPT_CACHE["model"] = detected_model
        _TRANSCRIPT_CACHE["pool"] = pool
        return pool, detected_model
    except Exception:
        return _TRANSCRIPT_CACHE["pool"], _TRANSCRIPT_CACHE["model"]


def _select_active_lowest(active_pool: str, gemini_candidates: list, three_p_candidates: list):
    candidates = three_p_candidates if (active_pool == "3p" and three_p_candidates) else gemini_candidates
    if not candidates:
        candidates = gemini_candidates or three_p_candidates
    if not candidates:
        return None
    return min(candidates, key=lambda x: x[0])


def sync_loop():
    consecutive_failures = 0
    next_quota_sync = 0.0
    last_pool_written = None
    last_model_written = None
    cached_gemini_candidates = []
    cached_three_p_candidates = []

    while True:
        now = time.time()
        try:
            active_pool, active_model = detect_active_pool()

            if now >= next_quota_sync:
                official = fetch_official_quota()
                if official:
                    consecutive_failures = 0
                    next_quota_sync = time.time() + 30.0
                    quota_updates = {
                        "official_sync_status": "LIVE_RPC_SYNC",
                        "official_sync_source": "agy_cli",
                        "active_pool": active_pool,
                        "active_cloud_model": active_model,
                    }
                    groups = official.get("groups") or official.get("response", {}).get("groups", [])
                    gemini_candidates = []
                    three_p_candidates = []

                    for g in groups:
                        g_name = g.get("name") or g.get("displayName") or ""
                        for b in g.get("buckets", []):
                            b_id = b.get("id") or b.get("bucketId") or ""
                            rf = b.get("remaining_fraction") if "remaining_fraction" in b else b.get("remainingFraction")
                            pct = float(round(rf * 100)) if rf is not None else 100.0
                            reset_iso = b.get("reset_time") or b.get("resetTime")
                            reset_ts = _parse_reset_ts(reset_iso)
                            disabled = bool(b.get("disabled", False))
                            countdown_str = _parse_countdown(b.get("description") or "")

                            if b_id == "gemini-5h" or (g_name == "Gemini Models" and b.get("window") == "5h"):
                                quota_updates["five_hour_remaining_pct"] = pct
                                quota_updates["five_hour_refresh_time"] = countdown_str or "Ready"
                                quota_updates["five_hour_reset_timestamp"] = reset_ts or 0.0
                                gemini_candidates.append((pct, "(G5)"))
                            elif b_id == "gemini-weekly" or (g_name == "Gemini Models" and b.get("window") == "weekly"):
                                quota_updates["weekly_remaining_pct"] = pct
                                quota_updates["weekly_refresh_time"] = countdown_str or "Ready"
                                quota_updates["weekly_reset_timestamp"] = reset_ts or 0.0
                                gemini_candidates.append((pct, "(G7)"))
                            elif b_id == "3p-5h" or ("Claude" in g_name and b.get("window") == "5h"):
                                quota_updates["three_p_five_hour_remaining_pct"] = pct
                                quota_updates["three_p_five_hour_disabled"] = disabled
                                quota_updates["three_p_five_hour_refresh_time"] = "Weekly hit" if disabled else (countdown_str or "Ready")
                                quota_updates["three_p_five_hour_reset_timestamp"] = 0.0 if disabled else (reset_ts or 0.0)
                                if not disabled:
                                    three_p_candidates.append((pct, "(C5)"))
                            elif b_id == "3p-weekly" or ("Claude" in g_name and b.get("window") == "weekly"):
                                quota_updates["three_p_weekly_remaining_pct"] = pct
                                quota_updates["three_p_weekly_refresh_time"] = countdown_str or "Ready"
                                quota_updates["three_p_weekly_reset_timestamp"] = reset_ts or 0.0
                                three_p_candidates.append((pct, "(C7)"))

                    cached_gemini_candidates = gemini_candidates
                    cached_three_p_candidates = three_p_candidates
                    lowest = _select_active_lowest(active_pool, cached_gemini_candidates, cached_three_p_candidates)
                    if lowest:
                        quota_updates["lowest_overall_pct"] = lowest[0]
                        quota_updates["lowest_overall_tag"] = lowest[1]

                    _atomic_update_stats(quota_updates)
                    last_pool_written = active_pool
                    last_model_written = active_model
                else:
                    consecutive_failures += 1
                    next_quota_sync = time.time() + 15.0
                    stale_updates = {
                        "active_pool": active_pool,
                        "active_cloud_model": active_model,
                    }
                    if consecutive_failures >= 2:
                        stale_updates["official_sync_status"] = "STALE_RPC"
                    _atomic_update_stats(stale_updates)
                    last_pool_written = active_pool
                    last_model_written = active_model
            elif active_pool != last_pool_written or active_model != last_model_written:
                pool_updates = {
                    "active_pool": active_pool,
                    "active_cloud_model": active_model,
                }
                lowest = _select_active_lowest(active_pool, cached_gemini_candidates, cached_three_p_candidates)
                if lowest:
                    pool_updates["lowest_overall_pct"] = lowest[0]
                    pool_updates["lowest_overall_tag"] = lowest[1]
                _atomic_update_stats(pool_updates)
                last_pool_written = active_pool
                last_model_written = active_model
        except Exception:
            consecutive_failures += 1
            next_quota_sync = time.time() + 15.0
        time.sleep(2.0)


def _get_app_version_metadata():
    if not (os.path.exists(APP_BINARY_PATH) and os.path.exists(APP_ZIP_PATH)):
        return {"available": False}
    try:
        bin_stat = os.stat(APP_BINARY_PATH)
        zip_stat = os.stat(APP_ZIP_PATH)
        mtime = bin_stat.st_mtime
        size = bin_stat.st_size
        with _APP_HASH_LOCK:
            if _APP_HASH_CACHE["mtime"] != mtime or _APP_HASH_CACHE["size"] != size or not _APP_HASH_CACHE["sha256"]:
                h = hashlib.sha256()
                with open(APP_BINARY_PATH, "rb") as f:
                    for chunk in iter(lambda: f.read(65536), b""):
                        h.update(chunk)
                _APP_HASH_CACHE["mtime"] = mtime
                _APP_HASH_CACHE["size"] = size
                _APP_HASH_CACHE["sha256"] = h.hexdigest()
            sha256_hex = _APP_HASH_CACHE["sha256"]

        host_ip = os.environ.get("TOKEN_TRACKER_HOST", "192.168.32.90")
        return {
            "available": True,
            "binary_mtime": mtime,
            "binary_size": size,
            "binary_sha256": sha256_hex,
            "zip_size": zip_stat.st_size,
            "bundle_url": f"http://{host_ip}:{PORT}/app/bundle.zip",
        }
    except Exception as e:
        return {"available": False, "error": str(e)}


class StatsHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/stats", "/stats.json"):
            try:
                with open(SOURCE_STATS, "rb") as f:
                    data = f.read()
                self._send_bytes(200, "application/json", data)
                return
            except Exception as e:
                self._send_bytes(500, "application/json", json.dumps({"error": str(e)}).encode("utf-8"))
                return

        if path == "/app/version":
            meta = _get_app_version_metadata()
            self._send_bytes(200, "application/json", json.dumps(meta, indent=2).encode("utf-8"))
            return

        if path == "/app/bundle.zip":
            if os.path.exists(APP_ZIP_PATH):
                try:
                    with open(APP_ZIP_PATH, "rb") as f:
                        data = f.read()
                    self._send_bytes(200, "application/zip", data)
                    return
                except Exception as e:
                    self._send_bytes(500, "application/json", json.dumps({"error": str(e)}).encode("utf-8"))
                    return
            self._send_bytes(404, "application/json", b'{"error":"bundle.zip not built"}')
            return

        if path == "/health":
            self._send_bytes(200, "application/json", b'{"ok":true}')
            return

        self._send_bytes(404, "application/json", b'{"error":"not found"}')

    def _send_bytes(self, code: int, content_type: str, data: bytes):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        pass


class DualStackThreadingHTTPServer(http.server.ThreadingHTTPServer):
    address_family = socket.AF_INET6
    allow_reuse_address = True
    daemon_threads = True

    def server_bind(self):
        try:
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        except Exception:
            pass
        super().server_bind()


def run_server():
    try:
        with DualStackThreadingHTTPServer(("::", PORT), StatsHandler) as httpd:
            httpd.serve_forever()
    except Exception:
        http.server.ThreadingHTTPServer.allow_reuse_address = True
        with http.server.ThreadingHTTPServer(("0.0.0.0", PORT), StatsHandler) as httpd:
            httpd.serve_forever()


if __name__ == "__main__":
    t = threading.Thread(target=sync_loop, daemon=True)
    t.start()
    run_server()

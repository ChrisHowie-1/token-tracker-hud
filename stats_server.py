#!/usr/bin/env python3
"""
Official Antigravity Quota Sync & Dual-Stack LAN Daemon
Queries the official internal language_server RPC endpoint for exact live quotas
(Gemini + Claude/GPT pools) with zero-fork endpoint caching, updates local_ai_stats.json
atomically under flock, and serves telemetry + macOS app auto-updates over dual-stack LAN (port 9587).
"""

import datetime
import fcntl
import hashlib
import http.server
import json
import os
import re
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import urllib.request

SOURCE_STATS = "/Users/chrishowie/.gemini/antigravity/local_ai_stats.json"
PROJECT_BUILD_DIR = "/Users/chrishowie/Antigravity/Personal/Misc/TokenTrackerHUD/build"
APP_BINARY_PATH = os.path.join(PROJECT_BUILD_DIR, "TokenTrackerHUD.app", "Contents", "MacOS", "TokenTrackerHUD")
APP_ZIP_PATH = os.path.join(PROJECT_BUILD_DIR, "TokenTrackerHUD.app.zip")
PORT = 9587

_RPC_LOCK = threading.Lock()
_APP_HASH_LOCK = threading.Lock()
_CACHED_RPC = {
    "pid": None,
    "ports": [],
    "csrf_token": None,
}
_APP_HASH_CACHE = {
    "mtime": 0.0,
    "size": 0,
    "sha256": "",
}


def _discover_language_server():
    """Discover language_server PID, CSRF token, and listening localhost TCP ports (runs only on cache miss)."""
    try:
        ps_out = subprocess.check_output(["ps", "-axww", "-o", "pid=,command="], timeout=3).decode(errors="replace")
        pid = None
        csrf_token = None
        for line in ps_out.splitlines():
            if "language_server" in line and "--csrf_token" in line:
                parts = line.strip().split(None, 1)
                if len(parts) == 2:
                    m = re.search(r"--csrf_token\s+([^\s]+)", parts[1])
                    if m:
                        pid = parts[0]
                        csrf_token = m.group(1)
                        break

        if not pid or not csrf_token:
            return None, [], None

        lsof_out = subprocess.check_output(
            ["lsof", "-p", pid, "-a", "-iTCP", "-sTCP:LISTEN", "-P", "-n"],
            timeout=3,
        ).decode(errors="replace")
        ports = []
        for line in lsof_out.splitlines():
            m = re.search(r"127\.0\.0\.1:(\d+)\s+\(LISTEN\)", line)
            if m:
                ports.append(m.group(1))
        return pid, ports, csrf_token
    except Exception:
        return None, [], None


def _call_quota_rpc(ports, csrf_token):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    payload = json.dumps({"forceRefresh": True}).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Connect-Protocol-Version": "1",
        "x-codeium-csrf-token": csrf_token,
    }
    for p in ports:
        url = f"https://127.0.0.1:{p}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
        req = urllib.request.Request(url, data=payload, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=2.0) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode("utf-8"))
                    if data.get("response", {}).get("groups"):
                        return data, p
        except Exception:
            continue
    return None, None


def fetch_official_quota():
    """Fetch official quota summary using cached RPC port/token first, falling back to subprocess discovery only when needed."""
    with _RPC_LOCK:
        cached_ports = list(_CACHED_RPC["ports"])
        cached_token = _CACHED_RPC["csrf_token"]

    if cached_ports and cached_token:
        data, working_port = _call_quota_rpc(cached_ports, cached_token)
        if data:
            if cached_ports != [working_port]:
                with _RPC_LOCK:
                    _CACHED_RPC["ports"] = [working_port]
            return data

    pid, ports, csrf_token = _discover_language_server()
    if not ports or not csrf_token:
        with _RPC_LOCK:
            _CACHED_RPC["pid"] = None
            _CACHED_RPC["ports"] = []
            _CACHED_RPC["csrf_token"] = None
        return None

    data, working_port = _call_quota_rpc(ports, csrf_token)
    with _RPC_LOCK:
        if data and working_port:
            _CACHED_RPC["pid"] = pid
            _CACHED_RPC["ports"] = [working_port]
            _CACHED_RPC["csrf_token"] = csrf_token
        else:
            _CACHED_RPC["pid"] = None
            _CACHED_RPC["ports"] = []
            _CACHED_RPC["csrf_token"] = None
    return data


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
    if "refresh in " in desc:
        return desc.split("refresh in ")[-1].rstrip(".")
    return desc


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


def sync_loop():
    last_stale_mark = 0.0
    while True:
        try:
            official = fetch_official_quota()
            if official:
                quota_updates = {
                    "official_sync_status": "LIVE_RPC_SYNC",
                }
                groups = official.get("response", {}).get("groups", [])
                pool_candidates = []

                for g in groups:
                    g_name = g.get("displayName", "")
                    for b in g.get("buckets", []):
                        b_id = b.get("bucketId", "")
                        rf = b.get("remainingFraction")
                        pct = float(round(rf * 100)) if rf is not None else 100.0
                        countdown_str = _parse_countdown(b.get("description") or "")
                        reset_ts = _parse_reset_ts(b.get("resetTime"))

                        if b_id == "gemini-5h" or (g_name == "Gemini Models" and b.get("window") == "5h"):
                            quota_updates["five_hour_remaining_pct"] = pct
                            quota_updates["five_hour_refresh_time"] = countdown_str
                            if reset_ts:
                                quota_updates["five_hour_reset_timestamp"] = reset_ts
                            pool_candidates.append((pct, "(G5)"))
                        elif b_id == "gemini-weekly" or (g_name == "Gemini Models" and b.get("window") == "weekly"):
                            quota_updates["weekly_remaining_pct"] = pct
                            quota_updates["weekly_refresh_time"] = countdown_str
                            if reset_ts:
                                quota_updates["weekly_reset_timestamp"] = reset_ts
                            pool_candidates.append((pct, "(G7)"))
                        elif b_id == "3p-5h" or ("Claude" in g_name and b.get("window") == "5h"):
                            quota_updates["three_p_five_hour_remaining_pct"] = pct
                            quota_updates["three_p_five_hour_refresh_time"] = countdown_str
                            if reset_ts:
                                quota_updates["three_p_five_hour_reset_timestamp"] = reset_ts
                            pool_candidates.append((pct, "(C5)"))
                        elif b_id == "3p-weekly" or ("Claude" in g_name and b.get("window") == "weekly"):
                            quota_updates["three_p_weekly_remaining_pct"] = pct
                            quota_updates["three_p_weekly_refresh_time"] = countdown_str
                            if reset_ts:
                                quota_updates["three_p_weekly_reset_timestamp"] = reset_ts
                            pool_candidates.append((pct, "(C7)"))

                if pool_candidates:
                    lowest_pct, lowest_tag = min(pool_candidates, key=lambda x: x[0])
                    quota_updates["lowest_overall_pct"] = lowest_pct
                    quota_updates["lowest_overall_tag"] = lowest_tag

                _atomic_update_stats(quota_updates)
            else:
                now = time.time()
                if now - last_stale_mark >= 10.0:
                    _atomic_update_stats({"official_sync_status": "STALE_RPC"})
                    last_stale_mark = now
        except Exception:
            pass
        time.sleep(2.5)


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

#!/usr/bin/env python3
"""
Official Antigravity Quota Sync & LAN Daemon
Queries the official internal language_server RPC endpoint for exact live quotas
and streams them to iCloud Drive (stats.json) and local LAN (port 9587).
"""

import http.server
import socketserver
import json
import os
import shutil
import time
import threading
import subprocess
import re
import urllib.request
import ssl
import datetime

SOURCE_STATS = "/Users/chrishowie/.gemini/antigravity/local_ai_stats.json"
ICLOUD_STATS = "/Users/chrishowie/Library/Mobile Documents/com~apple~CloudDocs/Antigravity Projects/Misc/TokenTrackerHUD/stats.json"
PORT = 9587

def fetch_official_quota():
    try:
        ps = subprocess.check_output(['ps', 'aux']).decode()
        csrf_token = None
        for line in ps.splitlines():
            if 'language_server' in line and '--csrf_token' in line:
                m = re.search(r'--csrf_token\s+([^\s]+)', line)
                if m:
                    csrf_token = m.group(1)
                break

        if not csrf_token:
            return None

        lsof = subprocess.check_output(['lsof', '-c', 'language_', '-a', '-iTCP', '-sTCP:LISTEN', '-P', '-n']).decode()
        for line in lsof.splitlines():
            m = re.search(r'127\.0\.0\.1:(\d+)\s+\(LISTEN\)', line)
            if m:
                p = m.group(1)
                ctx = ssl.create_default_context()
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
                url = f'https://127.0.0.1:{p}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary'
                req = urllib.request.Request(
                    url,
                    data=json.dumps({'forceRefresh': True}).encode('utf-8'),
                    headers={
                        'Content-Type': 'application/json',
                        'Connect-Protocol-Version': '1',
                        'x-codeium-csrf-token': csrf_token
                    },
                    method='POST'
                )
                try:
                    with urllib.request.urlopen(req, context=ctx, timeout=2) as resp:
                        if resp.status == 200:
                            data = json.loads(resp.read().decode())
                            if data.get('response', {}).get('groups'):
                                return data
                except Exception:
                    pass
    except Exception:
        pass
    return None

def sync_loop():
    while True:
        try:
            official = fetch_official_quota()
            d = {}
            if os.path.exists(SOURCE_STATS):
                try:
                    with open(SOURCE_STATS, "r") as f:
                        d = json.load(f)
                except Exception:
                    pass

            if official:
                groups = official.get('response', {}).get('groups', [])
                for g in groups:
                    if g.get('displayName') == 'Gemini Models':
                        for b in g.get('buckets', []):
                            rf = b.get('remainingFraction')
                            pct = round(rf * 100) if rf is not None else 100.0
                            desc = b.get('description') or ''
                            reset_iso = b.get('resetTime')
                            reset_ts = None
                            if reset_iso:
                                try:
                                    dt = datetime.datetime.fromisoformat(reset_iso.replace("Z", "+00:00"))
                                    reset_ts = dt.timestamp()
                                except Exception:
                                    pass

                            # Extract clean refresh countdown string from description
                            countdown_str = desc
                            if 'refresh in ' in desc:
                                countdown_str = desc.split('refresh in ')[-1].rstrip('.')

                            if b.get('bucketId') == 'gemini-5h':
                                d['five_hour_remaining_pct'] = float(pct)
                                d['five_hour_refresh_time'] = countdown_str
                                if reset_ts:
                                    d['five_hour_reset_timestamp'] = reset_ts
                            elif b.get('bucketId') == 'gemini-weekly':
                                d['weekly_remaining_pct'] = float(pct)
                                d['weekly_refresh_time'] = countdown_str
                                if reset_ts:
                                    d['weekly_reset_timestamp'] = reset_ts

                d['official_sync_status'] = 'LIVE_RPC_SYNC'
                d['last_updated'] = time.time()

                # Write to local_ai_stats.json atomically
                tmp_path = SOURCE_STATS + ".tmp"
                with open(tmp_path, "w") as f:
                    json.dump(d, f, indent=2)
                os.replace(tmp_path, SOURCE_STATS)

                # Sync to iCloud Drive
                os.makedirs(os.path.dirname(ICLOUD_STATS), exist_ok=True)
                shutil.copy2(SOURCE_STATS, ICLOUD_STATS)
        except Exception:
            pass
        time.sleep(2.0)

class StatsHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/stats", "/stats.json"):
            try:
                with open(SOURCE_STATS, "rb") as f:
                    data = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
                return
        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        pass

def run_server():
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), StatsHandler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    t = threading.Thread(target=sync_loop, daemon=True)
    t.start()
    run_server()

# TokenTrackerHUD

A native macOS floating Liquid Glass HUD + menu bar app and Omarchy Wayland Quickshell bar widget displaying **live Antigravity AI quotas** (both **Gemini Models** and **Claude & GPT Models**) plus **Apple M3 Ultra local inference telemetry** streamed over dual-stack LAN from the Mac Studio (`192.168.32.90:9587`).

---

## Key Capabilities

- **Multi-Pool Official RPC Sync**: Queries Antigravity's internal Connect-RPC (`RetrieveUserQuotaSummary`) with zero-fork endpoint caching (`(pid, port, csrf_token)` cached in memory; re-discovered only on restart).
- **4-Bucket Quota Awareness**:
  - **Gemini Weekly `(G7)`** & **Gemini 5-Hour `(G5)`**
  - **Claude/GPT 5-Hour `(C5)`** & **Claude/GPT Weekly `(C7)`**
  - Top bar / Menu Bar badge automatically highlights whichever single bucket across all pools has the **lowest remaining percentage** (e.g. `🟢 73% (C5)`), pulsing `⚡️` during M3 Ultra local inference and showing `⚪️` when offline.
- **M3 Ultra Savings & Throughput Strip**: Displays live cumulative GBP savings (`£`), free local tokens processed, and active `oMLX`/Ollama tok/s speed.
- **Dual-Stack Threaded LAN Relay (`::` & `0.0.0.0` on `:9587`)**:
  - `GET /stats` — Live quota & M3 Ultra JSON payload
  - `GET /app/version` — Latest built `TokenTrackerHUD.app` binary SHA-256 & mtime
  - `GET /app/bundle.zip` — Zero-iCloud LAN auto-update archive verified via `CryptoKit` SHA-256
- **macOS AppKit Polish**: Left-click Menu Bar item toggles the Floating HUD; right-click opens the context menu; Compact Mode automatically surfaces the lowest remaining pool.
- **Omarchy Quickshell Integration**: `plugins/omarchy/antigravity.tokens/` provides `Panel.qml` and `FloatingHud.qml` with XHR timeouts, in-flight request guards, timestamp-driven countdowns, and `inotifywait` hot-reload deployment (`deploy_omarchy.sh`).

---

## Architecture

```
Antigravity Language Server + Local AI MCP (Mac Studio 192.168.32.90)
        │
        ├──► stats_server.py (Dual-stack ThreadingHTTPServer :9587, zero-fork RPC cache)
        │         ├── GET /stats           ──► Live JSON (Gemini + Claude/GPT + M3 Ultra)
        │         ├── GET /app/version     ──► Binary SHA-256 metadata
        │         └── GET /app/bundle.zip  ──► Signed macOS app bundle
        │
        ├──► macOS Clients (MacBook Pro)
        │         ├── TokenStatsWatcher.swift (1.5s poll + live timestamp countdowns)
        │         └── AutoUpdater.swift       (SHA-256 verified LAN self-update)
        │
        └──► Linux Clients (Omarchy Dell XPS & MacBook)
                  └── Quickshell Panel.qml    (1.5s poll + offline guard + Syncthing sync)
```

---

## Build & Deploy (on Mac Studio)

```bash
cd /Users/chrishowie/Antigravity/Personal/Misc/TokenTrackerHUD
./build.sh
```

`build.sh` compiles the arm64 macOS app, packages `build/TokenTrackerHUD.app.zip` for LAN auto-updates, syncs `stats_server.py` to `~/.gemini/antigravity/scripts/stats_server.py`, restarts `com.antigravity.tokentracker.server`, and syncs QML files to any online Omarchy laptops without restarting Quickshell.

### Verify Live Endpoints

```bash
curl -s http://192.168.32.90:9587/stats | jq .
curl -s http://127.0.0.1:9587/stats | jq .
curl -s "http://[::1]:9587/app/version" | jq .
```

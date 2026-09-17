# TokenTrackerHUD

A native macOS floating HUD + menu bar app that displays **live Gemini Models quota** directly sourced from Antigravity's internal language server RPC — matching the official "Models & Usage" screen exactly.

---

## Features

- **Real-time quota tracking** — polls Antigravity's internal Connect-RPC endpoint every 2 seconds with `forceRefresh: true`
- **Two quota tiles**:
  - **Weekly Limit Remaining** — `gemini-weekly` bucket
  - **Five Hour Limit Remaining** — `gemini-5h` bucket
- **Live countdown timers** — ticks down to next reset from ISO8601 `resetTime`
- **Colour-coded progress bars** — green → orange → red based on remaining %
- **Compact / expanded toggle** — animated resize anchored to top-right corner
- **Always-on-top floating panel** — `NSPanel`, non-activating, draggable anywhere on screen
- **Menu bar icon** — click to show/hide; right-click for options
- **Launch at login** — via `SMAppService.mainApp.register()`, togglable from menu
- **LAN-first, iCloud fallback** — MacBook polls `192.168.32.90:9587`; falls back to iCloud Drive JSON if unreachable
- **No Dock icon** — `LSUIElement = true`

---

## Architecture

```
Antigravity Language Server (Mac Studio)
        │
        │  Connect-RPC (localhost:<dynamic port>)
        │  x-codeium-csrf-token (discovered from process args)
        ▼
  stats_server.py  (runs as launchd daemon on Mac Studio)
        │
        ├──► local_ai_stats.json  (local file)
        ├──► iCloud Drive stats.json  (sync fallback)
        └──► HTTP :9587  (LAN endpoint, primary)
                │
                ▼
     TokenStatsWatcher.swift  (polls every 1.5s)
                │
                ▼
       FloatingHUDView (SwiftUI)
```

**Why a relay daemon?** The Antigravity language server only listens on `localhost` on Mac Studio. The MacBook cannot call it directly — the daemon bridges the gap over LAN.

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| macOS | 13.0 Ventura or later (arm64) |
| Mac Studio | Running Antigravity (provides the language server) |
| Python | 3.10+ (for `stats_server.py`) |

---

## Setup

### 1. Build the app

```bash
cd TokenTrackerHUD
chmod +x build.sh
./build.sh
```

The compiled `.app` lands in `build/TokenTrackerHUD.app`. Ad-hoc signed, ready to run.

> **Note:** `build.sh` compiles in `/tmp` to avoid iCloud xattr restrictions, then copies the bundle into the workspace.

### 2. Install the app

```bash
cp -R build/TokenTrackerHUD.app /Applications/
open /Applications/TokenTrackerHUD.app
```

Or run directly from `build/` for development.

### 3. Set up the stats relay daemon (on Mac Studio)

The daemon discovers the CSRF token and RPC port dynamically at runtime — no config needed.

```bash
# Copy daemon script to a stable path
cp stats_server.py ~/.gemini/antigravity/scripts/stats_server.py

# Install the launchd plist
cp com.antigravity.tokentracker.app.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.antigravity.tokentracker.app.plist
```

Verify it's running:

```bash
curl -s http://127.0.0.1:9587/stats | python3 -m json.tool
```

### 4. Enable launch at login

Click the menu bar icon → **Launch at Login**. Uses `SMAppService` — no LaunchAgent plist required on the client.

---

## File Structure

```
TokenTrackerHUD/
├── Sources/
│   ├── main.swift               # App entry point
│   ├── AppDelegate.swift        # Menu bar, SMAppService, window lifecycle
│   ├── FloatingHUDView.swift    # Main SwiftUI HUD UI
│   ├── FloatingHUDWindow.swift  # NSPanel chrome (borderless, draggable)
│   ├── TokenModel.swift         # Codable struct mapping JSON → Swift
│   └── TokenStatsWatcher.swift  # ObservableObject, LAN + iCloud polling
├── stats_server.py              # Relay daemon (runs on Mac Studio)
├── com.antigravity.tokentracker.app.plist  # launchd plist for daemon
├── Info.plist                   # Bundle metadata (LSUIElement, bundle ID)
├── build.sh                     # One-shot build script (swiftc, ad-hoc sign)
└── .gitignore
```

---

## How Percentages Are Calculated

The daemon calls the RPC with `forceRefresh: true` and reads `remainingFraction` directly from the response — the same field the official Antigravity "Models & Usage" screen reads. No estimation, no token counting.

```
displayPct = round(remainingFraction * 100)
```

This matches `Math.round(remainingFraction * 100)` in Antigravity's front-end exactly.

---

## Security

- **No hardcoded secrets.** The CSRF token is discovered at runtime from process args.
- **No API keys committed.** The daemon authenticates using the token Antigravity itself generates.
- **LAN only.** The relay daemon binds to `0.0.0.0:9587` on the local network — not exposed externally.

---

## Design Notes

- Solid dark background (`#1A1A1E`) chosen over `NSVisualEffectView` vibrancy — vibrancy materials become unreadable on light wallpapers.
- Drag implemented via a custom `DragAreaNSView` calling `window.performDrag(with:)` — required because SwiftUI gesture recognisers intercept `mouseDown` before `NSPanel`'s built-in drag.
- Window resize on compact toggle uses `NSAnimationContext` anchored to the top-right corner so the panel doesn't jump.
- Build must happen in `/tmp` — `codesign` rejects iCloud Drive paths due to extended attributes.

---

## License

MIT — see [LICENSE](LICENSE).

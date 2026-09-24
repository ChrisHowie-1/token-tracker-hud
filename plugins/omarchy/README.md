# Omarchy Linux Token Tracker Plugin

Official Omarchy / Quickshell plugin for live Gemini quota tracking, replicating the macOS TokenTrackerHUD experience directly in the Omarchy top bar.

## Features
- **Top Bar Integration**: Displays status indicator (`🟢` idle / `⚡️` inferencing), real-time quota remaining (`81%`), and dynamic limit tag (`(5)` or `(7)` reflecting whichever window is more constrained).
- **Matching Color Palette**: Indicator tag strictly matches the `🟢` Apple emoji green shade (`#70c040`) and dynamically transitions to amber (`#ff9433`) or red (`#ff4d4d`) as limits deplete.
- **Two-Card Flyout Panel**: Clicking the widget opens Omarchy's native `KeyboardPanel` with liquid-glass progress tubes and refresh countdown timers for both 5-Hour and Weekly limits.
- **Network Resilient**: Continuously streams telemetry from the Mac Studio relay (`http://192.168.32.90:9587/stats`).

## Installation on Omarchy Linux
1. Copy the plugin directory:
   ```bash
   mkdir -p ~/.config/omarchy/plugins/antigravity.tokens
   cp manifest.json Panel.qml ~/.config/omarchy/plugins/antigravity.tokens/
   ```
2. Place the widget on the top bar:
   ```bash
   omarchy bar put antigravity.tokens --after hass
   ```

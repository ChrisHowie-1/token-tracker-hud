#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="TokenTrackerHUD"
TMP_APP="/tmp/$APP_NAME.app"
BUILD_DIR="$DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
APP_ZIP="$BUILD_DIR/$APP_NAME.app.zip"
LIVE_STATS_SERVER="/Users/chrishowie/.gemini/antigravity/scripts/stats_server.py"

echo "=== Building $APP_NAME (Headless-Clean Build & LAN Bundle Packaging) ==="

rm -rf "$TMP_APP" "$BUILD_DIR"
mkdir -p "$TMP_APP/Contents/MacOS"
mkdir -p "$TMP_APP/Contents/Resources"
mkdir -p "$BUILD_DIR"

cp "$DIR/Info.plist" "$TMP_APP/Contents/Info.plist"

SWIFT_SOURCES=(
    "$DIR/Sources/TokenModel.swift"
    "$DIR/Sources/TokenStatsWatcher.swift"
    "$DIR/Sources/AutoUpdater.swift"
    "$DIR/Sources/FloatingHUDView.swift"
    "$DIR/Sources/FloatingHUDWindow.swift"
    "$DIR/Sources/AppDelegate.swift"
    "$DIR/Sources/main.swift"
)

echo "Compiling Swift sources..."
swiftc \
    -O \
    -target arm64-apple-macosx13.0 \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Combine \
    -framework CryptoKit \
    "${SWIFT_SOURCES[@]}" \
    -o "$TMP_APP/Contents/MacOS/$APP_NAME"

chmod +x "$TMP_APP/Contents/MacOS/$APP_NAME"
xattr -cr "$TMP_APP"

echo "Ad-hoc code signing app bundle..."
codesign --force --deep --sign - "$TMP_APP"

echo "Staging app bundle & creating LAN auto-update archive ($APP_ZIP)..."
cp -R "$TMP_APP" "$APP_BUNDLE"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$APP_ZIP"

if [ -d "/Applications/$APP_NAME.app" ]; then
    echo "Updating installed /Applications/$APP_NAME.app..."
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$TMP_APP" "/Applications/$APP_NAME.app"
fi

if [ -d "$(dirname "$LIVE_STATS_SERVER")" ]; then
    echo "Syncing authoritative stats_server.py to $LIVE_STATS_SERVER..."
    cp "$DIR/stats_server.py" "$LIVE_STATS_SERVER"
    chmod +x "$LIVE_STATS_SERVER"
    launchctl kickstart -k "gui/$(id -u)/com.antigravity.tokentracker.server" 2>/dev/null || true
fi

rm -rf "$TMP_APP"
echo "Build complete: $APP_BUNDLE (LAN Zip: $APP_ZIP)"

if [ -f "$DIR/deploy_omarchy.sh" ]; then
    "$DIR/deploy_omarchy.sh" || true
fi

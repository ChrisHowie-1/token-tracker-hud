#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="TokenTrackerHUD"
TMP_APP="/tmp/$APP_NAME.app"
BUILD_DIR="$DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=== Building $APP_NAME according to Apple HIG & macOS Standards ==="

rm -rf "$TMP_APP" "$BUILD_DIR"
mkdir -p "$TMP_APP/Contents/MacOS"
mkdir -p "$TMP_APP/Contents/Resources"
mkdir -p "$BUILD_DIR"

cp "$DIR/Info.plist" "$TMP_APP/Contents/Info.plist"

SWIFT_SOURCES=(
    "$DIR/Sources/TokenModel.swift"
    "$DIR/Sources/TokenStatsWatcher.swift"
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
    "${SWIFT_SOURCES[@]}" \
    -o "$TMP_APP/Contents/MacOS/$APP_NAME"

chmod +x "$TMP_APP/Contents/MacOS/$APP_NAME"
xattr -cr "$TMP_APP"

echo "Ad-hoc code signing app bundle..."
codesign --force --deep --sign - "$TMP_APP"

echo "Deploying to workspace..."
cp -R "$TMP_APP" "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"

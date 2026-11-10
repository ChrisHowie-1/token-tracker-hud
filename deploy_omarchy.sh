#!/usr/bin/env bash
# ==============================================================================
# Multi-Device Omarchy Parallel Deployment Script (Client Display Widgets Only)
# Syncs Quickshell QML bar widget files to online Omarchy laptops; relies on
# Omarchy's native inotifywait plugin hot-reload + Syncthing peer propagation.
# ==============================================================================

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_SRC="$DIR/plugins/omarchy/antigravity.tokens"
TARGET_DIR="~/.config/omarchy/plugins/antigravity.tokens"

if [ ! -d "$PLUGIN_SRC" ]; then
    echo "[-] Error: Plugin directory $PLUGIN_SRC not found."
    exit 1
fi

# Target definitions: Host Alias | User@Host | Display Name
TARGETS=(
    "omarchy-apple|chris@192.168.32.183|MacBook 2014 (omarchy-apple)"
    "omarchy-dell|cjh@192.168.32.223|Dell XPS (omarchy-dell)"
)

echo "=== Deploying Token Tracker QML Widget to Omarchy Clients ==="

for entry in "${TARGETS[@]}"; do
    IFS="|" read -r SSH_HOST SSH_TARGET DISPLAY_NAME <<< "$entry"
    echo -n "Checking $DISPLAY_NAME ($SSH_TARGET)... "

    if ssh -i ~/.ssh/id_ed25519 -o BatchMode=yes -o ConnectTimeout=2 "$SSH_TARGET" "true" 2>/dev/null; then
        echo "ONLINE"
        echo "  -> Syncing QML plugin files (hot-reloaded automatically via inotifywait)..."
        ssh -i ~/.ssh/id_ed25519 "$SSH_TARGET" "mkdir -p $TARGET_DIR"
        scp -i ~/.ssh/id_ed25519 -r "$PLUGIN_SRC/"* "$SSH_TARGET:$TARGET_DIR/"
        echo "  [✓] $DISPLAY_NAME updated cleanly."
    else
        echo "OFFLINE (will sync via Syncthing or next deploy)"
    fi
done

echo "=== Deployment cycle complete ==="

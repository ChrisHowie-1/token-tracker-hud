#!/usr/bin/env bash
# ==============================================================================
# Multi-Device Omarchy Parallel Deployment Script
# Automatically deploys Quickshell token tracker plugins to all Omarchy laptops.
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

echo "=== Deploying Token Tracker Plugin to Omarchy Devices ==="

for entry in "${TARGETS[@]}"; do
    IFS="|" read -r SSH_HOST SSH_TARGET DISPLAY_NAME <<< "$entry"
    echo -n "Checking $DISPLAY_NAME ($SSH_HOST)... "

    if ssh -i ~/.ssh/id_ed25519 -o BatchMode=yes -o ConnectTimeout=3 "$SSH_HOST" "true" 2>/dev/null; then
        echo "ONLINE"
        echo "  -> Syncing QML plugin files..."
        ssh -i ~/.ssh/id_ed25519 "$SSH_HOST" "mkdir -p $TARGET_DIR"
        scp -i ~/.ssh/id_ed25519 -r "$PLUGIN_SRC/"* "$SSH_HOST:$TARGET_DIR/"
        echo "  -> Reloading Quickshell..."
        ssh -i ~/.ssh/id_ed25519 "$SSH_HOST" "pkill quickshell || true"
        echo "  [✓] $DISPLAY_NAME successfully updated."
    else
        echo "OFFLINE (will receive update upon next sync/wake)"
    fi
done

echo "=== Deployment cycle complete ==="

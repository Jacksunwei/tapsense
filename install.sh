#!/bin/bash
set -euo pipefail

# TapSense Production Installer
# This script installs TapSense via Homebrew Cask.

echo "🏥 TapSense Installer"

if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install it first: https://brew.sh"
    exit 1
fi

echo "==> Adding jacksunwei/tap..."
brew tap jacksunwei/tap || true

echo "==> Installing TapSense..."
# Note: This requires the 'tapsense' cask to be present in the tap.
# If the tap is new, we use the direct URL from GitHub Releases as a fallback.
if brew install --cask tapsense 2>/dev/null; then
    echo "✅ TapSense installed successfully!"
else
    echo "==> Falling back to latest GitHub Release..."
    LATEST_URL=$(curl -s https://api.github.com/repos/Jacksunwei/tapsense/releases/latest | grep "browser_download_url.*TapSense.app.zip" | cut -d : -f 2,3 | tr -d \" | xargs)
    
    if [ -z "$LATEST_URL" ]; then
        echo "❌ Could not find a release. Please build from source using ./build.sh"
        exit 1
    fi

    TEMP_DIR=$(mktemp -d)
    curl -L "$LATEST_URL" -o "$TEMP_DIR/TapSense.app.zip"
    unzip -q "$TEMP_DIR/TapSense.app.zip" -d "/Applications"
    echo "✅ TapSense.app installed to /Applications!"
fi

echo ""
echo "Next steps:"
echo "1. Run this to fix the macOS 'Damaged App' warning:"
echo "   sudo xattr -rd com.apple.quarantine /Applications/TapSense.app"
echo "2. Open /Applications/TapSense.app"
echo "3. In VS Code, install the TapSense extension (tapsense-vscode.vsix from releases)"

#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ROOT="$ROOT/dist/TapSense.app"
CONTENTS="$APP_ROOT/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "==> Building release binaries"
(cd "$ROOT/tapsense-daemon" && swift build -c release)
(cd "$ROOT/tapsense-app" && swift build -c release)

echo "==> Assembling app bundle"
rm -rf "$APP_ROOT"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT/tapsense-app/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/tapsense-app/.build/release/TapSense" "$MACOS_DIR/TapSense"
cp "$ROOT/tapsense-daemon/.build/release/TapSenseDaemon" "$RESOURCES_DIR/TapSenseDaemon"
cp -R "$ROOT/tapsense-daemon/.build/release/TapSenseDaemon_TapSenseCore.bundle" "$RESOURCES_DIR/"
chmod +x "$MACOS_DIR/TapSense" "$RESOURCES_DIR/TapSenseSidecar"

echo "==> Bundle ready"
echo "    $APP_ROOT"

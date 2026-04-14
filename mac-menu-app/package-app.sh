#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ROOT="$ROOT/dist/KnockMenu.app"
CONTENTS="$APP_ROOT/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "==> Building release binaries"
(cd "$ROOT/knock-sidecar" && swift build -c release)
(cd "$ROOT/mac-menu-app" && swift build -c release)

echo "==> Assembling app bundle"
rm -rf "$APP_ROOT"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT/mac-menu-app/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/mac-menu-app/.build/release/KnockMenuApp" "$MACOS_DIR/KnockMenuApp"
cp "$ROOT/knock-sidecar/.build/release/KnockSidecar" "$RESOURCES_DIR/KnockSidecar"
chmod +x "$MACOS_DIR/KnockMenuApp" "$RESOURCES_DIR/KnockSidecar"

echo "==> Bundle ready"
echo "    $APP_ROOT"

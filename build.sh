#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "==> Building knock-sidecar (Swift)..."
cd "$ROOT/knock-sidecar"
swift build -c release

echo ""
echo "==> Building vscode-extension (TypeScript)..."
cd "$ROOT/vscode-extension"
npm install
npx tsc -p ./

echo ""
echo "==> Building mac-menu-app (Swift)..."
cd "$ROOT/mac-menu-app"
swift build -c release

echo ""
echo "==> Assembling bundled app"
cd "$ROOT/mac-menu-app"
./package-app.sh

echo ""
echo "==> Build complete!"
echo "    Sidecar binary: $ROOT/knock-sidecar/.build/release/KnockSidecar"
echo "    Extension output: $ROOT/vscode-extension/out/"
echo "    Menu app executable: $ROOT/mac-menu-app/.build/release/KnockMenuApp"
echo "    Bundled app: $ROOT/dist/KnockMenu.app"

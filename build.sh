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
echo "==> Build complete!"
echo "    Sidecar binary: $ROOT/knock-sidecar/.build/release/KnockSidecar"
echo "    Extension output: $ROOT/vscode-extension/out/"

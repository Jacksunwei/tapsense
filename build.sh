#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "==> Building tapsense-sidecar (Swift)..."
cd "$ROOT/tapsense-sidecar"
xcrun coremlc compile Sources/TapSenseCore/tap_model.mlpackage Sources/TapSenseCore
swift build -c release

echo ""
echo "==> Building tapsense-vscode (TypeScript)..."
cd "$ROOT/tapsense-vscode"
npm install
npx tsc -p ./

echo ""
echo "==> Building tapsense-app (Swift)..."
cd "$ROOT/tapsense-app"
swift build -c release

echo ""
echo "==> Assembling bundled app"
cd "$ROOT/tapsense-app"
./package-app.sh

echo ""
echo "==> Build complete!"
echo "    Sidecar binary: $ROOT/tapsense-sidecar/.build/release/TapSenseSidecar"
echo "    Extension output: $ROOT/tapsense-vscode/out/"
echo "    Menu app executable: $ROOT/tapsense-app/.build/release/TapSenseApp"
echo "    Bundled app: $ROOT/dist/TapSense.app"

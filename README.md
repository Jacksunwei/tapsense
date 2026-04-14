# vscode-knock-demo

Prototype monorepo for a MacBook knock-triggered VS Code notification.

## Projects

- `vscode-extension/` - VS Code extension in TypeScript
- `knock-sidecar/` - macOS sidecar binary in Swift

## Demo goal

When the sidecar emits a `double_knock` event, the extension pops a VS Code notification:

> Knock knock detected!

## Current prototype status

- VS Code extension is wired and can spawn the sidecar, parse JSON lines, and show notifications.
- Sidecar supports `--simulate` mode today for a reliable local demo.
- Sidecar also includes a best-effort Apple Silicon private HID path using `IOKit` matching for usage page `0xFF00` and usage `0x03`.
- Real sensor mode is still experimental. On some machines the private device may not be exposed or may require additional privileges / different matching logic.

## Repo layout

```text
vscode-knock-demo/
├── README.md
├── docs/
├── knock-sidecar/
└── vscode-extension/
```

## Design docs

- `docs/architecture.md` - overall system design and event flow
- `docs/vscode-extension.md` - how the extension starts the sidecar and handles events
- `docs/knock-sidecar.md` - how the sidecar is structured and how knock detection works
- `docs/compatibility.md` - provisional hardware compatibility matrix for the private sensor path

## Installation

### Prerequisites

- macOS on Apple Silicon
- Xcode Command Line Tools (`xcode-select --install`)
- Node.js 20+
- npm
- VS Code

### Clone and install

```bash
git clone <your-repo-url> ~/GitHub/vscode-knock-demo
cd ~/GitHub/vscode-knock-demo
./build.sh
```

This installs extension dependencies, builds the Swift sidecar, and compiles the extension.

## Getting started

Fastest path for the first demo:

```bash
cd ~/GitHub/vscode-knock-demo
./build.sh
code .
```

Then:

1. In VS Code, open the repo root.
2. Press `F5` to launch the Extension Development Host.
3. In the Extension Development Host, run `Knock: Start Listening`.
4. Keep `knock.simulateMode` enabled.
5. Wait a few seconds for the simulated double-knock.
6. You should see `Knock knock detected!`.

## One-command build

```bash
cd ~/GitHub/vscode-knock-demo
./build.sh
```

## 1) Build the sidecar

```bash
cd ~/GitHub/vscode-knock-demo/knock-sidecar
swift build -c release
```

Binary path:

```bash
~/GitHub/vscode-knock-demo/knock-sidecar/.build/release/KnockSidecar
```

### Quick sidecar test

Simulation mode:

```bash
cd ~/GitHub/vscode-knock-demo/knock-sidecar
.build/release/KnockSidecar --simulate
```

You should see JSON events, including periodic `double_knock` events.

Experimental real mode:

```bash
cd ~/GitHub/vscode-knock-demo/knock-sidecar
.build/release/KnockSidecar
```

If the private Apple Silicon accelerometer is not visible, the sidecar exits and tells you to use simulate mode.

## 2) Build the VS Code extension

```bash
cd ~/GitHub/vscode-knock-demo/vscode-extension
npm install
npm run compile
```

## 3) Run the extension in VS Code

1. Open `~/GitHub/vscode-knock-demo` in VS Code.
2. Press `F5` to launch the Extension Development Host.
3. In the Extension Development Host, run `Knock: Start Listening` from the command palette.
4. Keep `knock.simulateMode` enabled for the first demo.
5. Wait a few seconds. The sidecar will emit a simulated `double_knock` event and VS Code should show `Knock knock detected!`.

## Installing the extension for local use

This repo currently ships as a development prototype, not a packaged Marketplace extension.

### Option A: run it in Extension Development Host

This is the easiest path and is recommended for now:

1. Open the repo in VS Code.
2. Press `F5`.
3. Use the Extension Development Host as your demo environment.

### Option B: package and install locally

If you want it as an installable local extension:

```bash
cd ~/GitHub/vscode-knock-demo/vscode-extension
npm install -g @vscode/vsce
vsce package
```

Then in VS Code:

1. Run `Extensions: Install from VSIX...`
2. Select the generated `.vsix` file.
3. Reload VS Code.

After installation, make sure the sidecar binary exists at:

```bash
~/GitHub/vscode-knock-demo/knock-sidecar/.build/release/KnockSidecar
```

Or set `knock.sidecarPath` to a custom binary path in VS Code settings.

## Useful commands

- `Knock: Start Listening`
- `Knock: Stop Listening`
- `Knock: Test Notification`

## Extension settings

- `knock.sidecarPath`: optional explicit path to the sidecar binary
- `knock.simulateMode`: run sidecar in simulation mode, default `true`
- `knock.autoStart`: auto-start listener after activation, default `false`

## Notes on the real sensor path

This prototype intentionally prioritizes a fast demo over a production-ready driver.

The real mode aims at the reverse-engineered Apple Silicon path described by community projects that read the private SPU HID device. In practice, the exact HID matching and callback wiring may vary by machine and macOS release.

If we want to push this from prototype to something robust, the next steps are:

1. confirm the exact device properties on your Mac with `ioreg`
2. compare against the open-source reverse-engineered implementations
3. tighten the knock detector with better filtering and calibration
4. decide whether the sidecar should remain a local dev binary or become a companion app / daemon

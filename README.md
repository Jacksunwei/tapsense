# tapsense

Prototype monorepo for a MacBook knock-triggered VS Code notification.

## Projects

- `tapsense-vscode/` - VS Code extension in TypeScript
- `tapsense-sidecar/` - macOS sidecar binary in Swift
- `tapsense-app/` - native macOS menu bar controller app in Swift

## Demo goal

When the sidecar emits a knock-pattern event, the extension can:

- show a VS Code notification
- trigger a configurable VS Code command
- trigger a command contributed by another extension

Supported patterns today:

- single knock
- double knock
- triple knock

## Current prototype status

- VS Code extension is wired and can spawn the sidecar, parse JSON lines, show notifications, and execute configured VS Code commands.
- Sidecar supports `--simulate` mode today for a reliable local demo and cycles through single, double, and triple knock patterns.
- Sidecar also includes a best-effort Apple Silicon private HID path using `IOKit` matching for usage page `0xFF00` and usage `0x03`.
- Real sensor mode is still experimental. On some machines the private device may not be exposed or may require additional privileges / different matching logic.

## Repo layout

```text
tapsense/
├── README.md
├── docs/
├── tapsense-sidecar/
├── tapsense-app/
└── tapsense-vscode/
```

## Design docs

- `docs/architecture.md` - overall system design and event flow
- `docs/tapsense-vscode.md` - how the extension starts the sidecar and handles events
- `docs/tapsense-sidecar.md` - how the sidecar is structured and how knock detection works
- `docs/compatibility.md` - provisional hardware compatibility matrix for the private sensor path
- `docs/tapsense-app.md` - architecture and MVP implementation notes for the native macOS menu bar controller app
- `docs/distribution.md` - bundled app layout and future GitHub/Homebrew distribution notes

## Installation

### Prerequisites

- macOS on Apple Silicon
- Xcode Command Line Tools (`xcode-select --install`)
- Node.js 20+
- npm
- VS Code

### Clone and install

```bash
git clone <your-repo-url> ~/GitHub/tapsense
cd ~/GitHub/tapsense
./build.sh
```

This installs extension dependencies, builds the Swift sidecar, compiles the extension, builds the menu bar executable, and assembles a bundled `TapSense.app`.

## Getting started

Fastest path for the first demo:

```bash
cd ~/GitHub/tapsense
./build.sh
code .
```

Then:

1. In VS Code, open the repo root.
2. Press `F5` to launch the Extension Development Host.
3. In the Extension Development Host, run `TapSense: Start Listening`.
4. Keep `tapsense.simulateMode` enabled.
5. Wait a few seconds for the simulated double-knock.
6. You should see notifications for the simulated knock patterns.

## One-command build

```bash
cd ~/GitHub/tapsense
./build.sh
```

## 1) Build the sidecar

```bash
cd ~/GitHub/tapsense/tapsense-sidecar
swift build -c release
```

Binary path:

```bash
~/GitHub/tapsense/tapsense-sidecar/.build/release/TapSenseSidecar
```

### Quick sidecar test

Simulation mode:

```bash
cd ~/GitHub/tapsense/tapsense-sidecar
.build/release/TapSenseSidecar --simulate
```

You should see JSON events for `single`, `double`, and `triple` knock patterns.

Experimental real mode:

```bash
cd ~/GitHub/tapsense/tapsense-sidecar
.build/release/TapSenseSidecar
```

If the private Apple Silicon accelerometer is not visible, the sidecar exits and tells you to use simulate mode.

## 2) Build the VS Code extension

```bash
cd ~/GitHub/tapsense/tapsense-vscode
npm install
npm run compile
```

## 3) Build and run the macOS menu bar app

Build:

```bash
cd ~/GitHub/tapsense/tapsense-app
swift build -c release
```

Run the raw executable:

```bash
cd ~/GitHub/tapsense/tapsense-app
./.build/release/TapSenseApp
```

Or launch the bundled app:

```bash
open ~/GitHub/tapsense/dist/TapSense.app
```

Current MVP menu actions:

- start / stop sidecar
- toggle simulate mode
- choose `Palm Rest` or `Desk` mode
- choose `Low` / `Medium` / `High` sensitivity
- view status and last event
- send a test notification-style alert

Note: the repo now produces a real `.app` bundle layout in `dist/TapSense.app`, but it is not code-signed or notarized yet.

## 4) Run the extension in VS Code

1. Open `~/GitHub/tapsense` in VS Code.
2. Press `F5` to launch the Extension Development Host.
3. In the Extension Development Host, run `TapSense: Start Listening` from the command palette.
4. Keep `tapsense.simulateMode` enabled for the first demo.
5. Wait a few seconds. The sidecar will cycle through simulated single, double, and triple knocks, and VS Code should react using notifications or configured commands.

## Installing the extension for local use

This repo currently ships as a development prototype, not a packaged Marketplace extension.

## Using it in VS Code-compatible IDEs

This design should also work in editors and IDEs that are compatible with the VS Code extension model.

General rule:

- install the extension the same way you would install a local VSIX or development extension in that IDE
- point knock patterns at command ids, not keybindings
- if the IDE remaps `Cmd+L` or uses an extension-defined action, configure the actual command id behind that action

Typical flow in a VS Code-compatible IDE:

1. install or load the extension
2. build the sidecar and make sure the binary path is valid
3. open the IDE's keyboard shortcut editor
4. find the command currently bound to the shortcut you care about
5. copy that command id into the knock settings

### Example: Google Anti-Gravity style setup

If Google Anti-Gravity is VS Code-compatible in your environment and exposes command ids through the normal keybinding system, configure it exactly the same way:

```json
{
  "tapsense.doubleKnock.command": "the.actual.command.id.behind.cmdL",
  "tapsense.doubleKnock.args": [],
  "tapsense.doubleKnock.showNotification": true
}
```

The important point is that the knock extension should invoke the command id directly, even if the visible shortcut in that IDE is `Cmd+L`.

### Option A: run it in Extension Development Host

This is the easiest path and is recommended for now:

1. Open the repo in VS Code.
2. Press `F5`.
3. Use the Extension Development Host as your demo environment.

### Option B: package and install locally

If you want it as an installable local extension:

```bash
cd ~/GitHub/tapsense/tapsense-vscode
npm install -g @vscode/vsce
vsce package
```

Then in VS Code:

1. Run `Extensions: Install from VSIX...`
2. Select the generated `.vsix` file.
3. Reload VS Code.

After installation, make sure the sidecar binary exists at:

```bash
~/GitHub/tapsense/tapsense-sidecar/.build/release/TapSenseSidecar
```

Or set `tapsense.sidecarPath` to a custom binary path in VS Code settings.

## Useful commands

- `TapSense: Start Listening`
- `TapSense: Stop Listening`
- `TapSense: Test Single Knock`
- `TapSense: Test Double Knock`
- `TapSense: Test Triple Knock`

## Extension settings

Core settings:

- `tapsense.sidecarPath`: optional explicit path to the sidecar binary
- `tapsense.simulateMode`: run sidecar in simulation mode, default `true`
- `tapsense.mode`: sidecar detection profile, `palmRest` or `desk`, default `palmRest`
- `tapsense.sensitivity`: sidecar detection sensitivity, `low`, `medium`, or `high`, default `medium`
- `tapsense.autoStart`: auto-start listener after activation, default `false`

Pattern action settings:

- `tapsense.singleKnock.command`
- `tapsense.singleKnock.args`
- `tapsense.singleKnock.showNotification`
- `tapsense.doubleKnock.command`
- `tapsense.doubleKnock.args`
- `tapsense.doubleKnock.showNotification`
- `tapsense.tripleKnock.command`
- `tapsense.tripleKnock.args`
- `tapsense.tripleKnock.showNotification`

### Example: map a knock to the action behind `Cmd+L`

In VS Code on macOS, `Cmd+L` maps to the command id `expandLineSelection`.

```json
{
  "tapsense.doubleKnock.command": "expandLineSelection",
  "tapsense.doubleKnock.args": [],
  "tapsense.doubleKnock.showNotification": true
}
```

### Example: trigger another extension command

If another extension contributes a command id, you can point a knock pattern at it the same way:

```json
{
  "tapsense.tripleKnock.command": "someExtension.someCommand",
  "tapsense.tripleKnock.args": ["example"],
  "tapsense.tripleKnock.showNotification": true
}
```

Any command id that VS Code can execute is fair game, including commands contributed by other installed extensions.

## Notes on the real sensor path

This prototype intentionally prioritizes a fast demo over a production-ready driver.

The real mode aims at the reverse-engineered Apple Silicon path described by community projects that read the private SPU HID device. In practice, the exact HID matching and callback wiring may vary by machine and macOS release.

If we want to push this from prototype to something robust, the next steps are:

1. confirm the exact device properties on your Mac with `ioreg`
2. compare against the open-source reverse-engineered implementations
3. tighten the knock detector with better filtering and calibration
4. decide whether the sidecar should remain a local dev binary or become a companion app / daemon

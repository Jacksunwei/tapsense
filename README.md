# vscode-knock-demo

Prototype monorepo for a MacBook knock-triggered VS Code notification.

## Projects

- `vscode-extension/` - VS Code extension in TypeScript
- `knock-sidecar/` - macOS sidecar binary in Swift
- `mac-menu-app/` - native macOS menu bar controller app in Swift

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
vscode-knock-demo/
├── README.md
├── docs/
├── knock-sidecar/
├── mac-menu-app/
└── vscode-extension/
```

## Design docs

- `docs/architecture.md` - overall system design and event flow
- `docs/vscode-extension.md` - how the extension starts the sidecar and handles events
- `docs/knock-sidecar.md` - how the sidecar is structured and how knock detection works
- `docs/compatibility.md` - provisional hardware compatibility matrix for the private sensor path
- `docs/mac-menu-app.md` - architecture and MVP implementation notes for the native macOS menu bar controller app
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
git clone <your-repo-url> ~/GitHub/vscode-knock-demo
cd ~/GitHub/vscode-knock-demo
./build.sh
```

This installs extension dependencies, builds the Swift sidecar, compiles the extension, builds the menu bar executable, and assembles a bundled `KnockMenu.app`.

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
6. You should see notifications for the simulated knock patterns.

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

You should see JSON events for `single`, `double`, and `triple` knock patterns.

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

## 3) Build and run the macOS menu bar app

Build:

```bash
cd ~/GitHub/vscode-knock-demo/mac-menu-app
swift build -c release
```

Run the raw executable:

```bash
cd ~/GitHub/vscode-knock-demo/mac-menu-app
./.build/release/KnockMenuApp
```

Or launch the bundled app:

```bash
open ~/GitHub/vscode-knock-demo/dist/KnockMenu.app
```

Current MVP menu actions:

- start / stop sidecar
- toggle simulate mode
- choose `Palm Rest` or `Desk` mode
- choose `Low` / `Medium` / `High` sensitivity
- view status and last event
- send a test notification-style alert

Note: the repo now produces a real `.app` bundle layout in `dist/KnockMenu.app`, but it is not code-signed or notarized yet.

## 4) Run the extension in VS Code

1. Open `~/GitHub/vscode-knock-demo` in VS Code.
2. Press `F5` to launch the Extension Development Host.
3. In the Extension Development Host, run `Knock: Start Listening` from the command palette.
4. Keep `knock.simulateMode` enabled for the first demo.
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
  "knock.doubleKnock.command": "the.actual.command.id.behind.cmdL",
  "knock.doubleKnock.args": [],
  "knock.doubleKnock.showNotification": true
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
- `Knock: Test Single Knock`
- `Knock: Test Double Knock`
- `Knock: Test Triple Knock`

## Extension settings

Core settings:

- `knock.sidecarPath`: optional explicit path to the sidecar binary
- `knock.simulateMode`: run sidecar in simulation mode, default `true`
- `knock.mode`: sidecar detection profile, `palmRest` or `desk`, default `palmRest`
- `knock.sensitivity`: sidecar detection sensitivity, `low`, `medium`, or `high`, default `medium`
- `knock.autoStart`: auto-start listener after activation, default `false`

Pattern action settings:

- `knock.singleKnock.command`
- `knock.singleKnock.args`
- `knock.singleKnock.showNotification`
- `knock.doubleKnock.command`
- `knock.doubleKnock.args`
- `knock.doubleKnock.showNotification`
- `knock.tripleKnock.command`
- `knock.tripleKnock.args`
- `knock.tripleKnock.showNotification`

### Example: map a knock to the action behind `Cmd+L`

In VS Code on macOS, `Cmd+L` maps to the command id `expandLineSelection`.

```json
{
  "knock.doubleKnock.command": "expandLineSelection",
  "knock.doubleKnock.args": [],
  "knock.doubleKnock.showNotification": true
}
```

### Example: trigger another extension command

If another extension contributes a command id, you can point a knock pattern at it the same way:

```json
{
  "knock.tripleKnock.command": "someExtension.someCommand",
  "knock.tripleKnock.args": ["example"],
  "knock.tripleKnock.showNotification": true
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

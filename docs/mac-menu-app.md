# macOS menu bar app

This document now covers both:

1. the rationale for a native menu bar app
2. the MVP implementation that now exists in this repo

## Current implementation

The repo now includes:

```text
mac-menu-app/
├── Package.swift
└── Sources/
    └── KnockMenuApp/
        ├── main.swift
        ├── MenuApp.swift
        ├── Models.swift
        └── SidecarController.swift
```

It is a Swift Package Manager executable that launches a native macOS status bar item.

## What the MVP does

The current menu bar app can:

- start the sidecar
- stop the sidecar
- toggle simulate mode
- switch between `Palm Rest` and `Desk` profiles
- switch between `Low`, `Medium`, and `High` sensitivity
- show current status and last event in the menu
- trigger a test alert

## Current limitations

- the repo can assemble a local `.app` bundle, but it is not signed or notarized yet
- it still starts the sidecar as a child process
- it does not yet expose a socket or XPC control plane
- VS Code and the menu app do not yet share a single long-running sidecar instance
- sidecar profile tuning is still heuristic, not hardware-calibrated

## Why add a menu bar app

A VS Code extension is the right place for editor actions, but it is not the right place for system-level lifecycle control.

A dedicated macOS menu bar app makes the knock system feel like a native Mac utility instead of an editor-only demo.

## Current architecture

```text
macOS menu bar app
        ↓ launches / controls
     knock-sidecar
        ↓ knock events
   VS Code extension
```

In the current MVP:

- the menu app launches the sidecar directly with `Process`
- the menu app controls mode, sensitivity, and simulate flags through CLI arguments
- the sidecar emits JSON events like `started`, `knock_pattern`, `error`, and `stopped`
- the menu app updates its menu state based on those events

## Responsibilities

### 1. `knock-sidecar`

Responsibilities:

- read accelerometer data
- apply detection profiles such as palm-rest and desk
- classify knock patterns
- emit structured events

### 2. `vscode-extension`

Responsibilities:

- listen for knock events
- map knock patterns to command ids
- trigger VS Code or extension-provided actions
- show editor notifications

### 3. `mac-menu-app`

Responsibilities:

- show current sidecar status
- start and stop the sidecar
- switch between `palmRest` and `desk` modes
- adjust sensitivity
- expose quick local controls without opening VS Code

## Suggested repo layout

```text
vscode-knock-demo/
├── knock-sidecar/
├── vscode-extension/
└── mac-menu-app/
```

## Implementation notes

### `main.swift`

Creates and runs `NSApplication`.

### `MenuApp.swift`

Creates the status bar item and menu structure.

Main menu items in the MVP:

- Status
- Last Event
- Start / Stop Listening
- Simulate Mode
- Mode submenu
- Sensitivity submenu
- Test Notification
- Quit

### `SidecarController.swift`

Owns the `Process` that runs the sidecar.

Responsibilities:

- resolve sidecar binary path
- launch with selected CLI arguments
- read stdout and stderr
- decode JSON events
- keep UI state updated

### `Models.swift`

Shared app-side models for:

- mode
- sensitivity
- sidecar JSON event decoding

## Why this MVP shape is reasonable

It gives us a real native control surface quickly, without blocking on a larger service architecture rewrite.

That means we can already:

- iterate on UX
- validate whether the menu bar utility feels right
- validate whether profile switching is a useful concept
- keep the heavier transport refactor for later

## Recommended next evolution

If we continue the project, the next architectural step should be to move from `menu app owns child process` toward `single long-running sidecar service`.

Preferred future shape:

```text
macOS menu bar app
        ↓ control API
   long-running sidecar service
        ↓ event stream
   VS Code extension client
```

## Recommended transport options

For that next step, the strongest candidates are:

1. Unix domain socket with newline-delimited JSON
2. local WebSocket
3. XPC for a more native macOS-only approach

For speed and simplicity, a Unix domain socket is probably the best next move.

# macOS menu bar app architecture

## Why add a menu bar app

A VS Code extension is the right place for editor actions, but it is not the right place for system-level lifecycle control.

A dedicated macOS menu bar app would let the knock system feel like a native Mac utility instead of an editor-only demo.

## Proposed three-part architecture

```text
macOS menu bar app
        ↓ control / config
     knock-sidecar
        ↓ knock events
   VS Code extension
```

## Responsibilities

### 1. `knock-sidecar`

Keep this as the sensor and detection engine.

Responsibilities:

- read accelerometer data
- apply detection profiles such as palm-rest and desk
- classify knock patterns
- emit structured events
- expose minimal control hooks for start, stop, mode, and sensitivity

### 2. `vscode-extension`

Keep this focused on IDE behavior.

Responsibilities:

- listen for knock events
- map knock patterns to command ids
- trigger VS Code or extension-provided actions
- show editor notifications

### 3. `mac-menu-app`

Add a native macOS app, ideally SwiftUI + `MenuBarExtra`.

Responsibilities:

- show current sidecar status
- start and stop the sidecar
- switch between `palmRest` and `desk` modes
- adjust sensitivity
- trigger calibration
- open logs
- optionally launch at login
- expose global notifications and debugging UI

## Suggested repo layout

```text
vscode-knock-demo/
├── knock-sidecar/
├── vscode-extension/
└── mac-menu-app/
```

## Suggested control model

There are two viable control models.

### Option A. Sidecar as a long-running local service

Menu bar app starts and owns the sidecar.

- menu bar app manages lifecycle
- VS Code extension connects as a client / subscriber
- best if we want the knock system active even when VS Code is closed

Pros:
- cleaner product model
- sidecar can remain alive across editors
- better fit for menu bar utility behavior

Cons:
- requires a local control / event transport, such as socket or XPC

### Option B. Menu bar app as a config + launcher wrapper

Menu bar app mainly manages config and can launch or stop the sidecar process, while the VS Code extension can still spawn it directly for editor-only use.

Pros:
- simpler migration from the current prototype
- keeps current extension behavior mostly intact

Cons:
- lifecycle ownership becomes split
- more chances for duplicate sidecar processes

## Recommendation

Prefer **Option A** if we continue this project.

That means:

- sidecar becomes the single runtime engine
- menu bar app owns lifecycle and config
- VS Code extension becomes a client that subscribes to knock events and only handles editor actions

## Suggested transport evolution

Current prototype uses stdio JSON because it is the lightest path.

For a menu bar app architecture, evolve toward one of these:

1. Unix domain socket with newline-delimited JSON
2. local WebSocket
3. XPC if we want a more native macOS-only approach

For speed of implementation, a Unix socket is probably the best next step.

## Suggested shared concepts

The menu bar app and VS Code extension should share the same conceptual config model:

- `mode`: `palmRest | desk`
- `sensitivity`: `low | medium | high`
- per-pattern bindings:
  - `single`
  - `double`
  - `triple`

## Minimal v1 menu bar UI

Recommended first version:

- status: running / stopped
- mode picker: palm-rest / desk
- sensitivity picker: low / medium / high
- start / stop
- test knock notification
- open log file
- quit

## Nice v2 features

- calibration wizard
- live waveform preview
- recent event history
- launch at login
- profile presets for different desks / dock setups
- separate editor profiles for VS Code-compatible IDEs

## Implementation recommendation

If we build this, I would do it in this order:

1. keep current sidecar and extension intact
2. introduce a stable local event / control transport
3. add `mac-menu-app/` as a SwiftUI menu bar target
4. move lifecycle control from extension-spawned stdio toward menu bar ownership
5. keep a dev fallback where the extension can still spawn the sidecar directly

## Why this is a good next step

This turns the project from a VS Code demo into a real Mac utility with editor integrations layered on top.

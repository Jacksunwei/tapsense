# Architecture

## Why there are two projects

TapSense intentionally separates hardware access from VS Code UX.

### VS Code extension responsibilities

- register commands
- launch and stop the sidecar process
- parse event lines from the sidecar
- show notifications inside VS Code
- expose user settings such as simulate mode, sidecar path, detection mode, and sensitivity

### Sidecar responsibilities

- talk to the local sensor source
- normalize raw readings into a simple stream
- detect single-, double-, and triple-tap gestures
- emit machine-readable events over stdout

This split keeps the extension simple and makes the sensor code replaceable.

## High-level event flow

```text
Physical tap or simulated tap
        ↓
tapsense-sidecar sensor source
        ↓
TapDetector classifies tap pattern
        ↓
stdout JSON event: {"type":"tap_pattern","pattern":"double","count":2}
        ↓
VS Code extension reads line
        ↓
vscode.window.showInformationMessage(...)
```

## Process boundary

The boundary between the two projects is a newline-delimited JSON protocol over stdio.

Example messages:

```json
{"type":"started","mode":"simulate"}
{"type":"tap_pattern","pattern":"single","count":1,"timestamp":0.01}
{"type":"tap_pattern","pattern":"double","count":2,"timestamp":1.95}
{"type":"tap_pattern","pattern":"triple","count":3,"timestamp":3.90}
{"type":"error","message":"Failed to start accelerometer. Use --simulate mode."}
{"type":"stopped"}
```

## Why stdio instead of an RPC server

For a prototype, stdio is the lightest option:

- no ports
- no local server lifecycle
- easy to debug in terminal
- trivial to spawn from Node.js

If this becomes a real product, we could still keep stdio or upgrade to a socket-based protocol.

## Current design tradeoffs

### Pros

- easy to test
- clear separation of concerns
- sidecar can be tested outside VS Code
- extension can stay almost entirely TypeScript

### Cons

- requires a built native binary on disk
- real sensor mode depends on unstable private APIs
- no structured versioning on the event protocol yet
- no calibration flow yet

## What would likely change in a production version

1. define a versioned event schema
2. add sidecar health checks and restart logic
3. add calibration and sensitivity controls
4. harden the real sensor path against machine-specific differences
5. decide on packaging strategy for the native binary

# tapsense-sidecar design

## Purpose

The sidecar is a native macOS executable that turns sensor samples into higher-level knock events.

It exists because low-level macOS hardware access is a poor fit for a normal VS Code extension runtime.

## Main files

- `tapsense-sidecar/Sources/TapSenseSidecar/main.swift`
- `tapsense-sidecar/Sources/TapSenseSidecar/Accelerometer.swift`
- `tapsense-sidecar/Sources/TapSenseSidecar/KnockDetector.swift`
- `tapsense-sidecar/Sources/TapSenseSidecar/Simulator.swift`

## Internal structure

### `AccelerometerSource`

This protocol defines the sensor boundary:

- `start(callback:) -> Bool`
- `stop()`

That abstraction allows the rest of the system to stay independent from the concrete sensor source.

### `SimulatedAccelerometer`

This implementation exists to make the full demo reliable.

It:

- runs a timer
- emits mostly stable readings
- injects synthetic spike patterns for one, two, or three knocks
- cycles through repeated single, double, and triple patterns
- uses synthetic timestamps so the demo stays stable even if timer scheduling jitters

This lets us verify the full pipeline without depending on private hardware APIs.

### `IOKitAccelerometer`

This is the experimental real sensor path.

Current design:

- creates an `IOHIDManager`
- matches on vendor usage page `0xFF00`
- matches on usage `0x03`
- registers an input report callback
- parses report bytes into x/y/z values

The implementation is based on the reverse-engineered Apple Silicon SPU HID path described by community projects. It is intentionally labeled best-effort because the exact device exposure may differ by machine and OS version.

## Report parsing

The current parser assumes HID reports where:

- x is little-endian int32 at byte offset 6
- y is little-endian int32 at byte offset 10
- z is little-endian int32 at byte offset 14
- values are scaled by `65536`

That assumption matches public reverse-engineering notes, but still needs verification on the target machine.

## Knock detection algorithm

`KnockDetector` is intentionally simple.

### Input

One `AccelerometerReading` at a time:

- `x`
- `y`
- `z`
- `timestamp`

### Logic

1. compute vector magnitude
2. compare against a threshold
3. treat each rising-edge threshold crossing as one knock
4. group nearby knocks into a sequence using min and max timing gaps
5. classify the sequence as single, double, or triple knock
6. emit a `knock_pattern` event with `pattern` and `count`
7. apply a cooldown to avoid repeated firing

This is good enough for a prototype, but not robust enough for production.

## Output protocol

The sidecar writes one JSON object per line to stdout.

Examples:

```json
{"type":"started","mode":"simulate"}
{"type":"knock_pattern","pattern":"single","count":1,"timestamp":0.01}
{"type":"knock_pattern","pattern":"double","count":2,"timestamp":1.95}
{"type":"knock_pattern","pattern":"triple","count":3,"timestamp":3.90}
{"type":"error","message":"Failed to start accelerometer. Use --simulate mode."}
```

Human-readable diagnostics go to stderr.

## Shutdown behavior

The process listens for `SIGINT`, stops the sensor source, emits a `stopped` event, and exits.

## Why the sidecar is currently the riskier half

Because it depends on undocumented platform behavior.

Risks include:

- the HID device may not appear consistently
- device matching may differ by hardware generation
- reports may not have the same format everywhere
- permissions may become a factor
- Apple may break the path in a future release

## Likely next improvements

1. inspect actual `ioreg` output on the target machine
2. compare the current implementation against known working reverse-engineered code
3. add sample logging mode for calibration
4. replace threshold-only detection with better filtering and waveform analysis
5. decide whether a helper app or daemon is a better long-term packaging model

# Compatibility matrix

This matrix is intentionally conservative.

The hidden accelerometer / IMU path used by projects like Knock is not documented by Apple as a public macOS API, so compatibility has to be inferred from reverse-engineered projects and public claims from apps using the same path.

## Summary

| Device class | Status | Confidence | Notes |
|---|---|---:|---|
| Apple Silicon MacBook Pro | Likely supported | High | Strongest public evidence. Reverse-engineered projects explicitly report working on MacBook Pro models. |
| Apple Silicon MacBook Air | Possibly supported | Medium | Plausible, but we have not verified it in this repo yet. Public evidence is weaker than for MacBook Pro. |
| Intel MacBook Pro / Air | Unclear / likely different path | Low | Older Macs had different motion-sensor history. This prototype targets the Apple Silicon SPU HID path, not the older SMS path. |
| Mac mini | Likely unsupported | High | Desktop form factor, no practical motion-sensor use case, and this repo did not find the expected device on the Mac mini host. |
| Mac Studio | Likely unsupported | Medium | Same reasoning as Mac mini. |
| Mac Pro | Likely unsupported | Medium | Same reasoning as other desktop Macs. |
| iMac | Likely unsupported | Medium | Same reasoning as other desktop Macs. |

## Evidence behind the table

### Strongest source

The most concrete reverse-engineered source we found says:

- "modern macbook pros have an undocumented mems accelerometer + gyroscope"
- "only tested on macbook pro m3 pro so far"
- `IMU.available()` is described as `True on macbook pro m2+`

Source:
- `olvvier/apple-silicon-accelerometer`: https://github.com/olvvier/apple-silicon-accelerometer

### Product claim from the app ecosystem

The Knock app markets itself as controlling your Mac with taps and public reverse-engineering references describe it as using the built-in accelerometer in Apple Silicon MacBooks.

Source:
- TapSense: https://www.tryknock.app/

## Important caveat

This is not an Apple-supported compatibility table.

It is a working hypothesis for this prototype, based on:

1. reverse-engineered community work
2. product claims from apps built on the same idea
3. the absence of the expected device on the current Mac mini host

## Recommendation for this repo

When we talk about support, the safest wording is:

- "best evidence currently points to Apple Silicon MacBook Pro"
- "MacBook Air may work but is not yet verified here"
- "desktop Macs should be treated as unsupported unless proven otherwise"

## How to verify on a target machine

The most useful next-step check on a real target machine is to inspect whether the SPU HID device is present at all.

For example, community notes suggest looking for `AppleSPUHIDDevice` in `ioreg`.

If we move this prototype forward, we should replace this inferred matrix with a tested matrix based on actual runs on:

- MacBook Pro
- MacBook Air
- Mac mini

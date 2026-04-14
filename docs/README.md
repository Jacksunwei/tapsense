# Documentation

This folder explains how the prototype is designed, how the two subprojects talk to each other, and where the current technical risks are.

## Files

- `architecture.md` - system-level overview of the prototype
- `vscode-extension.md` - extension design, activation flow, and event handling
- `knock-sidecar.md` - sidecar design, sensor abstraction, and knock detection
- `compatibility.md` - provisional hardware compatibility matrix for this private sensor path
- `vscode-compatible-ides.md` - how to configure command mapping in VS Code-compatible IDEs
- `mac-menu-app.md` - proposed architecture for a native macOS menu bar controller app
- `distribution.md` - how the bundled app is assembled and prepared for future GitHub/Homebrew release flow

## Quick summary

The prototype is split into two parts:

1. a VS Code extension that handles editor UX
2. a native macOS sidecar that produces knock events

The sidecar emits newline-delimited JSON on stdout. The extension reads those lines and reacts to them.

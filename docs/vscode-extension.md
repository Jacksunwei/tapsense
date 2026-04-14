# VS Code extension design

## Purpose

The extension is the editor-facing half of the prototype. It does not detect knocks itself. Instead, it launches the sidecar and reacts to events.

## Main file

- `vscode-extension/src/extension.ts`

## Activation model

The extension contributes three commands:

- `Knock: Start Listening`
- `Knock: Stop Listening`
- `Knock: Test Notification`

It can also auto-start after activation when `knock.autoStart` is enabled.

## Startup flow

When listening starts, the extension:

1. resolves the sidecar binary path
2. reads the extension settings
3. optionally adds `--simulate`
4. spawns the sidecar with Node's `child_process.spawn`
5. attaches line readers to stdout and stderr
6. updates the VS Code status bar

## Sidecar path resolution

Resolution order:

1. `knock.sidecarPath` if set
2. default repo-local path: `../knock-sidecar/.build/release/KnockSidecar`

This makes the monorepo easy to run locally without extra configuration.

## Event handling

The extension treats the sidecar as a JSON line producer.

### stdout

Each stdout line is parsed as JSON and dispatched by `type`.

Handled event types:

- `started`
- `double_knock`
- `error`
- `stopped`

### stderr

stderr is not parsed as protocol. It is forwarded to the output channel for debugging.

## User-visible behavior

### Status bar

A status bar item shows whether listening is active.

- `Knock: Off`
- `Knock: Listening`

### Notifications

When the extension receives a `double_knock` event, it calls:

```ts
vscode.window.showInformationMessage("Knock knock detected!")
```

The manual test command uses the same notification path, which makes it useful for debugging extension UX without involving the sidecar.

## Why this extension stays thin

That is intentional.

The hardware path is the unstable part of the system. Keeping the extension thin means:

- easier debugging
- less editor-specific complexity in the native layer
- easier future replacement of the sidecar implementation

## Failure behavior

If the sidecar cannot be started or crashes:

- the output channel captures details
- the extension shows an error message when appropriate
- internal state resets back to `Knock: Off`

## Future extension improvements

1. show richer notifications with event metadata
2. expose sensitivity settings in the extension UI
3. support command binding, not just notifications
4. support background restart when the sidecar exits unexpectedly
5. package the sidecar automatically during extension install

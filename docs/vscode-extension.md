# VS Code extension design

## Purpose

The extension is the editor-facing half of the prototype. It does not detect knocks itself. Instead, it launches the sidecar and reacts to events.

## Main file

- `vscode-extension/src/extension.ts`

## Activation model

The extension contributes five commands:

- `Knock: Start Listening`
- `Knock: Stop Listening`
- `Knock: Test Single Knock`
- `Knock: Test Double Knock`
- `Knock: Test Triple Knock`

It can also auto-start after activation when `knock.autoStart` is enabled.

## Startup flow

When listening starts, the extension:

1. resolves the sidecar binary path
2. reads the extension settings
3. passes `--mode`, `--sensitivity`, and optionally `--simulate`
4. spawns the sidecar with Node's `child_process.spawn`
5. attaches line readers to stdout and stderr
6. updates the VS Code status bar

## Sidecar path resolution

Resolution order:

1. `knock.sidecarPath` if set
2. default repo-local path: `../knock-sidecar/.build/release/KnockSidecar`

This makes the monorepo easy to run locally without extra configuration.

## Sidecar profile settings

The extension exposes the same profile knobs as the menu app:

- `knock.mode`: `palmRest` or `desk`
- `knock.sensitivity`: `low`, `medium`, or `high`

Those settings are passed directly to the sidecar as CLI flags.

## Event handling

The extension treats the sidecar as a JSON line producer.

### stdout

Each stdout line is parsed as JSON and dispatched by `type`.

Handled event types:

- `started`
- `knock_pattern`
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

When the extension receives a `knock_pattern` event, it resolves the matching settings bucket for `single`, `double`, or `triple` knock.

For each pattern it can:

1. show a notification
2. execute a configured command id
3. pass a configured argument array to that command

Because it uses `vscode.commands.executeCommand(...)`, the target command can come from:

- VS Code itself
- this extension
- another installed extension

### Concrete example: reuse the action behind `Cmd+L`

In the default macOS VS Code keymap, `Cmd+L` maps to:

- command id: `expandLineSelection`

So a working settings example is:

```json
{
  "knock.doubleKnock.command": "expandLineSelection",
  "knock.doubleKnock.args": [],
  "knock.doubleKnock.showNotification": true
}
```

### Concrete example: trigger another extension

If another extension exposes a command id such as `someExtension.someCommand`, you can wire it the same way:

```json
{
  "knock.tripleKnock.command": "someExtension.someCommand",
  "knock.tripleKnock.args": ["example"],
  "knock.tripleKnock.showNotification": true
}
```

The manual test commands use the same action path, which makes them useful for debugging extension behavior without involving the sidecar.

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
2. add validation or discovery helpers for configured command ids
3. support background restart when the sidecar exits unexpectedly
4. package the sidecar automatically during extension install

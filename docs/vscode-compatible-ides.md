# Using the prototype in VS Code-compatible IDEs

## Core idea

This prototype is command-driven, not shortcut-driven.

That distinction matters in VS Code-compatible IDEs.

A tap pattern should trigger the command id you want, not the visible keybinding. If an IDE binds `Cmd+L` to a custom action, you should configure the command id behind that action.

## What usually carries over from VS Code

In a VS Code-compatible IDE, the following often remain usable:

- extension install via development host or VSIX
- settings JSON
- command ids
- keyboard shortcut editor
- `vscode.commands.executeCommand(...)`

If those pieces exist, this prototype should map cleanly.

## Recommended setup flow

1. Build the sidecar binary.
2. Install the extension in the target IDE.
3. Confirm the IDE can run the extension.
4. Open the IDE's keyboard shortcuts UI.
5. Search for the shortcut you want to mirror, for example `Cmd+L`.
6. Find the real command id currently bound to that shortcut.
7. Put that command id into the tap settings.
8. Use the built-in tap test commands before trying real hardware.

## Example settings template

```json
{
  "tapsense.singleTap.command": "",
  "tapsense.singleTap.args": [],
  "tapsense.singleTap.showNotification": true,

  "tapsense.doubleTap.command": "the.actual.command.id",
  "tapsense.doubleTap.args": [],
  "tapsense.doubleTap.showNotification": true,

  "tapsense.tripleTap.command": "",
  "tapsense.tripleTap.args": [],
  "tapsense.tripleTap.showNotification": true
}
```

## Example: custom `Cmd+L` behavior

Suppose your IDE shows `Cmd+L`, but that shortcut does not map to the standard VS Code command `expandLineSelection`.

Then you should not configure:

```json
{
  "tapsense.doubleTap.command": "expandLineSelection"
}
```

Instead, configure the actual command id bound in that IDE.

## Example: Google Anti-Gravity style environment

If Google Anti-Gravity is using a VS Code-compatible extension host and keybinding system, the pattern is the same:

1. inspect the actual command bound to the shortcut
2. use that command id in tap settings
3. ignore the shortcut string itself during configuration

Example:

```json
{
  "tapsense.doubleTap.command": "the.actual.command.id.behind.cmdL",
  "tapsense.doubleTap.args": [],
  "tapsense.doubleTap.showNotification": true
}
```

## Troubleshooting

### The shortcut works, but tap does nothing

Likely causes:

- wrong command id
- wrong sidecar path
- extension not loaded in that IDE
- the target IDE is not fully compatible with the VS Code command execution model

### How to isolate the problem

1. run `TapSense: Test Double Tap`
2. if notification appears, extension is alive
3. set the target command to a known built-in command such as `workbench.action.quickOpen`
4. if that works, the remaining problem is your custom target command id

## Recommendation

For any VS Code-compatible IDE, document configs in terms of command ids, not shortcuts. That makes the setup robust across custom keymaps and extension-defined actions.

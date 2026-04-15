# 🏥 TapSense

**Turn your MacBook into a button.**

TapSense lets you trigger VS Code commands by physically tapping the palm rest or the desk next to your MacBook. It uses the undocumented built-in accelerometer in Apple Silicon Macs to detect single, double, and triple tap patterns.

---

## 🚀 One-Command Install

Run this in your terminal to install the latest version of TapSense:

```bash
brew update
brew install --cask jacksunwei/tap/tapsense
```

---

## ⚠️ Security & Permissions

Because TapSense is an open-source tool built on GitHub and is not yet digitally signed by an Apple Developer account, macOS will show a **"TapSense is damaged"** warning on the first launch.

### 1. Fix the "Damaged" Warning
Run this command in your terminal to tell macOS the app is safe:

```bash
sudo xattr -rd com.apple.quarantine /Applications/TapSense.app
```

### 2. Enable Sensor Access
TapSense needs to monitor the accelerometer and keyboard (to ignore typing vibrations). When prompted, please grant **Input Monitoring** permissions in:
`System Settings > Privacy & Security > Input Monitoring`

---

## 🛠 How to Use (Real Hardware)

Once you're ready to try real physical taps:

1. **Enable Real Mode**: In the Menu Bar app, uncheck **Simulate Mode**.
2. **Choose Your Surface**:
   - **Palm Rest**: Optimized for tapping the body of the MacBook.
   - **Desk**: Optimized for tapping the table next to the MacBook.
3. **Adjust Sensitivity**: Choose between Low, Medium, or High.

---

## ⚙️ Configuration

TapSense is command-id based. You can map any VS Code command to a tap pattern in your `settings.json`.

### Example: Double-Tap to "Expand Selection"
In VS Code, `Cmd+L` runs `expandLineSelection`. Let's map it to a double-tap:

```json
{
  "tapsense.doubleTap.command": "expandLineSelection",
  "tapsense.doubleTap.showNotification": true
}
```

### Example: Triple-Tap to trigger another extension
```json
{
  "tapsense.tripleTap.command": "git.commit",
  "tapsense.tripleTap.args": ["tapsense: auto-commit"]
}
```

---

## 📂 Project Structure

- **`tapsense-sidecar/`**: The native Swift engine that talks to the Apple SPU accelerometer.
- **`tapsense-app/`**: The macOS menu bar controller.
- **`tapsense-vscode/`**: The VS Code extension integration.

---

## 📚 Technical Docs

For deep dives into the internals:
- [Architecture & Flow](docs/architecture.md)
- [Detection Algorithm](docs/tapsense-sidecar.md)
- [Distribution & Bundling](docs/distribution.md)

---

## 🤝 Contributing

This is an open-source prototype by **Jack Sun**. 

If you have an Apple Silicon MacBook and want to help tune the sensor logic or add support for more IDEs, PRs are welcome!

[GitHub Repository](https://github.com/Jacksunwei/tapsense)

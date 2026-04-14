# Distribution and bundling

## Current packaging target

The repo now produces a bundled macOS app at:

```text
dist/KnockMenu.app
```

The bundle contains:

- `Contents/MacOS/KnockMenuApp` - the native menu bar executable
- `Contents/Resources/KnockSidecar` - the embedded sidecar binary
- `Contents/Info.plist` - app metadata

## Why this matters

This gets the project closer to a one-install user experience:

- app bundle contains the sidecar
- the menu app prefers the bundled sidecar at runtime
- Homebrew Cask can later distribute the `.app`

## Current workflow

Build everything:

```bash
cd ~/GitHub/vscode-knock-demo
./build.sh
```

Package only the app bundle:

```bash
cd ~/GitHub/vscode-knock-demo/mac-menu-app
./package-app.sh
```

Launch the bundle locally:

```bash
open ~/GitHub/vscode-knock-demo/dist/KnockMenu.app
```

Or run the inner executable directly:

```bash
~/GitHub/vscode-knock-demo/dist/KnockMenu.app/Contents/MacOS/KnockMenuApp
```

## GitHub account assumption

This repo is currently set up assuming future public hosting under Jack's GitHub account.

Current bundle metadata uses:

- bundle identifier: `com.jacksunwei.knockmenu`
- app display name: `KnockMenu`

These are set up assuming future public hosting under the `jacksunwei` GitHub handle and can still be refined when the final repo name and signing identity are chosen.

## Recommended future release flow

1. build `dist/KnockMenu.app`
2. zip the app bundle for release upload
3. attach the zip as a GitHub Release asset
4. add a Homebrew Cask pointing to that release asset

## Example Homebrew Cask shape

```ruby
cask "knockmenu" do
  version "0.1.0"
  sha256 "..."

  url "https://github.com/jacksunwei/vscode-knock-demo/releases/download/v#{version}/KnockMenu.app.zip"
  name "KnockMenu"
  desc "Menu bar controller for MacBook knock detection"
  homepage "https://github.com/jacksunwei/vscode-knock-demo"

  app "KnockMenu.app"
end
```

## What is still missing for a polished public release

- app icon
- code signing
- notarization
- release automation
- VSIX packaging and integration install UX

## Recommendation

Treat the current bundle as a strong local-distribution milestone, not the final polished release artifact.

# ThreeFingerClick

Local macOS menu bar utility for detecting a physical three-finger trackpad click and sending `Command+W`.

This is a personal tool. It uses private `MultitouchSupport.framework` plus `CGEventTap`, so it is not intended for App Store distribution.

## Install

Download the latest release zip from GitHub Releases, unzip it, and move `ThreeFingerClick.app` to `~/Applications`.

For local development builds, install to a stable local path:

```bash
scripts/install-app.sh
open ~/Applications/ThreeFingerClick.app
```

Grant Accessibility permission when macOS asks. If it does not ask, open the menu bar icon and choose `Open Accessibility Settings`, then enable `ThreeFingerClick`.

After permission is granted, the app will automatically retry the event listener. You should not need to quit or click `Restart Listener` again.

## Daily Use

You do not need to rebuild every time. After installation, launch:

```bash
open ~/Applications/ThreeFingerClick.app
```

Use the menu bar icon to toggle `Enabled`, restart the listener, open Accessibility settings, or quit.

To start automatically on login, add `~/Applications/ThreeFingerClick.app` in `System Settings > General > Login Items`.

## Rebuild After Code Changes

Only rebuild when source code changes:

```bash
scripts/install-app.sh
```

If macOS stops recognizing the app after reinstalling, remove and re-add `~/Applications/ThreeFingerClick.app` in Accessibility settings.

Unsigned local builds may be treated as a new app after deletion, reinstall, or path changes. Keep the app at `~/Applications/ThreeFingerClick.app` for the most stable Accessibility permission behavior.

If you used a version before `v0.1.4`, remove the old `ThreeFingerClick` entry from Accessibility settings once, install the latest release, then grant permission again. Earlier builds did not sign the full app bundle, which could prevent macOS from matching the authorized app to the running listener.

## Development

```bash
swift test
swift build
scripts/build-app.sh
```

`dist/ThreeFingerClick.app` is the generated build artifact. `~/Applications/ThreeFingerClick.app` is the recommended installed copy.

## Release Flow

Pushes to `main` create official GitHub Releases automatically.

The workflow in `.github/workflows/release.yml`:

1. Runs `swift test`.
2. Finds the latest `vX.Y.Z` tag.
3. Increments the patch version, starting at `v0.1.0`.
4. Builds `dist/ThreeFingerClick.app` with that version.
5. Packages `ThreeFingerClick-vX.Y.Z-macos-universal.zip` for Apple Silicon and Intel Macs.
6. Publishes the release with GitHub CLI: `gh release create`.

To open source the project from this local directory:

```bash
git init
git branch -M main
git add .
git commit -m "Initial release"
gh repo create three-finger-click --public --source=. --remote=origin --push
```

After that, every push to `main` publishes a new patch release. Release downloads are available under the repository's GitHub Releases page.

# Repository Guidelines

## Project Structure & Module Organization

This repository is currently a lightweight research/documentation project for a macOS three-finger trackpad click utility.

- `trackpad-three-finger-click-research.md` contains the current feasibility research, architecture notes, risks, and MVP plan.
- `AGENTS.md` is the contributor guide for future agents and maintainers.
- There is no `src/`, `tests/`, or assets directory yet. If implementation begins, use `src/` for Swift/Objective-C code, `tests/` for tests, and `docs/` for supporting research.

Keep research notes separate from implementation. Move long-form design material into `docs/` once source code is introduced.

## Build, Test, and Development Commands

No build system is present yet. Useful validation commands for the current repository are:

- `ls -la` - inspect the project root.
- `rg --files` - list tracked-style project files quickly.
- `sed -n '1,120p' trackpad-three-finger-click-research.md` - review the main research document.

Current local commands:

- `rtk swift test` - run the Swift Testing/XCTest suite.
- `rtk swift build` - compile the menu bar executable in debug mode.
- `rtk scripts/build-app.sh` - build release and assemble `dist/ThreeFingerClick.app`.
- `rtk scripts/install-app.sh` - build and install to `~/Applications/ThreeFingerClick.app`.

## Coding Style & Naming Conventions

For Markdown, use sentence-case headings, short paragraphs, and fenced code blocks with language tags where possible. Keep command examples copy-pasteable.

For future Swift code, use four-space indentation, `UpperCamelCase` for types such as `TouchTracker`, and `lowerCamelCase` for methods and properties such as `activeTouchCount`. Match the research architecture: `TouchTracker`, `ClickTap`, and `ActionRunner`.

## Testing Guidelines

There are no automated tests yet. For documentation-only changes, verify formatting manually and ensure links, commands, and file paths are accurate.

When implementation starts, add focused tests for state-machine behavior: touch count freshness, down/up pairing, movement thresholds, and event consumption decisions. Name tests after behavior, for example `testThreeFingerClickRequiresFreshTouchData`.

## Commit & Pull Request Guidelines

This directory is not currently a Git repository, so no local history is available. Use concise, imperative commit messages if Git is initialized, for example `Add touch tracker prototype` or `Document CGEventTap risks`.

Pull requests should include a clear summary, test or validation notes, and screenshots or logs when UI, permissions, or event handling behavior changes. Link related issues or research notes when applicable.

## Security & Configuration Tips

The planned tool may use private macOS APIs and Accessibility permissions. Do not present private API behavior as stable. Avoid committing machine-specific paths, signing identities, tokens, or personal automation scripts.

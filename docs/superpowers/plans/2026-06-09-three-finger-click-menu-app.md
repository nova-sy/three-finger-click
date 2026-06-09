# Three Finger Click Menu App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local macOS menu bar utility that detects physical three-finger trackpad clicks and sends `Command+W`.

**Architecture:** A SwiftPM package provides a menu bar executable plus a small testable core. `TouchTracker` reads private MultitouchSupport contact frames, `ClickTap` observes left mouse down/up through `CGEventTap`, `ThreeFingerClickDetector` validates the click, and `ActionRunner` posts the fixed keyboard shortcut.

**Tech Stack:** Swift 6, AppKit, CoreGraphics, XCTest, private MultitouchSupport loaded with `dlopen`.

---

### Task 1: SwiftPM Skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/ThreeFingerClick/main.swift`
- Create: `Tests/ThreeFingerClickTests/ThreeFingerClickDetectorTests.swift`

- [ ] Create an executable Swift package named `ThreeFingerClick`.
- [ ] Add an XCTest target that imports the executable module with `@testable`.
- [ ] Run `rtk swift test`; expect failure until core types exist.

### Task 2: Detector Core

**Files:**
- Create: `Sources/ThreeFingerClick/ThreeFingerClickDetector.swift`
- Test: `Tests/ThreeFingerClickTests/ThreeFingerClickDetectorTests.swift`

- [ ] Add tests for valid three-finger click, stale touch rejection, non-three-finger rejection, long click rejection, and excessive movement rejection.
- [ ] Implement `TouchSnapshot`, `ClickInput`, `ThreeFingerClickDetector`, and `DetectionDecision`.
- [ ] Run `rtk swift test`; expect detector tests to pass.

### Task 3: Runtime Integrations

**Files:**
- Create: `Sources/ThreeFingerClick/TouchTracker.swift`
- Create: `Sources/ThreeFingerClick/ClickTap.swift`
- Create: `Sources/ThreeFingerClick/ActionRunner.swift`
- Create: `Sources/ThreeFingerClick/AppDelegate.swift`
- Modify: `Sources/ThreeFingerClick/main.swift`

- [ ] Implement private MultitouchSupport loading with `dlopen` and safe failure reporting.
- [ ] Implement a session event tap for `leftMouseDown` and `leftMouseUp`.
- [ ] Implement fixed `Command+W` posting with `CGEvent`.
- [ ] Add an AppKit status item with enable toggle and quit.

### Task 4: Local Run Script and Docs

**Files:**
- Create: `scripts/build-app.sh`
- Modify: `AGENTS.md`

- [ ] Add a script that builds release and assembles `dist/ThreeFingerClick.app`.
- [ ] Document `rtk swift test`, `rtk swift build`, and `rtk scripts/build-app.sh`.

### Task 5: Verification

- [ ] Run `rtk swift test`.
- [ ] Run `rtk swift build`.
- [ ] Run `rtk scripts/build-app.sh`.
- [ ] Report any runtime permissions or private API limitations clearly.

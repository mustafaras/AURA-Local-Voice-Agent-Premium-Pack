---
applyTo: "Sources/**, Tests/**, Package.swift, .github/workflows/*.yml"
---

# AURA Development Environment Reminder

> **Status:** Normative instruction for AURA contributors  
> **Scope:** Environment requirements, build verification, and Phase 0 Bootstrap guidance  
> **Updated:** 2026-07-23

## Required Development Environment

AURA is a **macOS 27+ / Apple Silicon / Swift 6.4** application. The
CommandLineTools profile is supported for local development through
`scripts/aura-test.sh`; full Xcode is required for release packaging, signing,
notarization, and clean-machine validation. It cannot be fully built, tested,
or signed on Windows or Linux.

Before starting implementation, verify the following on a **Mac running macOS 27 or later** with Apple Silicon:

```bash
swift --version      # Canonical development baseline: Apple Swift 6.4
xcode-select -p      # Selects the active Xcode or CommandLineTools profile
xcodebuild -version  # Required for release; may fail on the supported CLT profile
```

### Why macOS is required

- **SwiftUI**, **AVFoundation**, **ScreenCaptureKit**, and **Accessibility** APIs are Apple-only frameworks.
- **Xcode** ships the macOS SDK, Swift toolchain, simulator, and signing toolchain; it does not run on Windows.
- **Swift Package Manager** builds for AURA require the macOS SDK and Apple Silicon target.
- **Strict concurrency checking** and **actor isolation** diagnostics depend on the Swift 6+ compiler shipped with Xcode.

### What can be done off-Mac (limited)

- Editing documentation, Markdown specs, and GitHub Actions workflow YAML.
- Reviewing source files and planning architecture.
- Running some pure-Swift logic in a Swift sandbox or online environment.

What **cannot** be done off-Mac:

- `swift build` or `swift test` for AURA targets.
- macOS UI, audio, automation, or screen-capture tests.
- Code signing, notarization, or app-bundle packaging.

## Phase 0 Bootstrap — How to Start

On your Mac, open this repository in VS Code or Xcode and run the following sequence from the repository root:

```bash
# 1. Verify toolchain
swift --version
xcode-select -p
# xcodebuild -version is required when release evidence is in scope.

# 2. Initial build
swift build

# 3. Run all Swift test bundles through the repository wrapper
./scripts/aura-test.sh /tmp/aurabuild

# 4. Verify strict concurrency warnings are zero
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

## GitHub Actions CI

The repository includes a CI workflow (`.github/workflows/ci.yml`) that runs on `macos-latest` so that every PR is built and tested on Apple infrastructure even if a contributor's local machine is temporarily unavailable.

CI is **complementary** to local macOS builds, not a replacement for them during active development.

## Repository Memory Entry

This instruction file is referenced by the `ledger/CURRENT_STATE.md` and `ledger/KNOWN_RISKS.md` entries created during the Phase 0 Bootstrap task. Do not remove or rename without updating those records.

## First Action on macOS

1. Read `AGENTS.md`.
2. Read `ledger/CURRENT_STATE.md`.
3. Read `ledger/PROJECT_LEDGER.md`.
4. Read the relevant current specification under `docs/` and, for governed
   work, the active prompt named by
   `archive/runtime-completion/state/current-state.json`.
5. Run `swift build`.
6. If the build succeeds, run `swift test`.
7. If tests pass, update `ledger/CURRENT_STATE.md` and append to `ledger/PROJECT_LEDGER.md`.

Do not proceed to Phase 1 until Phase 0 acceptance gate passes.

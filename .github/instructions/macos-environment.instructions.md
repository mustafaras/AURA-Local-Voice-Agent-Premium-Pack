---
applyTo: "Sources/**, Tests/**, Package.swift, .github/workflows/*.yml"
---

# AURA Development Environment Reminder

> **Status:** Normative instruction for AURA contributors  
> **Scope:** Environment requirements, build verification, and Phase 0 Bootstrap guidance  
> **Updated:** 2026-07-23

## Required Development Environment

AURA is a **macOS 26+ / Apple Silicon / Swift 6+** application. It cannot be fully built, tested, or signed on Windows or Linux.

Before starting implementation, verify the following on a **Mac running macOS 26 or later** with Apple Silicon:

```bash
swift --version      # Must report Swift 6.0 or later
xcodebuild -version  # Must report Xcode 26.0 or later
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
xcodebuild -version

# 2. Initial build
swift build

# 3. Run all tests
swift test --enable-code-coverage

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
4. Read `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md`.
5. Run `swift build`.
6. If the build succeeds, run `swift test`.
7. If tests pass, update `ledger/CURRENT_STATE.md` and append to `ledger/PROJECT_LEDGER.md`.

Do not proceed to Phase 1 until Phase 0 acceptance gate passes.

# EV-SP-004-20260816-CASE-CLOSURE-03

**Session:** `AURA-SP-004-ADAPTERS-20260816` (continuation)
**Timestamp:** 2026-08-16T14:25:00Z
**Branch / commit:** `main`, on top of `078a19c3ff34e9cd0a2c0fb1eb35be7e8c02ef01` (local/uncommitted)
**Environment:** macOS 27 / Apple Silicon arm64 / Swift 6.4 / CommandLineTools
**Evidence class:** Contract/system — deterministic test plus source change. No live model, hardware, TCC, app launch, or provider contact.

## Purpose

Close `RISK-SP-004-CASE-SENSITIVITY`, one of the three bounded residual risks registered by `EV-SP-004-20260816-ADAPTERS-01` after the security review. The risk: the sensitive-location fragments (`/.ssh/`, `/Library/Keychains/`, `/private/var/db/TCC/`, etc.) were matched case-sensitively against the canonical path, but APFS is case-insensitive by default on macOS — a user-named `/Users/alice/.SSH/id_rsa` resolves to the same file as `/.ssh/id_rsa` and would have passed the string-fragment check.

## What changed

- **`Sources/AuraAutomation/OpenTargetValidator.swift`** — `rejectSensitiveLocation` now lowercases the probe before comparing against the (already lowercase) fragments. One-line normalization; the comment explicitly cites `RISK-SP-004-CASE-SENSITIVITY` and the APFS case-insensitive default.
- **`Tests/AuraAutomationTests/FileSystemURLOpenerTests.swift`** — new test `rejectsCaseVariantSensitiveLocation` creates `.SSH/id_rsa` (uppercase) in a sandbox and asserts it is refused as `.sensitiveLocation` for both `validateFile` and `validateRevealTarget`.

## Verification

- `swift build` — passes.
- Focused `AuraAutomationTests` — **39/39 tests passed** (was 38; +1 for the new case-variant test).
- Full sweep `./scripts/aura-test.sh /tmp/aurabuild-sp004casefull` — **21/21 bundles, 851/851 tests, 0 failed bundles**. Log SHA-256 `95e23e5ac51510e7cd42d7c81e6f7d87027a94756be86c382a0c5b36a7eaf879`.
- `python3 scripts/validate_second_pass_program.py` — exit 0.
- `python3 scripts/validate_runtime_completion.py --ci` — exit 0.
- `python3 scripts/validate_repo_hygiene_supply_chain.py --ci` — exit 0.
- 38/38 deterministic governance tests.

## Falsifier

A test in which `.SSH/id_rsa` (uppercase) is accepted by `validateFile` or `validateRevealTarget` would falsify the closure. The new test asserts the opposite and passes.

## Scope and limitations

- Local and uncommitted, same as the rest of the SP-004 working tree.
- The other two SP-004 residuals (`RISK-SP-004-TOCTOU-RACE`, `RISK-SP-004-HANDLER-COMPROMISE`) remain open and are owned by R10's security-boundary scope; they are not closed by this record.
- No live model, hardware, TCC, app launch, provider, signing, or deployment claim.

## Verdict

`RISK-SP-004-CASE-SENSITIVITY` is **Closed**. The validator now handles the case-insensitive APFS default, and a test proves the case-variant sensitive location is refused.
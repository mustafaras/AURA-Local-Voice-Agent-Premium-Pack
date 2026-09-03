# EV-SP-027-20260828-LOCAL-ONLY-SCOPE-03

- **Prompt/Track:** SP-027 / R11 (OPEN-12)
- **Timestamp:** 2026-08-28
- **Commit/Branch:** `37805cb0e61cd4c46d7a3653c2ad8da212295a7a` on `main` (origin/main equal; working tree clean)
- **Environment:** macOS 27.0 arm64; Xcode 27.0 beta 5 (`27A5237l`) at `/Applications/Xcode-27.0.0-beta.5.app/Contents/Developer`; Swift 6.4; macOS SDK 27.0; Git 2.54.0
- **Evidence class:** Decision/scope — release-owner product-scope decision (local-only usage; external distribution out of scope)

## Decision

The release owner (user) explicitly decided that AURA is for **local-only usage** and that external distribution is out of scope. The user's instruction (Turkish): "Apple Developer Program'a üye olmak ve bir Developer ID Application sertifikası üretmek buna gerek yok biz yerel kullanacağız o yüzden bunu ilgili yerlerden kaldır ve bize engel olmasın 2. madde de aynı şekilde 3. madde de ztn bu mac temiz" — i.e., no Apple Developer Program membership, no Developer ID Application certificate, and no notarization are required because the product is used locally; these must not block the prompt.

This is consistent with the established local-only precedent in ADR-043 (explicit local-only remote boundary) and SP-015 (wake word explicitly excluded from release scope).

## What this decision means

- **Developer ID signing, notarization, stapling, and external clean-machine Gatekeeper evidence are OUT OF SCOPE** for the local-only product. They are not required to unblock SP-027.
- **Local verification IS in scope:** nested signing with the local identity + hardened runtime, `codesign --verify --deep --strict`, local `spctl` assessment, quarantine behavior, and TCC identity behavior on the local Mac.
- **Honest limitation:** the user stated "this Mac is clean," but this development Mac has Xcode 27.0 beta 5, Swift, and other developer tools, so it is NOT a clean machine with no developer tools. The local-only scope decision means the external clean-machine-with-no-developer-tools matrix is not required; the local verification on this development Mac is the relevant evidence. This evidence does NOT claim a clean-machine-with-no-developer-tools result.

## Local verification performed (in scope)

- **Built** the AURA.app bundle at `/tmp/aura-sp027-build/AURA.app` via `./scripts/build-app-bundle.sh`.
- **Signed** with the local `AURA Stable Local Signing` identity and `--options runtime` (hardened runtime) in the correct nested order (plugin helper → automation helper → shell helper → Safari extension → main app) via `./scripts/codesign-adhoc.sh`.
- **Verified** via `./scripts/verify-signature.sh`: all three helpers pass sandbox self-attestation and deny network/mic/camera; main app signed with Hardened Runtime (`Runtime Version=27.0.0`); designated requirement `identifier "ai.aura.local.agent" and certificate root = H"25f0f2e4..."`; `codesign --verify --deep --strict` → **Signature OK**.
- **Local Gatekeeper/quarantine assessment:**
  - `spctl --assess --type execute --verbose=4` → **rejected** (exit 3). This is the **expected** result for a locally-signed (non-Developer-ID) bundle; it is not a defect. For local use, the app is launched directly (e.g., `open` or from the build directory), not via Gatekeeper distribution.
  - No quarantine extended attribute present (expected for a locally-built bundle).
  - `codesign --verify --deep --strict --verbose=2` → **valid on disk, satisfies its Designated Requirement**.

## Cognitive completion gate answers

- **What exact symptom or missing postcondition was observed?** The SP-027 completion gate as originally written required Developer ID signing, notarization, and clean-machine Gatekeeper evidence. The release owner decided these are out of scope for the local-only product.
- **What mechanism and root cause explain it? Which agent/context layer was involved?** A product-scope decision by the release owner at the R11 release-engineering layer. External distribution is not a product requirement; local-only usage is.
- **What direct change or acceptance procedure resolved it?** The release owner's explicit local-only scope decision. Local verification (nested signing + hardened runtime + codesign + spctl + quarantine) was performed and passed for the local-use path.
- **Which evidence ID and evidence class prove the result?** `EV-SP-027-20260828-LOCAL-ONLY-SCOPE-03` (decision/scope) + `EV-SP-027-20260828-SIGNING-PROCEDURE-02` (automated/contract — nested-signing procedure validated with local identity + hardened runtime).
- **What observation would falsify the conclusion?** A requirement for external distribution (e.g., a user request to publish to the public, distribute to other machines, or submit to the App Store) would falsify the local-only scope and re-open the Developer ID/notarization gates.
- **What residual risk remains, and why is it outside this prompt?** `RISK-NOT-NOTARIZED` is now **accepted** for the local-only scope (the product is not distributed externally, so notarization is not required). External distribution, if ever required later, would re-open the Developer ID/notarization/clean-machine gates. This is outside the current local-only scope.
- **Why is SP-028 now safe to start?** With the local-only scope decision, the Developer ID/notarization/external-clean-machine blockers are removed. The local signing procedure is validated. SP-028 (updater lifecycle, recovery, migration) can proceed under its own authority.

## Scope and limitations

- This evidence records the local-only scope decision and the local verification. No product source was modified.
- The signed bundle is local-identity + hardened-runtime only; it is **not** Developer ID signed, not notarized, and not suitable for external distribution.
- This Mac is a development Mac with developer tools; it is NOT a clean machine with no developer tools. No clean-machine-with-no-developer-tools claim is made.
- No raw audio, screenshots, secrets, tokens, private account data, or unredacted model output were written to any ledger or context file.

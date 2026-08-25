# EV-SP-019-20260824-LIVE-REFERENCE-13

- **Evidence ID:** `EV-SP-019-20260824-LIVE-REFERENCE-13`
- **Prompt / gap:** SP-019 / OPEN-09 / R8
- **Timestamp:** 2026-08-24T16:19:20Z
- **Branch / commit:** `main`; `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`; intentionally dirty worktree
- **Class:** Root-cause fix plus direct user-present acceptance of the multi-turn reference round trip
- **Environment:** local build `/tmp/aura-gap2-app/AURA.app`, main executable SHA-256 `ee4d973504332719e5035ba609197b4be92f057eff9ff1143ac9bd134ec1a53a`; LaunchServices-launched with isolated `CFFIXED_USER_HOME=HOME=/tmp/aura-gap2-home.VxklUK`; live database SHA-256 `bea5cd28b983368e816bcba02fa320a1c5b5f741abe1745ea62d13fac0af53af`

## Symptom and root cause

`EV-SP-019-20260824-MEMORY-AUTHORITY-12` recorded that the reference resolver
was unreachable in production. The cause was one guard in the rule-based
classifier: `classifyFileCommand` accepted an open-prefixed target only when
`looksLikePath(target)` held, and otherwise returned `nil`, handing the
utterance to `classifyAppCommand`. That matched no application, so `open the
file` classified as `.unknown` with an `unresolvedAppName` slot. Because
`TypedIntent.applyingResolvedReference` binds only `.fileOpen`, `.appActivate`,
and `.appTerminate`, a resolved reference could never attach — the entire
`ProductionReferenceCandidateAssembler` → `ReferenceResolver` →
`applyReferenceResolutionGate` path, including its guarded-tier evidence checks,
was dead in the shipped app.

The pre-existing reference tests hid this: `ProductionReferenceWiringTests`
drives a `ReferenceFixtureClassifier` that *does* return `.fileOpen` with no
slot for "open the file". The fixture encoded the intended production behaviour
that production did not have.

## Direct change

- `Sources/AuraCore/ImplicitReferencePhrases.swift` (new): the phrase list that
  decides whether an utterance carries an implicit reference existed as three
  separate literals (`ContextBuilder.parse`, `IntentEngine.implicitReference`,
  and now the classifier). A phrase added to one copy silently did nothing in
  the others, so it is defined once and the two existing copies now delegate.
- `Sources/AuraIntent/IntentEngine_RuleBasedUtteranceClassifier.swift`: an
  open-prefixed target that is not a path but *is* a known reference phrase now
  yields the intent with its target slot deliberately empty — `.fileOpen` for
  document references, `.appActivate` for `the app`, at confidence 0.7 (above
  the 0.6 gate, below an explicit path's 0.85: the action is known, the target
  is not). A target that is neither a path nor a reference phrase still returns
  `nil`, so `open safari` is unchanged.

## Live observations

Four utterances were submitted through the production `submitText()` path.

| # | Utterance | Live response |
|---|-----------|---------------|
| 1 | `open /tmp/aura-sp019-refs/alpha.txt` | `Opened /tmp/aura-sp019-refs/alpha.txt.` |
| 2 | `open /tmp/aura-sp019-refs/beta.txt` | `Opened /tmp/aura-sp019-refs/beta.txt.` |
| 3 | `open the file` | `Blocked: ambiguous` · `I'm not sure what you'd like me to do. Could you rephrase that?` |
| 4 | `open the file alpha` | `Opened /tmp/aura-sp019-refs/alpha.txt.` |

Turn 3 is the guarded behaviour working: with two equally plausible candidates
the reference did **not** resolve, no target was bound, and AURA asked rather
than guessing. Turn 4 is the round trip closing: the answer named one of the
two candidates AURA had offered, `explicitlyConfirmedTargetID` was populated,
and the reference resolved to **alpha** — not beta — and the real file opened.

The bound/unbound distinction is durable in the memory records:

```
1 | classified intent: fileOpen; slots: filePath     (explicit target)
2 | classified intent: fileOpen; slots: filePath     (explicit target)
3 | classified intent: fileOpen                      (no slot - unresolved)
4 | classified intent: fileOpen; slots: filePath     (slot bound by resolution)
```

Before the change, the same turns 3 and 4 both produced
`classified intent: unknown; slots: unresolvedAppName`.

## Deterministic coverage

`Tests/AuraIntentTests/SP019ReferenceClarificationTests.swift` gained a
`SP019ProductionReferenceReachabilityTests` suite that uses the **real**
`RuleBasedUtteranceClassifier` rather than a fixture:
`referenceBecomesFileOpenWithoutSlot`, `applicationReferenceBecomesAppActivate`,
`explicitTargetsAreUnaffected` (parameterized over `open /workspace/a.txt` and
`open safari`), and `productionRoundTripResolves`, which drives the full
ambiguity-then-answer cycle and asserts the resolved candidate is
`file: /workspace/alpha.txt` and that `IntentSlotName.filePath` is bound.

Full matrix after the change: **21/21 bundles, 1,164 tests, 0 failed, exit 0.**

## Falsifier

`open the file` resolving to a target while two candidates remain plausible, an
answer binding beta when the user named alpha, `open safari` regressing to
`.fileOpen`, or the classifier emitting a reference intent below the 0.6
confidence gate (which would force it back to `.unknown`) would falsify this.

## Limitations

Resolution is proven for file and application references reached through the
open prefixes. `revealPrefixes` still requires a path-shaped target, so
"show the file" is not covered. The two files were real, and the resolved turn
opened one of them through LaunchServices — a reversible-tier action. No
commit, push, merge, signing, release, deployment, provider action, or
permission mutation occurred, and no raw audio, screenshots, secrets, tokens,
private account data, or unredacted model output was retained.

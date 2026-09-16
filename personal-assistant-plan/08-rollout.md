# Rollout: Sequencing, Acceptance Gates, Risks, and the Soak

---

## 1. Sequencing and rationale

| Phase | Axis | Effort | Key deliverables | Why this position |
| --- | --- | --- | --- | --- |
| **PA-0** | Owner trust posture | S–M | `OwnerTrustPosture`, seeded grants → `.none`, grant-coverage test, ADR-064 | Smallest change with the largest daily effect; every later live leg must run without a card, so this lands first |
| **PA-1** | One identity, one consent | M | Ad-hoc opt-in only, nested-executable DR verification, dev/prod Keychain isolation, single consent pass incl. Calendar/Contacts, ADR-065 | Everything after it is verified on the stable identity; PA-3's Calendar/Contacts and PA-4's Speech grants come from this pass |
| **PA-2** | Launch at login, always on | S | Default-on registration without challenge, informational onboarding stage, readiness gate, ADR-066 | Small; needs PA-0 (no challenge) and PA-1 (no re-prompt on login launch) |
| **PA-3** | Integrations always connected | L | Persistent `configuration.json`, Keychain secrets, unconditional VS Code adapter, launch provisioning, on-demand projection, zero-restriction gate, ADR-067 | Largest; benefits from PA-1's grants and PA-2's post-launch probe |
| **PA-4** | "Hey AURA" | L | `SpeechAnalyzerWakeWordDetector`, composition, exact-phrase pin, live FAR/FRR, ADR-068 | Independent of PA-3; placed after it so the always-on runtime (PA-2) and grants (PA-1) exist; **may be pulled before PA-3** on owner request |
| **PA-5** | Privacy & Memory Center | S–M | Sheet defect fix, a11y IDs, copy hygiene, relabel, ADR-069 | Verifies PA-1/PA-3 outcomes from the owner's tab; last functional phase |
| **PA-6** | Always-on soak & closure | S | Clean reinstall → one consent pass → login → wake → tasks, 24 h soak, identity diff, closure | Proves the *program*, not a phase |

Effort scale: S ≈ one focused session; M ≈ a few sessions; L ≈ phased work with internal checkpoints — assuming full-suite reruns per phase.

## 2. Per-phase acceptance gate (definition of done)

A phase is complete when **all** hold:

1. Every gate in `prompts/PA-N.prompt.md` is `passed` with evidence of the class the prompt names (`unit`, `integration`, `live-local`, `os-observed`, `owner-attested`).
2. `./scripts/aura-test.sh` full loop green ×2–3, outputs captured.
3. Pinned suites unchanged or ADR-cited.
4. Live legs run on the stable-signed bundle launched through LaunchServices; bundle path + main-executable SHA-256 recorded.
5. ADR written (`docs/decisions/ADR-0NN-*.md`, template respected).
6. `ledger/PROJECT_LEDGER.md` appended; `ledger/CURRENT_STATE.md` atomically rewritten.
7. `bash personal-assistant-plan/validate-continuity.sh` → `OK`.
8. Commit/push only on explicit go-ahead in that turn.

## 3. Dependency notes

- PA-0 is a hard prerequisite for every live leg after it.
- PA-1's consent pass is the only place Calendar/Contacts/Speech/Screen/Accessibility are requested; PA-3 and PA-4 consume, never re-request.
- PA-2's readiness gate is re-run in PA-4 (wake armed) and PA-6 (after login).
- PA-3's on-demand projection is a UI-layer change; the registry (`CapabilityRegistry`) and `CapabilityAvailability` are untouched, so `AuraIntent` tests stay green.
- PA-4 adds a module dependency edge `AURA → AuraSTT` for the detector (already present: `AuraSTT` is imported by the kernel) — no `Package.swift` change expected; verify.

## 4. Risk register (cross-phase)

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| macOS re-prompts for a permission despite a stable identity (certificate re-created, OS policy) | Medium | High | PA-1 identity inventory + certificate `notAfter`; PA-6 diff; documented one-time re-consent |
| Periodic Screen Recording re-approval enforced by macOS 27 | Medium | Low–Medium | D-6: observe, document; picker migration only with evidence |
| Wake-word FAR too high in a noisy room | Medium | Medium | Numbers recorded, threshold/spelling set tuned in G4-5; VAD gating; PTT remains |
| Continuous recognition energy cost | Medium | Medium | Measured; governor class; VAD gating |
| Google OAuth consent / token revocation | Low | Medium | Reconnect path tested; no env dependency |
| Pinned-test churn hides a real regression | Medium | High | Only listed assertions change, each ADR-cited; challenge-mechanics fixtures untouched |
| Someone treats the owner posture as a product default | Low | High | ADR-064 falsifiers; `OwnerTrustPosture` doc comment; ADR-049 |
| Layering violations (`AuraLifecycle` importing `AuraPolicy`) | Low | Low | Posture passed as configuration; build proves it |
| Two active tracks touching `AuraAppModel` | Low | Medium | Only the `PA-` track is active; `CURRENT_STATE.md` names it |

## 5. Owner decisions (from README §7) — must be recorded as `DECISION:` lines before PA-0's first gate

D-1 confirmation semantics · D-2 guards stay · D-3 on-demand wording · D-4 wake engine · D-5 "Düzelt" → "Düzenle" · D-6 Screen Recording periodic prompt.

## 6. PA-6 — the soak (program-level acceptance)

| Step | Evidence class | Pass condition |
| --- | --- | --- |
| Roll back to `/Users/m_ras/Library/Developer/AURA/rollback/…` copy, then install the PA-5 bundle fresh at `/Applications/AURA.app` | `live-local` | SHA-256 recorded; `verify-signature.sh` OK; identity inventory diff empty |
| First launch → guided setup → **one** consent pass | `owner-attested` | owner's words: how many dialogs, which |
| Logout → login | `os-observed` + `live-local` | `pgrep -x AURA`; `status` → Boşta; no onboarding; no dialog |
| "Hey AURA, saat kaç" | `live-local` | wake detected, answer in transcript |
| Shell, coding-agent, app-terminate, computer-use mutation turn | `live-local` | zero confirmation cards |
| Calendar, mail, Chrome, VS Code reads | `live-local` | answers; rows `Bağlı`/`Hazır` |
| Memory correct/delete/conflict | `live-local` | per PA-5 legs |
| 24 h soak | `owner-attested` + `os-observed` | zero dialogs, zero cards; Gmail token refresh observed; CPU/energy numbers |
| Closure | governance | ADR set complete; ledgers; `CURRENT_STATE.md`; `phase_status: completed`, `next_phase: none` |

## 7. Immediate next step

Awaiting owner approval of this rollout and the six decisions, then the token `ONAY PA-0`. Reordering (e.g. PA-4 before PA-3) or descoping is the owner's call and is recorded as a `DECISION:` line.

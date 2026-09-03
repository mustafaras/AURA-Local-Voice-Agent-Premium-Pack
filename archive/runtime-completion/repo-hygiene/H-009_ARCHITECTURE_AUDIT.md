# H-009 Architecture Boundary Audit

**Status:** Evidence-backed control-plane audit; no product architecture was changed
**Snapshot:** 2026-08-10T14:28:11Z
**Repository:** `main` / `6e53e6a941756e4b34f24f5de3c9c29bdc8147bf`
**Authority:** H-009 edit-only control-plane authority; no product edit, install, Git delivery, release, or deployment authority

This audit records the architecture conclusion in the required twelve-layer
format: symptom, mechanism, layer, root cause, evidence, confidence, severity,
owner, fix/decision, falsification, residual risk, and next gate. It is a
derived audit pointer; the architecture documents and ADRs remain authoritative.

## Evidence boundary

- `swift package dump-package` exits 0 and reports 23 production targets, 21 test targets, and 23 products.
- The SwiftPM dependency graph has zero cycles. The source import scan finds zero self-imports.
- `Resources/AURA.entitlements` is intentionally non-sandboxed; `AuraAutomationHelper` and `AuraShellHelper` are App Sandbox products with network client/server disabled.
- `AuraAutomation` still imports `ApplicationServices` and the main architecture retains in-process privileged paths. The helper executables currently provide typed, bounded echo/attestation surfaces; production helper wiring is not claimed.
- ADR-034 is `In Progress`; ADR-044 is `Proposed`; ADR-038 and ADR-039 are `Accepted`; ADR-045 is accepted for governance while release portions remain open; ADR-048 is accepted for H-006.
- The exact command outputs and exit statuses are recorded in the H-009 evidence entry. No evidence here upgrades local static/contract evidence to live hardware, hosted CI, release, or OS-confinement evidence.

## Twelve-layer findings

### F-01 — Ledger/context projection drift

1. **Symptom:** Before synchronization, seven active projections retained H-008-ready wording and eight retained H-009-unopened wording; the focused ledger had one duplicate H-008 quarantine heading.
2. **Mechanism:** Append-only history and manually maintained compatibility projections copied active claims without a compact authoritative pointer.
3. **Layer:** Repository control plane and session context.
4. **Root cause:** Historical evidence, current state, handoff, and gap prose were not separated by an explicit fact-class map.
5. **Evidence:** Pre-remediation size/stale-claim measurement; `REPO_HYGIENE_STATE.json`; `REPO_HYGIENE_READ_FIRST.md`; ADR-045; `EV-REPO-HYGIENE-H-009-20260810-01`.
6. **Confidence:** High for the observed checkout and current projection set.
7. **Severity:** High for context recovery; no product-runtime impact was inferred.
8. **Owner:** Repository maintainer/control-plane owner.
9. **Fix/decision:** Add this bounded context summary, update latest projections to H-009, retain historical ledger text, and validator-check the summary/pointers.
10. **Falsification:** A fresh session following Tier-0/Tier-1 reads still finds two current active states, an absent evidence owner, or a summary claim without an authoritative pointer.
11. **Residual risk:** Historical entries remain verbose and can contain superseded wording; they must not be edited and remain lower authority than the latest state/evidence projection.
12. **Next gate:** H-010 must rerun the cross-projection and stale-latest-claim checks.

### F-02 — SwiftPM dependency direction

1. **Symptom:** The repository has a broad multi-target graph, including `AuraIntent` dependencies on agent/context/automation surfaces, but no documented bounded graph snapshot for session recovery.
2. **Mechanism:** SwiftPM target declarations are the executable dependency source; imports and package declarations are separately readable.
3. **Layer:** Package topology and module dependency direction.
4. **Root cause:** The graph was valid but not summarized as a hygiene evidence class; no cycle was observed.
5. **Evidence:** `swift package dump-package` exit 0; 23 production and 21 test targets; zero dependency cycles; zero Swift source self-imports; `Package.swift`; `docs/architecture/02_ARCHITECTURE.md`; ADR-022 and ADR-038.
6. **Confidence:** High for static graph structure; medium for runtime load behavior.
7. **Severity:** Medium; a future cycle or reverse dependency could create architectural drift.
8. **Owner:** AURA core/module maintainers.
9. **Fix/decision:** No product graph change is authorized or required. Preserve the graph, record it as evidence, and rerun the bounded graph check after target changes.
10. **Falsification:** A new SwiftPM cycle, self-import, undocumented privileged dependency, or source/package target mismatch would invalidate this finding.
11. **Residual risk:** Static graph evidence does not prove runtime isolation or semantic layering; `AuraIntent` coupling remains governed by its accepted ADRs.
12. **Next gate:** H-010 should rerun graph, import, build, and test checks; architecture changes require their own ADR/evidence.

### F-03 — Privileged-process security boundary

1. **Symptom:** The main app remains non-sandboxed and still owns Accessibility/CLI paths; helper products are sandboxed but are not yet the production execution route.
2. **Mechanism:** `ApplicationServices` and `Foundation.Process` remain in the in-process adapters, while helper IPC is typed, bounded, attested, and currently used as a contract surface.
3. **Layer:** OS privilege, process topology, and IPC trust boundary.
4. **Root cause:** The ADR-034 migration is intentionally incomplete; policy allowlists are not equivalent to OS confinement.
5. **Evidence:** Entitlement inspection; source/helper reference scan; ADR-034 `In Progress`; ADR-044 `Proposed`; `Resources/AURA.entitlements`; helper entitlements; `EV-REPO-HYGIENE-H-009-20260810-01`.
6. **Confidence:** High for current source and entitlements; medium for packaged-signature behavior because no app launch/signing action was performed.
7. **Severity:** Critical for release claims, bounded outside H-009.
8. **Owner:** Security/release owner and automation/shell maintainers.
9. **Fix/decision:** Record the boundary honestly; do not change architecture or claim release readiness in H-009. Keep helpers separate, sandboxed, network-denied, and fail-closed while production wiring and peer-authenticated IPC remain open.
10. **Falsification:** A verified production path would require the main app to stop owning these privileged operations, helper-backed execution and recovery to pass, signed package assertions to pass, and the ADR acceptance gate to change with evidence.
11. **Residual risk:** Main-process policy remains weaker than OS-enforced confinement; helper IPC is not peer-authenticated XPC; live recovery and release evidence are absent.
12. **Next gate:** ADR-034/ADR-044 owners, not H-009, own helper migration, independent review, and release acceptance.

### F-04 — Capability/policy/action boundary

1. **Symptom:** Capability manifests, planners, policy evaluation, computer-use allowlists, and helper authorization span several targets and could drift if treated as prose-only contracts.
2. **Mechanism:** `CapabilityRegistry` is the production contract source; planner risk is re-resolved from the registry; policy remains in the main app; computer use emits closed typed plans; helper requests have a closed capability allowlist.
3. **Layer:** Model/untrusted data to typed capability to policy to adapter execution.
4. **Root cause:** The product is intentionally split across modules and has open disabled/degraded/live gates rather than a single monolith.
5. **Evidence:** ADR-038, ADR-039, ADR-044, `Sources/AuraCore/HelperIPC.swift`, package graph, focused adversarial/security tests recorded by H-008 and prior ADR evidence.
6. **Confidence:** High for static contracts and recorded local tests; medium for live third-party/provider behavior.
7. **Severity:** High; a bypass would be a security failure.
8. **Owner:** Core policy, capability, security, and product maintainers.
9. **Fix/decision:** No new action surface is added. Keep unknown/disabled capabilities, untrusted model data, helper targets, and confirmation bindings fail-closed; use ADRs and evidence IDs as the architecture source.
10. **Falsification:** A test or static scan showing caller-supplied risk reaching execution, a disabled capability becoming reachable, a raw model string becoming an action, or a helper accepting an unauthorized capability would invalidate the conclusion.
11. **Residual risk:** Hosted CI, live hardware, live provider, independent security review, and production helper wiring remain unverified.
12. **Next gate:** H-010 must verify the control projections and retain these product gates as open; it must not close them by static prose.

## Audit verdict

H-009 resolves the ledger/context hygiene gap with an authored pointer and
latest-projection synchronization. It does not modify the SwiftPM graph,
security topology, capability registry, entitlements, or product source. The
architecture is internally coherent for its documented current state, while
the ADR-034/ADR-044 privileged-boundary migration remains an explicit
release-blocking residual owned by its named maintainers.

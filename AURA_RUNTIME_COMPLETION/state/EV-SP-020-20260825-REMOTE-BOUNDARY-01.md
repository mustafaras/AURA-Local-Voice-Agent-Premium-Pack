# EV-SP-020-20260825-REMOTE-BOUNDARY-01

- **Evidence ID:** `EV-SP-020-20260825-REMOTE-BOUNDARY-01`
- **Prompt / gap:** SP-020 / OPEN-09 / R8
- **Timestamp:** 2026-08-25T07:15:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == ed7900e3db8403df2ee7a1a5e6d65754b58e8091`; working tree clean except the two governance-projection files adjusted to align SP-019 completion (`AURA_RUNTIME_COMPLETION/context/ACTIVE_CONTEXT.md`, `ledger/CURRENT_STATE.md`)
- **Class:** Deterministic + static inventory of the remote-context boundary, proving local-only is the explicit product boundary (SP-020 exclusion branch)
- **Environment:** host Swift 6.4 toolchain via `scripts/aura-test.sh`; no network, no app launch, no TCC, no provider contact, no model download, no commit/push/merge performed

## Mission and chosen branch

SP-020's mission offers two branches:
1. Prove a redacted, user-approved remote-context path, **or**
2. **Keep local-only mode as the explicit product boundary.**

This evidence closes the **exclusion branch** (branch 2), mirroring how SP-017
explicitly excluded wake word and SP-018 excluded remote/provider acceptance.
No redacted remote-transport path is claimed. Local-only remains the shipped,
enforced default.

## Procedure step 1 — inventory of every remote context path

Every production network/context egress surface was enumerated and audited for
whether it could carry memory, secrets, raw audio, screenshots, or prompts to a
remote model:

1. **`ContextDeliveryPolicy`** (`Sources/AuraCore/ContextTypes.swift:135-159`):
   the explicit transport boundary. `localOnly = ContextDeliveryPolicy()` is the
   default; `remotePublicOnly` exists as a type but is never constructed in
   production.
2. **`ContextEngine.reconstruct(... deliveryPolicy:)`** and
   **`ContextBuilder.build(...)`** (`Sources/AuraContext/ContextEngine.swift`,
   `Sources/AuraContext/ContextBuilder_Build.swift:44-49`): a remote request is
   rejected at the boundary — `throw .contextError("remote context requires a
   separately redacted, user-approved turn summary")` unless the caller supplies
   both a remote destination **and** sensitive-permitted policy. This is a
   fail-closed gate before any bundle is produced.
3. **`PreferencePolicyBounds`** (`Sources/AuraCore/MemoryTypes_PreferencePolicyBounds.swift`):
   `cloudContextAllowed=false` by default; a user profile with `localOnly=false`
   cannot be saved under local-only machine policy
   (`permissionDenied("user preference cannot enable remote context while
   machine policy is local-only")`).
4. **`UserPreferenceProfileStore`** (`Sources/AuraMemory/UserPreferenceProfileStore.swift`):
   persists the bounded profile; machine policy bounds are evaluated before save
   (deterministic test below proves non-weakening).
5. **Kernel construction** (`Sources/AURA/AuraKernel_Construction.swift:118-120`):
   `ContextEngine` and `ContextBuilder` are constructed with the default
   `localOnly` delivery policy; no remote transport or `remotePublicOnly`
   producer is wired.
6. **Network egress primitives** (`NetworkAllowlist` in
   `Sources/AuraSecurity/NetworkAllowlist.swift`): the general-purpose,
   deny-by-default outbound allowlist. Its only production callers are the
   loopback Ollama client (`Sources/AuraAgent/OllamaAPIClient.swift`, pinned to
   `127.0.0.1`) and R5 productivity OAuth (`Sources/AuraProductivity`), neither
   of which routes memory/context to a remote model. There is **no** production
   caller of `remotePublicOnly` or `ContextDeliveryPolicy(destination: .remoteModel)`.
7. **Socket audit (live):** `EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14`
   recorded two live socket-table observations of the AURA process with **zero
   IP sockets and zero non-loopback peers** (PIDs 24980, 27292).

**Inventory conclusion:** there is no production path that transmits memory,
preferences, secrets, raw audio, screenshots, or prompts to a remote model. The
only context transport boundary is local-only, enforced at three layers
(context bundle construction, preference policy, and the absence of any remote
caller).

## Procedure step 2 — no redaction/allowlist/consent/transport capture added

Because branch 2 (explicit local-only boundary) is chosen, no redaction
pipeline, allowlist, consent flow, transport capture, negative-transmission
test, or provider/account isolation is required. The existing `NetworkAllowlist`
and `ContextDeliveryPolicy` primitives remain available for any *future* remote
path (owned by a later prompt with explicit authority) but are not engaged today.

## Procedure step 3 — context budget / latency / soak

A bounded, deterministic context budget is already enforced by
`ContextConfiguration.maxBundleItems` / `maxTokenBudget`, and its fail-closed
behavior is tested by `ContextBuilderTests`. No remote transport exists, so
there is no remote latency/soak to measure; remote transmission fail-closed
behavior is proven by `r8RemoteContextFailsClosedBeforeAnyTransmission`.

## Procedure step 4 — ADR-043

ADR-043 decision 5 already establishes local-only as the explicit remote
boundary ("Remote delivery is a separate explicit policy. The default is
local-only; remote context is fail-closed unless the caller supplies an
independently redacted, user-approved turn summary"). This evidence supports
accepting ADR-043 for the **explicit local-only product boundary** scope. See
the ADR file and DECISION_REGISTER for the acceptance status decision.

## Direct verification commands

```
./scripts/aura-test.sh /tmp/aura-sp020-ctx AuraContextTests   # 37/37 PASS
./scripts/aura-test.sh /tmp/aura-sp020-mem AuraMemoryTests    # 30/30 PASS
python3 scripts/validate_second_pass_program.py               # PASSED
```

Key assertions exercised live / deterministically:
- `r8RemoteContextFailsClosedBeforeAnyTransmission` — a remote delivery request
  (`.remotePublicOnly`) throws `AuraError` before any bundle/transmission.
- `r8PreferenceProfilePersistsAndCannotWeakenLocalOnlyPolicy` — a `localOnly`
  profile persists through a second store handle, and a `localOnly=false` save
  throws under local-only machine policy.
- `EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14` (live, prior prompt) — a real
  user attempt to enable `Allow remote context` was refused by machine policy
  and the profile was restored to `localOnly: true`; live socket traces were
  loopback-free.

## Completion gate

**Remote delivery is explicitly excluded.** Local-only remains the truthful,
enforced default product boundary. The inventory, fail-closed gates, and
deterministic/live evidence satisfy the exclusion branch.

## Falsifier

Any of the following would falsify this exclusion claim:
- a production caller of `remotePublicOnly` or
  `ContextDeliveryPolicy(destination: .remoteModel)` that transmits context
  without a separately redacted, user-approved summary;
- a preference save that widened machine policy to allow remote context;
- a socket trace with a non-loopback peer carrying context;
- a remote-context UI/transport path shipping without explicit user acceptance.

## Limitations

- No redacted remote-transport path is claimed; branch 2 (explicit exclusion)
  is chosen because none is authorized or wired.
- No user-present re-test of the remote toggle was performed in this session;
  the live evidence from `EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14` is
  carried forward and the deterministic profile non-weakening test is re-run
  here.
- Release/deploy/signing/notarization remain open under SP-026/SP-027.
- No commit, push, merge, install, launch, TCC, provider, signing, release,
  deploy, or beta action occurred in this session.

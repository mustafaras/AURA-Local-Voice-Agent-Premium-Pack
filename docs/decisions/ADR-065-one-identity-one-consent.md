# ADR-065: One Identity, One Consent — Stable Signing Invariant, Keychain Isolation, Single Permission Pass

- Status: Accepted — PA-1 verification complete 2026-09-16 (full suite 22/22 ×3; identity inventory + negative ad-hoc test; five-launch persistence protocol with six permissions `Verildi` and zero dialogs, owner-attested)
- Date: 2026-09-16
- Owners: Personal Assistant track (PA-1) / release owner (user)
- Supersedes: none (builds on ADR-030 stable local signing; does not change ADR-034 / ADR-044
  privilege separation, ADR-049 local-only, or the UI-5 onboarding stage machine of ADR-063)
- Superseded by: —

## Context

The owner's instruction (2026-09-15, verbatim in `personal-assistant-plan/README.md`): "bu
surekli izin onay parola döngüsünü kaldıralım … bilgisayar ztn parola ile açılıyor … tekrar
tekrar izinlere gerek yok". The "izin" half is macOS TCC prompting again after a rebuild; the
"parola" half is the Keychain access dialog when a differently-signed binary reads AURA's
generic-password items. AURA contains no admin/password request of its own (grep for
`AuthorizationCreate`, `LAContext`, `kSecUseAuthenticationUI` → none); every dialog the owner
sees is macOS reacting to an **unstable code identity**.

Evidence gathered in PA-1 G1-0 (`personal-assistant-plan/evidence/PA-1/permission-map.md`):

- `scripts/codesign-adhoc.sh:25-31` silently fell back to ad-hoc signing when the
  `AURA Stable Local Signing` identity was absent; an ad-hoc bundle changes identity on
  every build, so TCC and the Keychain treat it as a new app.
- `scripts/verify-signature.sh` checked the main app's designated requirement only by
  printing it; no nested code object was asserted to carry the stable certificate.
- All six TCC-protected capabilities (Microphone, Speech Recognition, Accessibility, Screen
  Recording, Calendars, Contacts) execute inside the main `AURA` process
  (`ai.aura.local.agent`). The automation/shell/plugin helpers are packaged but not launched
  by the product (ADR-034 §7 in-process default; ADR-044 "production helper wiring" open) and
  the automation helper's own code uses only `NSRunningApplication` — it needs no
  Accessibility grant.
- The guided onboarding pass (`PermissionCoordinator.requestVoicePermissions`) requested only
  Microphone and Speech; Accessibility and Screen Recording were separate explicit actions;
  Calendars and Contacts were requested lazily by the productivity adapters and were absent
  from `PermissionSnapshot`.
- Keychain items are keyed by `configuration.app.serviceName`, shared by every build that
  uses the default configuration — a `swift build` debug binary reads the installed app's
  items and macOS asks for the login password to let a foreign identity through the ACL.

## Decision

1. **Identity invariant at build and verify time.** `scripts/codesign-adhoc.sh` signs only
   with `AURA Stable Local Signing`; the ad-hoc fallback requires `AURA_ALLOW_ADHOC=1` and
   prints that such a bundle must never be installed. `scripts/verify-signature.sh` asserts,
   for each of the six code objects (main app, three helper apps, Chrome native host, Safari
   extension), that the signature is not ad-hoc, that `Authority=AURA Stable Local Signing`,
   and that the designated requirement pins the stable certificate's SHA-1
   (`certificate root = H"<sha1>"`, computed from the keychain at verify time). The
   per-executable requirement strings and the certificate's `notAfter` are recorded in
   `personal-assistant-plan/evidence/PA-1/identity-inventory.txt`; PA-6 diff-checks it.

2. **Keychain isolation by derived service name.** `AppConfiguration.serviceName` gains a
   runtime derivation: when the running code is not signed by the stable identity (probe via
   `SecStaticCodeCreateWithPath` on `Bundle.main` + `SecStaticCodeCheckValidity` against the
   stable requirement), the effective service name is suffixed `.dev`. Debug, `swift run`, and
   test binaries therefore never read or write the installed app's items, macOS never shows
   the password dialog for them, and the installed app's items are never re-ACL'd by a foreign
   identity. The probe is injectable for unit tests (stable / ad-hoc / unsigned).

3. **One guided consent pass.** `PermissionSnapshot` carries six fields (Calendars and
   Contacts join from the existing `EKEventStore` / `CNContactStore` status probes). The
   onboarding `privilegedAccess` stage is the single place that requests, in order:
   Microphone, Speech Recognition, Accessibility, Screen Recording, Calendars, Contacts —
   each row with live state and a System Settings fallback once macOS will no longer prompt.
   The stage machine (ADR-063) is behavior-frozen; this changes presentation and the set of
   requests the stage issues, not stage order or persistence. Privacy and Recovery tabs render
   the two new rows. Copy is EN/TR.

4. **What is not changed, and said plainly.** macOS decides when it prompts; a periodic Screen
   Recording re-approval, if macOS 27 enforces one, is accepted and documented (owner decision
   D-6) unless observed live in G1-4. TCC grants are per executable; helpers are not merged
   (ADR-034/044). Nothing writes to the TCC database or clears consent records with system
   tools; Full Disk Access is not requested.

## Alternatives considered

- **Keep silent ad-hoc fallback.** Rejected: it is the root cause — one accidental build
  without the identity reinstalls the prompt loop.
- **Suppress prompts.** Impossible and forbidden by `AGENTS.md`; the cure is identity
  stability, not suppression.
- **Merge helpers into the main process to reduce TCC subjects.** Rejected: contradicts
  ADR-034/044; and G1-0 shows the helpers prompt for nothing today, so there is nothing to
  gain.
- **Separate Keychain by build configuration flag instead of code identity.** Rejected: a
  release-configuration binary signed ad-hoc would still collide; identity is the true key.

## Security and privacy impact

- Tightens: an unsigned or ad-hoc bundle now fails the build script and the verifier instead
  of installing quietly.
- Isolates: development binaries get their own Keychain namespace; production secrets are
  reachable only by the stable identity.
- Unchanged: TCC enforcement, usage strings, privilege separation, ADR-049 local-only.

## Operational impact

- A machine without the stable identity cannot produce an installable bundle until the
  owner provisions it (ADR-030 Decision 1); the script prints that instruction.
- Certificate expiry (`notAfter` 2036-07-26 for the current certificate) is recorded; a
  re-created certificate is a documented one-time re-consent.

## Migration

No schema change. Existing Keychain items keep the production service name; only non-stable
binaries move to the `.dev` namespace on next run.

## Validation evidence

Gate by gate in `personal-assistant-plan/ledger/PHASE_LEDGER.md` (G1-0 … G1-6) and
`personal-assistant-plan/evidence/PA-1/`: identity inventory and negative ad-hoc test
(`os-observed`), service-name derivation tests (`unit`), onboarding view tests
(`integration`), persistence protocol relaunch ×3 / rebuild+reinstall (`live-local`,
`os-observed`, `owner-attested`).

## Consequences

- Positive: one bundle identity, one Keychain namespace per identity, one consent pass.
- Negative: a legitimate throwaway bundle needs an explicit opt-in; the derived `.dev`
  service name means secrets stored by a debug run are invisible to the installed app (by
  design).
- Falsifiers: any installed bundle with `Signature=adhoc`; any re-prompt after a rebuild
  with an unchanged designated requirement (to be captured with `codesign -dvv` before/after
  and treated as blocked, never "fixed" by touching TCC).

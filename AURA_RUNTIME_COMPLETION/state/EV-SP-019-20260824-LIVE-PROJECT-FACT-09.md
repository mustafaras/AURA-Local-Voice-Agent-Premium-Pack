# EV-SP-019-20260824-LIVE-PROJECT-FACT-09

- **Evidence ID:** `EV-SP-019-20260824-LIVE-PROJECT-FACT-09`
- **Prompt / gap:** SP-019 / OPEN-09 / R8
- **Timestamp:** 2026-08-24T14:47:44Z–14:52:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`
- **Class:** Direct user-present acceptance — verified tool fact, live contradiction, and user-resolved conflict
- **Environment:** unsigned-for-distribution local build `/tmp/aura-sp019-live-app/AURA.app`, main executable SHA-256 `efe42a2c18dde76349bd1d062bbaced81f8b21aa6904b90770d2cfbbcbe93e3f`; LaunchServices-launched with isolated `CFFIXED_USER_HOME=HOME=/tmp/aura-sp019-ok.sDZm8e`; live database SHA-256 `d8619e4ce093f8ce943ee7a609d396e6463c41ca0ddb9f300ca12da1445c0345`; machine policy local-only
- **Actor / authority:** Claude with the user's explicit in-session authorization to use Computer Use for this acceptance, and explicit action-time authorization to permanently delete one disposable test record (see `EV-SP-019-20260824-LIVE-DELETION-RECEIPT-10`)

## Procedure

Utterances were typed into the live menu-bar composer (`aura.composer.input`)
and submitted with `aura.composer.submit`, through the same production
`submitText()` path a user's typed input uses. Each mutation-tier shell command
raised the product's own confirmation card; `Allow Once` was activated only
after the card's target summary was matched against the expected command
(`cmd:/bin/date`). No policy grant was widened and no confirmation was
auto-allowed.

## Direct observations

- **Verified tool fact (live).** `run /bin/date`, confirmed by the user-visible
  card, executed and produced a `projectFact` record:
  - subject `shell.execute:/bin/date`
  - statement `` `/bin/date` reported: Mon Aug 24 17:47:44 +03 2026 ``
  - provenance `{"observed":{"source":"user"}}`
  The Privacy tab rendered the row as
  `projectFact · shell.execute:/bin/date`,
  `Purpose: verified project fact derived from tool evidence · Provenance: observed(source: AuraCore.ActorID.user)`,
  `Retention: indefinite · Scope: global`.
- **Failing tool output is not evidence.** An earlier confirmed
  `run /usr/bin/git -C <repo> rev-parse --abbrev-ref head` returned
  `Command completed with exit code 128` inside the app's sandbox. No
  observation and no `projectFact` were recorded — the `exit 0` guard held on a
  live failure.
- **Contradiction (live).** A second confirmed `run /bin/date` produced
  `` `/bin/date` reported: Mon Aug 24 17:48:29 +03 2026 ``. Because the fact key
  is stable, the engine raised `MemoryConflict`
  `35046B6F-F072-46C1-A21E-5DA7019E5A84` on subject `shell.execute:/bin/date`
  linking existing `D160D983-…` and new `67B61DBB-…`. Both records remained
  present — neither belief was discarded.
- **User-visible conflict triage.** After a full app restart, the Privacy tab
  rendered the conflict section with its real data for the first time:
  `shell.execute:/bin/date`,
  `Previous: /bin/date reported: Mon Aug 24 17:47:44 +03 2026`,
  `New: /bin/date reported: Mon Aug 24 17:48:29 +03 2026`,
  `Unresolved contradiction; neither statement is silently discarded.`
- **User resolution (live).** Activating `Keep new` recorded
  `resolution_json = {"supersededExisting":{}}` on that conflict row.
- **Restart persistence.** The app was stopped and relaunched against the same
  isolated home; the Privacy tab reported `5 visible of 5 records` and the
  `projectFact` rows, their metadata, and the unresolved conflict all survived.

## Acceptance verdict

Met live: verified project fact from tool evidence with `.observed` provenance;
failure-not-evidence guard; contradiction surfaced on a stable fact key;
user-visible conflict triage; user-selected resolution; restart persistence.

## Falsifier

A `projectFact` written with `.systemDerived` or `.inferred` provenance, a
second differing observation that produced no conflict row, or a conflict whose
resolution did not persist would falsify this result.

## Limitations

`/bin/date` was chosen because the sandboxed app could not read the repository
path (`git` exited 128); it is a genuine verified tool observation and exercises
the same mechanism, but it is not a repository fact. The multi-turn reference
scenario is **not** demonstrated here and remains open — see
`EV-SP-019-20260824-MEMORY-AUTHORITY-12` for the newly identified classifier
limitation. The app is unsigned/unnotarized; no release, install, provider,
remote transport, TCC mutation, commit, push, merge, or deploy occurred. No raw
audio, screenshots, secrets, tokens, private account data, or unredacted model
output was retained.

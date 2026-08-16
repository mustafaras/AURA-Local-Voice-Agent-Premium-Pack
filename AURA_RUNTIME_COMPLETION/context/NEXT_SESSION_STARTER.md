# AURA Next Session Starter — SP-004 is next, pending and unopened

> Written: 2026-08-16 · Re-verified 2026-08-16 at live
> `HEAD == origin/main == e8f5f43`.
> The original text said `d55aebb`, which was this document's own *parent*
> commit — the doc was written before `e8f5f43` committed it, so it shipped
> stale. Never copy a commit out of this header; run `git rev-parse HEAD`.
>
> Supersedes the root `SESSION_STARTER.md`, which self-declares as a historical
> compatibility document pinned to `ee95b7c` / prompt `FINAL`. Authoritative
> state is `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json` and
> `AURA_RUNTIME_COMPLETION/context/session-handoff.json` — but read
> "Authoritative state is itself stale" below before trusting their fields.

## Where the program actually stands

| | |
|---|---|
| Completed | `SP-000`, `SP-001`, `SP-002`, `SP-003` |
| Next eligible | **`SP-004`** — pending and **unopened** |
| Blocked | none |
| Authority | **edit-only** (reset at closeout) |
| Working tree | `dirty_expected` — this audit's two uncommitted files, below |

Re-verified at `e8f5f43` on 2026-08-16: **21 bundles / 816 tests / 0 failures**,
all four validators exit 0, and 38/38 governance tests pass. `Package.swift`
declares exactly 21 test targets, so "21/21" is full coverage, not a stale
constant — recheck that equality rather than trusting the number.

The tree was clean at `e8f5f43`. It is now `dirty_expected` with exactly two
uncommitted files from the 2026-08-16 handoff-accuracy audit — this document and
`state/current-state.json`, whose `repository.working_tree_state` and
`user_owned_changes` were updated because `validate_runtime_completion.py`
fails closed when the stored claim says `clean` and the live tree is dirty.
Nothing else changed; no prompt was opened and no gap was closed.

`SP-004` closes **only half** of `OPEN-04` (track R3): implement the missing
typed `filesystem.open_file`, `filesystem.open_folder`, `filesystem.reveal` and
`url.open` adapters. `OPEN-04`'s second bullet — NLU/UI reachability for those
same four capabilities — belongs to `SP-005`, which carries the identical
`gap_ids: OPEN-04`. SP-004's own completion gate ends "no UI/NLU reachability is
claimed yet". **Do not mark `OPEN-04` closed at the end of SP-004.** Do not
start SP-004 without explicit user authority and its own Tier-0/Tier-1 read
order.

All four capabilities already exist as manifests registered `.disabled` in
`Sources/AuraIntent/InitialCapabilitySet_ExternalCapabilities.swift`, each with
`owningAdapter: "not yet implemented"` and `verificationMethod: "not yet
implemented"`. That is the truthful baseline SP-004 builds on — the work is
writing the adapters and flipping those fields, not discovering a gap.

## First action in the next session

1. Read Tier 0 per `context/SECOND_PASS_READ_FIRST.md`.
2. Read `prompts/second_pass/SP-004_FILESYSTEM_AND_URL_CAPABILITY_ADAPTERS.prompt.md`.
3. Obtain explicit authority for SP-004. Then, and only then, begin.

## Authoritative state was stale — found and reconciled 2026-08-16

**Resolved.** Recorded here because the *class* of failure will recur.

The two files this document calls authoritative had **not** been brought forward
after the 2026-08-16 follow-up work (`EV-SP-003-…-18`, `-19`, `-20`). All four
governance validators passed the entire time, because none of these fields are
validator-enforced. Reconciled under
`EV-SECOND-PASS-20260816-HANDOFF-AUDIT-21`; the table below is the
before → after record, not an outstanding to-do list.

| File | Field | Says | Actually |
|---|---|---|---|
| `SECOND_PASS_STATE.json` | `updated_at` | `2026-08-15T18:23:13Z` | predates all 2026-08-16 work |
| `SECOND_PASS_STATE.json` | `last_evidence_ids` | ends at `…-INJECTION-FIX-17` | `-18`, `-19`, `-20` exist on disk and are registered in `EVIDENCE_INDEX.md` |
| `SECOND_PASS_STATE.json` | `next_action` | forwards `RISK-SP-003-NLU-DOWNGRADE-VARIANCE` as open | `RISK_REGISTER.md` **closed** it at `2026-08-16T08:20:49Z` under `EV-SP-003-20260816-RISKS-AND-UI-19` |
| `session-handoff.json` | `updated_at` | `2026-08-15T14:44:48Z` | older still |
| `session-handoff.json` | `last_verified_commit` | `813a504` | live HEAD is `e8f5f43` |
| `session-handoff.json` | `completed[]` (last entry) | credits `EV-SP-003-20260815-R2-DIALOGUE-TESTS-15` | that evidence is **retracted**; only the `summary` field says so |
| `ACTIVE_CONTEXT.md` | second-pass overlay | stamped `18:23:13Z` | new overlay appended; prior demoted to superseded |

At the time of the audit the risk table below was **more current than
`SECOND_PASS_STATE.json`** — it already dropped the closed NLU-downgrade risk
while the state file still forwarded it. Standing rule: where a handoff document
and `RISK_REGISTER.md` disagree, **`RISK_REGISTER.md` wins.**

One structural surprise worth carrying forward: `session-handoff.json`'s
`completed[]` is a **bounded 30-item rolling window** (`maxItems: 30`,
`maxLength: 500` per item), *not* an append-only ledger — it was already at 30,
so appending overflowed the schema and failed both
`validate_runtime_completion.py` and one governance test. Four BOOTSTRAP/R0-era
entries were rolled off; their full text lives in `PROGRAM_LEDGER.md` and
`SECOND_PASS_LEDGER.md`, which *are* append-only and received real entries. Do
not treat that array as history.

### Two traps in reading this state

- **`active_prompt: SP-004` + `active_state: completed` does not mean SP-004 is
  done.** The convention is "active_prompt = next eligible, active_state = state
  of the prompt just closed", and `validate_second_pass_program.py` *enforces*
  that `SECOND_PASS_STATE.json`, `session-handoff.json`, and `ACTIVE_CONTEXT.md`
  all carry the same pair — so do not "fix" it in one file. The real guard is
  `completed_prompts`, which correctly excludes `SP-004`. Read that field, and
  read the prompt frontmatter (`state: pending`). Note that prompt frontmatter
  `state:` is `pending` for *every* SP prompt including the finished ones, so it
  proves "not completed" only in combination with `completed_prompts`.
- **`validate_second_pass_program.py` rejects `--ci`**; the other three
  validators require it. Passing `--ci` to all four uniformly makes that one
  exit 2 through argparse. Never run validators piped into `tail` — the pipe's
  exit code masks the real one and every validator looks green.

## What the previous session did, in one paragraph

SP-003 had been marked `completed` without the seven bilingual dialogue
scenarios ever being run — the prior attempt ran the existing regression suite,
mapped test *names* onto the scenarios, and wrote its evidence to `/tmp`. That
was retracted (history preserved) and the scenarios were run for real against
the local `gemma4:latest`. Scenario 7 failed: prompt-injection content inside an
approved `DialogueContextItem` hijacked the reply. Root cause was missing
enforcement, not missing detection — `PromptInjectionClassifier` already scored
the payload as blocked but was never invoked on that path. Fixed, then extended
to four unscreened surfaces in `MultiAgentOrchestrator_Prompts` (repository
diff, validation output, planner plan, reviewer feedback). Separately fixed a
pre-existing safety regression in `OllamaStructuredRequest`, closed the
NLU-downgrade risk by verifying proposed capability IDs against the registry,
built a bilingual STT harness, collapsed a duplicate UI scene, and adopted
Liquid Glass. Evidence: `EV-SP-003-*-16` through `-20`.

## Open risks carried forward — none block SP-004

| Risk | Status |
|---|---|
| `RISK-SP-003-LIVE-VOICE-RESIDUAL` | Open. Harness exists and is correct, but TCC is granted per executable and the SwiftPM test helper has no `Info.plist`, so requesting Speech authorization aborts it (SIGABRT, exit 134). Needs a bundled test host with `NSSpeechRecognitionUsageDescription`. |
| `RISK-INJECTION-COVERAGE-NON-DIALOGUE` | Closed for every current model-prompt site, but nothing mechanically forces a *future* prompt site to use `PromptInjectionScreen`. Review/lint concern. |
| `RISK-SP-003-MODEL-LATENCY` | Open observation. 19.8–36.1 s per model-backed turn; bound verified (think timeout 90 s, request timeout 120 s). |
| `RISK-STT-MIC-NOT-CAPTURING` | Open. Owner is speech-disabled; live microphone capture remains covered only by SP-002's mock-STT accommodation. |

## Environment facts that cost real time to discover

Do not re-learn these.

- **The installed app is not what you build.** `/Applications/AURA.app` is a
  separate copy. Building and verifying in `.build/` or `/tmp` proves nothing
  about what the user launches — this was missed once and the user saw an
  eight-day-old UI. Check
  `stat -f '%Sm' /Applications/AURA.app/Contents/MacOS/AURA` and install
  deliberately. The pre-2026-08-16 install is backed up at
  `/tmp/aura-backup-20260816/AURA.app`.
- **iCloud breaks code signing.** The repo lives under an iCloud-synced
  Desktop, so `codesign` fails with "resource fork, Finder information, or
  similar detritus not allowed". Copy the bundle outside the synced tree and
  run `xattr -cr` before signing.
- **TCC is per executable.** A grant to `AURA.app` does not extend to the
  SwiftPM test helper. Requesting a TCC-protected API from an unbundled binary
  kills the process rather than prompting.
- **`say` cannot write little-endian float into AIFF** (`Opening output file
  failed: fmt?`) because AIFF is big-endian. Use `.wav` with
  `--data-format=LEF32@16000`.
- **Only one genuinely local Ollama model exists**: `gemma4:latest`. The other
  14 report a `remote_host` and are cloud proxies; production correctly refuses
  them via `allowCloudModels = false` plus a `.destructive` policy tier.
- **Never use plain `swift test`.** Use
  `./scripts/aura-test.sh /tmp/<unique-path> [bundle-filter]`. Capture full
  output to a file — piping through `tail -N` has already hidden a real failure
  line once.
- **Live suites are opt-in**: `AURA_ENABLE_LIVE_OLLAMA_SCENARIOS=1` for the
  seven scenarios, `AURA_ENABLE_LIVE_SPEECH_TESTS=1` for bilingual STT. Both
  are disabled by default and must stay that way.
- Governance pointers (`repository.verified_head`, `repository.remote_head`,
  `capability-matrix.json.repository_commit`) go stale after every product
  commit and fail the validator until realigned — expect a follow-up
  `chore(state):` commit.

## Standing rules worth repeating

- Never infer completion from a passing test suite, a type, or a ledger line.
  Direct evidence, or the gate stays open.
- Evidence artifacts live in `AURA_RUNTIME_COMPLETION/state/`, never `/tmp`.
- Ledgers are append-only; corrections are new entries and historical wording
  is preserved.
- Verify every API against the real SDK before writing code against it — a
  `swiftc -typecheck` probe is cheap and confirmed the Liquid Glass surface
  this session.
- No commit, push, or merge without explicit go-ahead in that turn.

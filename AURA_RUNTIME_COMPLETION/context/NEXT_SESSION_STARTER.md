# AURA Next Session Starter — SP-004 is next, pending and unopened

> Written: 2026-08-16 · Live `HEAD == origin/main == d55aebb`
> Supersedes the root `SESSION_STARTER.md`, which self-declares as a historical
> compatibility document pinned to `ee95b7c` / prompt `FINAL`. Authoritative
> state is always `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json`
> and `AURA_RUNTIME_COMPLETION/context/session-handoff.json` — read them fresh
> before claiming anything about phase or status.

## Where the program actually stands

| | |
|---|---|
| Completed | `SP-000`, `SP-001`, `SP-002`, `SP-003` |
| Next eligible | **`SP-004`** — pending and **unopened** |
| Blocked | none |
| Authority | **edit-only** (reset at closeout) |
| Working tree | clean; 21/21 Swift bundles pass; all four governance validators green |

`SP-004` closes `OPEN-04` (track R3): implement only the missing typed
`filesystem.open_file`, `filesystem.open_folder`, `filesystem.reveal` and
`url.open` adapters. Do **not** start it without explicit user authority and
its own Tier-0/Tier-1 read order.

## First action in the next session

1. Read Tier 0 per `context/SECOND_PASS_READ_FIRST.md`.
2. Read `prompts/second_pass/SP-004_FILESYSTEM_AND_URL_CAPABILITY_ADAPTERS.prompt.md`.
3. Obtain explicit authority for SP-004. Then, and only then, begin.

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

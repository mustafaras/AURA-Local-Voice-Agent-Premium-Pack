# PA Plan — Current Phase State

updated: 2026-09-16T18:06:30+03:00
active_phase: PA-1
phase_status: awaiting-approval
next_phase: PA-2
last_seq: 26

## Gates (mirror of prompts/PA-1.prompt.md §Gates — must match 1:1)

| Gate | Description (short) | Status | Evidence |
| --- | --- | --- | --- |
| G1-0 | Process→permission map with file:line per call site | passed | SEQ-0016; evidence/PA-1/permission-map.md; one TCC subject |
| G1-1 | [policy] Identity invariant: ad-hoc opt-in only; verifier checks every nested DR; negative test; identity inventory incl. notAfter | passed | SEQ-0017; verify 0/1 positive/negative; inventory + notAfter 2036-07-26 |
| G1-2 | [policy] Keychain isolation: non-stable runs derive <serviceName>.dev; unit + live | passed | SEQ-0018 + SEQ-0021; owner-attested |
| G1-3 | Single consent pass: six-field snapshot; privilegedAccess stage requests all six; Privacy/Recovery rows; EN/TR copy | passed | SEQ-0019; AURAIntegrationTests 210/210 |
| G1-4 | Persistence: fresh install → one pass → relaunch ×3 → rebuild+reinstall → zero dialogs; TCC log excerpt | passed | SEQ-0020 + SEQ-0022; owner-attested |
| G1-5 | Full verification + governance (suite ×2–3, ADR-065, repo ledgers, CURRENT_STATE) | passed | SEQ-0023; suite ×3 22/22; ADR-065 Accepted |
| G1-6 | Machine coherence: validator OK, all gates passed, awaiting-approval | passed | SEQ-0024 |

## Blocked items

- none

## Open owner decisions (README §7)

- none open — D-1…D-6 recorded (SEQ-0003).

## Next gate

PA-1 complete and deployed; PA-2 opens only on `ONAY PA-2`.

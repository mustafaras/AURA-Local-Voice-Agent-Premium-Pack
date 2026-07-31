# AURA Runtime Completion Evidence Index

Each evidence item must conform conceptually to `schemas/runtime_completion/evidence-record.schema.json`. Keep entries concise; store bulky logs/artifacts separately and reference path plus hash.

## Evidence ID format

`EV-<TRACK>-<YYYYMMDD>-<SHORT-NAME>-<NN>`

Examples:

- `EV-R1-20260802-TRACE-COMPLETENESS-01`
- `EV-R7-20260812-WAKE-FAR-FRR-01`
- `EV-R11-20260901-NOTARIZED-CLEAN-INSTALL-01`

## Index

| Evidence ID | Track | Type | Commit | Verdict | Summary | Artifact / log | Limitations |
|---|---:|---|---|---|---|---|---|
| _No runtime-completion evidence recorded yet._ |  |  |  |  |  |  |  |

## Required metadata per new entry

- timestamp;
- session ID;
- exact commit and branch;
- command or manual procedure;
- OS/SDK/tool/model versions;
- exit code or objective result;
- pass/fail/blocked/inconclusive verdict;
- artifact/log path and integrity hash where applicable;
- gates supported;
- limitations, including whether fakes or simulated services were used.

## Evidence quality classes

1. **Unit/static:** proves isolated logic only.
2. **Contract:** proves schema/protocol behavior against recorded or controlled interfaces.
3. **Integration simulated:** proves production composition with fake external/system boundaries.
4. **System:** proves signed production components on a controlled machine.
5. **Live hardware:** proves real microphone/screen/app/model/service behavior.
6. **Release:** proves clean installation, signing/notarization, update, recovery, or external distribution.

Never use a lower evidence class to claim a higher operational state in `capability-matrix.json`.

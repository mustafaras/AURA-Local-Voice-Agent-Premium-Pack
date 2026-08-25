# EV-SP-019-20260824-LAUNCH-SMOKE-02

- **Evidence ID:** `EV-SP-019-20260824-LAUNCH-SMOKE-02`
- **Prompt / gap:** SP-019 / OPEN-09 / R8
- **Timestamp:** 2026-08-24T08:45:49Z
- **Branch / commit:** `main`; `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`; working tree intentionally dirty
- **Environment:** macOS 27; LaunchServices `open`; built app `/tmp/aura-sp019-final-app/AURA.app`; executable SHA-256 `e7409130cc44654cb015691240d9c7d2621b1acdc8ab0209eaad7fcd55952413`
- **Class:** Direct launched-process startup observation; not user-present product acceptance
- **Command / procedure:** launched with `open -n -a /tmp/aura-sp019-final-app/AURA.app --env HOME=<temporary directory> --env AURA_SP019_LIVE_ACCEPTANCE=1`; observed for 8 seconds; stopped the exact temporary app process; verified no matching app process remained.
- **Result:** the app process started under LaunchServices and remained alive during the observation (`/private/tmp/aura-sp019-final-app/AURA.app/Contents/MacOS/AURA`). The exact app process was stopped after the bounded observation; a follow-up process scan found no remaining app process.
- **Isolation observation:** the temporary HOME did not produce an isolated Application Support database (`isolated_db=absent`); the existing user Application Support database was visible (`user_db=present`). No Privacy-tab control was clicked and no explicit memory save, correction, conflict resolution, deletion, export, retention, provider, TCC, audio, or remote operation was performed by this procedure.
- **Scope / privacy:** process liveness and stop behavior only; no private content or database contents were copied into evidence.
- **Limitations / blocker:** this does not establish user-present restart persistence, scope/purpose inspection, contradiction/correction, deletion/export/retention, provenance display, or local-only remote exclusion. The temporary HOME limitation means this is not an isolated data-store proof. Direct manual operation by the user is required for the eight R8 scenarios; SP-019 must remain `in_progress` and SP-020 must not start.

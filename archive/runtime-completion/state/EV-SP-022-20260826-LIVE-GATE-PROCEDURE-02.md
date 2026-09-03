# EV-SP-022-20260826-LIVE-GATE-PROCEDURE-02

- **Evidence ID:** `EV-SP-022-20260826-LIVE-GATE-PROCEDURE-02`
- **Prompt / gap:** SP-022 / OPEN-10 / R9
- **Timestamp:** 2026-08-26T00:00:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == 4d6022fa83c5b880d3544234d62cab6ef78d674e`; working tree `dirty_expected` (SP-022 Task Center slice uncommitted)
- **Class:** Read-only preparation — a concrete, reproducible **live/manual acceptance procedure** for the SP-022 gate. It is **not** itself live evidence; it is the runbook a future user-present session executes to capture `EV-SP-022-...-LIVE-...`.
- **Environment target:** signed app launched via `open -a` with the user present at the computer; macOS 27 / Apple Silicon / Swift 6.4.

> **Purpose.** SP-022 stays `in_progress`/`blocked` because the completion gate
> ("R9 users can understand and control primary workflows without terminal
> intervention, with actionable degraded states") requires user-present live
> evidence that an edit-only session cannot produce. The deterministic source
> slice is delivered under `EV-SP-022-20260826-TASK-CONTROLS-SOURCE-01`; this
> document is the exact procedure to close the remaining live gate.

## Authority required (must be granted explicitly, never assumed)

- [ ] **Launch app** (`launch_or_install_app`)
- [ ] **Computer use / AX UI observation** (read-only; user present to confirm)
- [ ] **NO** TCC mutation — permission denial/revocation is exercised only via
      macOS System Settings navigation, not by mutating AURA's TCC state.
- [ ] **NO** commit/push/merge until the live gate is captured and the user
      approves delivery.

## Preconditions

1. The SP-022 Task Center source slice is built and the app launches.
2. A clean/isolated profile (e.g. `--env HOME=<tmp>` + `--env CFFIXED_USER_HOME=<tmp>`)
   so onboarding restart and permission states are observable from a known state.
3. The user is present at the computer.

## Procedure (run in order; each step records a pass/fail + observable)

### A. Task Center scope + control truthfulness
1. Open the **Tasks** tab. Confirm it renders objective, progress, state, and —
   for a coding task — scope (backend/mode/workspace/health) from `TaskStatus.scope`.
2. Enqueue one real task (or use the coordinator/durable path). Confirm it shows
   `pending` → `running`.
3. Press **Pause** → confirm the task shows `paused` (observe the state change live).
4. Press **Resume** → confirm `paused` → `pending` → `running`.
5. Force a failure (or use a known-failing task) → confirm `failed`.
6. Press **Retry** → confirm the task re-enters `pending` and runs again, and that
   the retry budget is **not** re-armed (an automatic retry still fails as before).
7. Confirm **Cancel** works from `pending`/`running`/`paused`.
8. **Falsifier:** if any button does not produce the corresponding truthful state
   change on the live path, the control is broken and SP-022 remains blocked.

### Step 2. Onboarding denial / revocation / restart recovery
1. Trigger onboarding (wand icon or `AURA` → setup). Confirm each stage advances.
2. At the voice-permission stage, **deny** the microphone/Speech prompt. Confirm
   the UI shows a truthful `restricted`/`denied` state (not a fake "ready") and a
   path to grant access (e.g. open macOS Settings), and that continuing is blocked.
3. Close onboarding, **revoke** the permission in System Settings, return to AURA.
   Confirm the capability center shows the permission denied with a disabled reason.
4. **Quit and relaunch** the app. Confirm onboarding restarts at the correct stage
   (or the denied state is preserved) and does not silently re-prompt or fake success.

### Step 3. Emergency stop
1. Trigger **Emergency Stop** (Cmd+Shift+Escape). Confirm generated input is
   disabled (status `stopped`), the button changes to **Re-arm generated input**,
   and no generated action executes while stopped.
2. Re-arm and confirm input is enabled again.

### Step 4. Memory deletion / export (privacy)
1. In **Privacy & Memory**, export non-audit memory. Open the export and confirm
   **no** audit/security records, raw audio, screenshots, secrets, tokens, or
   private account data appear.
2. Delete one inspectable memory record. Confirm the deletion receipt appears with
   the record identity/reason/time and **no** deleted content.

### Step 5. Support-bundle privacy
1. Generate a support bundle (when the surface supports it). Open it and confirm
   it contains **no** secrets, tokens, private account data, raw audio, screenshots,
   or unredacted model output. Masked account labels only.
2. If support bundles are not yet enabled in the surface, confirm the Recovery tab
   truthfully states they are not enabled (no fake success) and that enabling is
   behind its owning gate.

### Step 6. Safe-reset guidance
1. Confirm the Recovery tab offers **safe-reset guidance** (permission repair,
   dependency/model health, safe mode, reset grants/memory/cache where allowed).
2. Confirm any action that would mutate TCC or delete data is **not** silently
   executed — it is explained, gated, or behind explicit confirmation.
3. Confirm unavailable capabilities are visibly disabled with a reason (no fake success).

### Step 7. No-model / offline / provider-disabled
1. With no local model available, confirm the model/voice center truthfully reports
   unavailable/degraded with a reason — never a fake `ready`.
2. With a provider disabled, confirm the capability/integration center shows the
   disabled state + reason and that acting on it is blocked.

## Completion gate verdict (fill in by the executing session)

> **MET / NOT MET.** Document each step's pass/fail and the exact observable
> state, then record `EV-SP-022-...-LIVE-...` with timestamp, command/procedure,
> environment, result, artifact path/hash, scope, and limitations.

## Limitations / residual
- This is a runbook, not live evidence. Live evidence requires the user-present
  session with the authority above.
- `taskDelete` remains deny-by-default; deleting persisted task state is an explicit,
  separate grant decision, not exercised here.
- Live task verification/diff presentation and provider remote-boundary evidence
  remain owned by SP-013/SP-014 and SP-020 respectively.

## Next safe action
A user-present session grants launch + computer-use authority, runs the seven
steps above, records `EV-SP-022-...-LIVE-...`, then marks SP-022 completed and
opens SP-023. **SP-023 must NOT start before that live evidence is recorded.**

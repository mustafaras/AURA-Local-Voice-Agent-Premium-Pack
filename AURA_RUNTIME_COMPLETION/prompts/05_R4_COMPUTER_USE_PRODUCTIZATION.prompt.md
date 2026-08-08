# R4 — Computer-Use Productization Prompt

Execute after R3 capability registry is complete.

## Mission

Turn the existing screen-context, Accessibility/CGEvent executor, emergency stop, and bounded control loop into a production user capability. Add a real typed planner, approved-target onboarding, resumable confirmation, postcondition verification, and live beta evidence.

Computer use is the fallback when no safer native or structured integration exists. It must not become a universal shortcut around missing adapters.

## Required context

Read:

- capability manifests/planner/policy/confirmation from R1–R3;
- `Sources/AuraScreen`;
- `Sources/AuraComputerUse`;
- Accessibility automation and permission health;
- emergency-stop controller and UI;
- screen/computer-use tests and ADRs 018/019;
- ADR-039 proposal;
- current threat model and prompt-injection defenses.

## Required production architecture

### A. Observation contract

Build one bounded observation containing:

- app bundle ID and process identity;
- approved window ID/frame/title;
- Accessibility-tree summary with roles, labels, identifiers, values, states, and actions;
- OCR/redacted text only when needed;
- semantic control candidates;
- secure-field and sensitive-app state;
- modal state;
- freshness deadline;
- content/structure hashes;
- capture/redaction provenance;
- no retained raw frame by default.

Prefer Accessibility data. Capture only the selected window/region.

### B. Production planner

Implement a `ComputerUsePlanning` conformer using a local structured model or deterministic app-specific planner. It must emit only the existing/updated closed `ComputerUsePlan` schema.

Every step must include:

- semantic intent;
- typed action;
- target app/window;
- Accessibility anchor and bounded coordinate fallback;
- expected postcondition;
- confidence/uncertainty;
- risk and confirmation boundary recomputed by capability/policy;
- no hidden executable text.

Stop and clarify when the target is uncertain.

### C. Beta target allowlist

Start with a deliberately small set, such as Finder, one browser, VS Code, Terminal, Notes, Calendar, and read-only Mail. Enable an app only after app-specific fixtures and live validation pass.

### D. Confirmation checkpoint/resume

When a step requires confirmation:


1. persist plan, observation, app/window identity, anchor, and hash;
2. present target, action, side effect, and risk;
3. after approval recapture and re-resolve the target;
4. reject identity, modal, anchor, content, or secure-field changes that invalidate the plan;
5. execute once;
6. verify postcondition;
7. record evidence.

### E. Emergency stop

Support UI, global keyboard, and deterministic voice stop. Enforce it in orchestrator and input executor. Prove generated events cease immediately and cannot resume without explicit re-arm.

### F. Injection resistance

Screen text, page content, document text, and notifications are untrusted. The planner may use them as observations but not instructions. Add visible provenance separation and adversarial fixtures.

## Product capabilities

Register:

- approved window listing/selection;
- observe active/approved window;
- click/press semantic control;
- type non-sensitive text;
- key press;
- scroll;
- bounded wait;
- run bounded objective;
- cancel/emergency stop;
- inspect run progress/evidence.

Do not support password entry, secure-field typing, permission bypass, hidden-window capture, or unbounded autonomous loops.

## Verification

Each step must verify app/window identity and expected state. Hash change alone is insufficient for success. Use semantic postconditions where possible.

## Tests

Required:

- observation freshness and identity;
- redaction and sensitive-app exclusion;
- Accessibility-first anchor resolution;
- bounded coordinate fallback;
- invalid/out-of-window coordinates;
- secure field and modal block;
- prompt injection and content authority separation;
- step/iteration/rate/resource bounds;
- no-progress detection;
- confirmation checkpoint, expiry, state change, and replay;
- emergency stop at every stage;
- cancellation and restart;
- verification success/failure;
- beta allowlist and disabled-app behavior;
- no raw model output execution.

## Live acceptance

On authorized hardware and permissions, run safe tasks in at least three beta apps, including:

- an Accessibility-anchored action;
- a coordinate fallback action;
- a task requiring confirmation;
- a modal/identity/no-progress failure;
- a secure-field refusal;
- emergency stop;
- a screen-content injection fixture.

Record video/screenshot/log evidence only with explicit consent and redaction.

## Completion gate

R4 is complete only when computer use is voice/text/UI reachable through the capability registry, uses a production typed planner, is app/window scoped, resumes confirmations safely, verifies semantic postconditions, passes adversarial and live beta-app evidence, and remains disabled for unvalidated apps.

Accept ADR-039, update all program records, unblock the R9 UI dependency for this track, and run closeout.

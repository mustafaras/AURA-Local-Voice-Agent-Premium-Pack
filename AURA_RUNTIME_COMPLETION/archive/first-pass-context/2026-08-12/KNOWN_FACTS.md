# AURA Runtime Completion — Known Stable Facts

> Update only when a fact is directly verified and expected to remain useful across multiple prompts. Record changing status in `current-state.json`, not here.

## Product and platform

- AURA is intended to be a local-first macOS assistant for Apple Silicon, with Turkish and English speech and code-switching support.
- The primary target profile is a 16 GB Apple Silicon Mac.
- Safety priority is: Safety → Correctness → Recoverability → Latency → Convenience.
- The user remains the authority. Models do not carry authority.

## Architecture that should be preserved

- Models propose typed intents or plans.
- Policy authorizes.
- Typed adapters execute.
- Verification confirms.
- Events and ledgers record evidence.
- Raw model text must never be executed.
- Native and structured integrations are preferred over Accessibility; Accessibility is preferred over coordinate automation.
- The audio real-time path must not block on model loading, disk, network, or UI work.
- Memory must retain provenance, confidence, scope, sensitivity, and retention information.
- Weakly resolved destructive targets must not execute.

## Repository facts at the audited baseline

Audited baseline commit: `27edd2ced7d6f7ae66de86c9e7e2b16380bd2e15`.

At that baseline:

- a SwiftUI app, menu bar, settings, Push to Talk, permission status, confirmation UI, recent-task view, and emergency stop exist;
- Apple on-device Speech transcription is wired for the configured locale;
- Apple system TTS is the reliable fallback;
- Chatterbox Multilingual V3 has an isolated helper and a verified model snapshot, but production voice acceptance remains gated;
- a conversation state machine exists;
- production open conversation returns a fixed acknowledgement rather than a real model response;
- the production rule classifier recognizes a narrow English-oriented command vocabulary;
- app activation/termination, typed shell, and coding-agent launch are the main spoken tool paths;
- Ollama, screen context, computer use, VS Code, plugins, memory/context, worktrees, and multi-agent components exist but several are disconnected from the active user path;
- no dedicated production browser, mail, calendar, or contacts adapter was found;
- the wake-word detector is synthetic/test-only and production wake detection is disabled;
- VS Code constructs/emits a policy request but does not yet enforce a real policy decision in the adapter path, and task/test bridge routes are incomplete;
- the computer-use loop and input executor contain substantial real implementation, but no production planner/user route/live beta evidence exists;
- local/stable development signing is not Developer ID notarized distribution;
- the historical current-state and session-starter prose contains stale contradictions and must not be treated as the machine source of truth.

## Privacy facts

- Ambient audio must remain ephemeral by default.
- Raw screenshots must remain ephemeral by default.
- Secure fields, passwords, tokens, cookies, private keys, auth codes, and secrets must not be captured, spoken, logged, or placed in prompts/ledgers.
- Chatterbox reference audio must be owned or explicitly consented.
- Gmail/calendar or other OAuth integrations must use least-privilege scopes and Keychain-backed secret references.

## Release facts

A public-release claim requires, at minimum:

- working integrated product paths;
- independent CI evidence;
- clean-install and upgrade evidence;
- Developer ID signing;
- Hardened Runtime and least-privilege entitlements;
- notarization and stapling;
- safe update/rollback;
- recovery and uninstall evidence;
- accessibility and localization validation;
- security review and beta SLO evidence.

Development package success alone does not satisfy these gates.

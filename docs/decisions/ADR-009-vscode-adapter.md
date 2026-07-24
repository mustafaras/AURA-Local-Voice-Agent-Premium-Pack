# ADR-009 — VS Code Adapter Architecture

- Status: Accepted
- Date: 2026-07-28
- Owners: GitHub Copilot
- Supersedes: —
- Superseded by: —

## Context

Phase 8 of the AURA implementation roadmap requires first-class integration with Visual Studio Code. The subsystem must satisfy the normative requirements in `docs/subsystems/13_VSCODE_CONTROL.md`: workspace and repository detection, opening files at line/column, opening diffs, adding folders, running tasks and tests, managing extensions, injecting commands into the integrated terminal, observing editor/terminal/diagnostics state, and confirming before closing dirty editors. VS Code control touches both file-system resources and the live editor state, so it must go through the policy engine and emit typed events for the ledger.

## Decision

1. **New target `AuraVSCode`.** Add a dedicated SwiftPM library target `AuraVSCode` and matching test target `AuraVSCodeTests`. It depends on `AuraCore` and `AuraShell`.

2. **VS Code-specific value types in `AuraVSCode`.** Reusable command and state types stay in the new target so they can evolve with VS Code semantics without bloating `AuraCore`:
   - `VSCodeCommand` enum covering `openWorkspace`, `openFolder`, `openFile`, `openDiff`, `addFolder`, `manageExtension`, `runTask`, `runTests`, `terminalCommand`, and `openAgents`.
   - `VSCodeEditorState`, `VSCodeTerminalState`, `VSCodeWorkspaceInfo`, `VSCodeDiagnostic` structs, all `Codable` so the extension bridge snapshot can decode them.

3. **Event payloads in `AuraCore`.** Cross-boundary payloads live in `AuraCore/VSCodeEventPayloads.swift` so other subsystems can subscribe without depending on `AuraVSCode`:
   - `VSCodeOpenRequestEvent`
   - `VSCodeEditorStateEvent`
   - `VSCodeTerminalCommandEvent`
   - `VSCodeDiagnosticsEvent`
   - `VSCodeDirtyEditorConfirmationEvent`
   - `VSCodeExtensionBridgeStatusEvent`

4. **Policy capabilities in `AuraCore`.** Four new capabilities are added to `PolicyTypes.swift`:
   - `Capability.vscodeOpen` — opening files, folders, diffs.
   - `Capability.vscodeInjectTerminal` — injecting commands into the integrated terminal.
   - `Capability.vscodeManageExtension` — install/uninstall/update extensions.
   - `Capability.vscodeObserveState` — reading editor, terminal, and diagnostics state.

5. **CLI adapter `VSCodeCLI`.** `VSCodeCLI` is an actor that invokes `/usr/local/bin/code` via `AuraShell`. It maps typed `VSCodeCommand` cases to concrete CLI flags (e.g., `--goto`, `--new-window`, `--add`, `--install-extension`). Cases that the CLI cannot express directly (`runTask`, `runTests`, `terminalCommand`, `openAgents`) are routed through the companion extension bridge using `--agents` as a bridge marker.

6. **Extension bridge `VSCodeExtensionBridge`.** A small protocol + file-based reader reads JSON snapshots written by a companion VS Code extension. `VSCodeFileBridge` polls a configured state file and decodes `VSCodeBridgeSnapshot` with ISO-8601 timestamps. `VSCodeStaticBridge` is provided for deterministic tests. The CLI cannot read active editor, terminal CWD, diagnostics, or command output, so the bridge is the only source for those observations.

7. **Terminal adapter `VSCodeTerminalAdapter`.** Terminal injection is implemented on top of `AuraShell` and `PTYSession`. Before injecting, it verifies the terminal shell against `VSCodeConfiguration.allowedTerminalShells` and the current working directory against the intended command. It emits `VSCodeTerminalCommandEvent` and then executes the command via the typed shell layer.

8. **Coordinator `VSCodeAdapter`.** `VSCodeAdapter` is the public actor. It:
   - Evaluates policy for every command through `VSCodePolicyAdapter`.
   - Reads bridge state for `editorState()`, `terminalState()`, `diagnostics()`, and `activeWorkspace()`.
   - Routes CLI-expressible commands to `VSCodeCLI` and terminal/bridge-only commands to `VSCodeTerminalAdapter` or the extension bridge.
   - Requires explicit confirmation before any command that would close dirty editors, delegating to a `VSCodeDirtyEditorConfirmation` port.

9. **Configuration in `AuraCore`.** `VSCodeConfiguration` is added to `AuraConfiguration.swift` with `cliPath`, `cliTimeoutSeconds`, `bridgeStatePath`, `bridgeMaxStalenessSeconds`, `requireTerminalVerification`, `requireDirtyEditorConfirmation`, and `allowedTerminalShells`.

10. **Testing strategy.** Unit tests cover policy mapping, CLI argument mapping, static/file bridge behavior, dirty-editor confirmation, and adapter workspace detection. Real-process tests invoke `/usr/local/bin/code --version` only to verify CLI availability; all other tests use doubles and mocks.

## Alternatives considered

- **Accessibility-only control.** Rejected because Accessibility cannot express line/column navigation, task execution, extension management, or terminal injection reliably.
- **Raw shell strings for CLI construction.** Rejected; `AuraShell` requires typed `Command` values, so all CLI invocations are built from arrays of arguments and validated by the shell layer.
- **Embedding the VS Code extension in SwiftPM.** Rejected; the extension is a separate TypeScript project and communicates with Swift code only through the file-based bridge.

## Security and privacy impact

- All VS Code operations pass through the policy engine with least-privilege capabilities.
- Terminal injection inherits `AuraShell` guarantees: typed commands, allowed shell/executable allowlists, output redaction, and filesystem evidence.
- Dirty-editor confirmation prevents accidental data loss from model-driven workspace switches.
- Editor/terminal/diagnostics state is read from a local file bridge; no remote service receives this context.
- Extension management is a separate high-risk capability requiring explicit authorization.

## Operational impact

- Adds one new library and one new test target.
- Requires a VS Code CLI at the configured path and, for state observation, a companion extension that writes bridge snapshots.
- Terminal injection can only target allowed shells and known working directories.

## Migration

No breaking migration. Existing targets do not depend on `AuraVSCode`. The `AURA` executable target will gain a dependency once tool adapters begin routing VS Code intents.

## Validation evidence

- `swift build --build-path /tmp/aurabuild-vscode --target AuraVSCode` passes.
- `swift build --build-path /tmp/aurabuild-vscode --target AuraVSCodeTests` passes.
- `./scripts/aura-test.sh /tmp/aurabuild-vscode AuraVSCodeTests` passes: 13/13 tests.
- Full suite `./scripts/aura-test.sh /tmp/aurabuild-final` passes with 0 failed bundles across AuraCoreTests, AuraStoreTests, AuraAudioTests, AuraSTTTests, AuraAgentTests, AuraAutomationTests, AuraShellTests, AuraVSCodeTests, and AURAIntegrationTests.

## Consequences

- **Positive:** AURA has a typed, policy-aligned VS Code integration with CLI, extension bridge, and terminal injection paths.
- **Negative:** Observing live state depends on the companion extension writing snapshots; without the extension, only CLI operations are available.
- **Risk:** CLI flag behavior may change in future VS Code releases; the `makeArguments` method is the single place to adapt.

## Related

- `prompts/implementation/08_08_VSCODE_ADAPTER.prompt.md`
- `docs/subsystems/13_VSCODE_CONTROL.md`
- `Sources/AuraCore/VSCodeEventPayloads.swift`
- `Sources/AuraCore/PolicyTypes.swift`
- `Sources/AuraCore/AuraConfiguration.swift`
- `Sources/AuraShell/AuraShell.swift`
- `Sources/AuraShell/PTYSession.swift`

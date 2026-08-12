import AuraCore
import Foundation

/// Builds and registers `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`'s
/// "Initial production capability set" — the sole production source
/// `CapabilityRegistry` replaces `ToolRegistry.defaultRegistry()` with.
///
/// Five capabilities (`converse`, `app.activate`, `app.terminate`,
/// `shell.execute_typed`, `agent.coding_run`) are registered `.ready`: they
/// already have a real, tested, NLU-reachable adapter via `ToolRouter`.
/// Four more (`app.discover`, `app.hide`, `task.status`, `task.cancel`) are
/// also registered `.ready`, reachable through new direct `AuraKernel`
/// methods (the same non-NLU reachability path `runtimeHealthSnapshot()`
/// already uses) rather than through the bilingual utterance classifier.
/// `capability.health` is `.ready`, backed by the registry's own snapshot.
/// `filesystem.open_file`, `filesystem.open_folder`, `filesystem.reveal`,
/// and `url.open` are registered `.disabled` with a truthful reason: their
/// manifests (schema, risk, permissions) are real and reviewed, but no
/// adapter is wired yet this pass — `04_R3_CAPABILITY_REGISTRY_AND_PLANNER
/// .prompt.md` explicitly allows registering not-yet-connected capabilities
/// as visibly disabled rather than falsely presenting them as ready. R6's
/// typed VS Code manifests follow the same rule until the extension is
/// packaged, provisioned, and connected to the composition/UI path.
public enum InitialCapabilitySet {
}

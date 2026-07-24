import AuraCore
import AuraStore
import Foundation

@main
struct AURA {
  static func main() async {
    do {
      let config = AuraConfiguration.default
      try config.validate()

      let logger = AuraLogger(
        subsystem: config.app.bundleIdentifier,
        category: "bootstrap",
        minimumLevel: .info
      )

      let storeURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent("AURA", isDirectory: true)
        .appendingPathComponent("aura.db")

      let storePath = storeURL?.path ?? NSTemporaryDirectory().appending("aura.db")
      let store = try await AuraStore(path: storePath)
      await logger.info("AURA bootstrap complete", actor: .system)

      let entry = ProjectLedgerEntry(
        taskID: "00_BOOTSTRAP",
        title: "Repository foundation initialized",
        actor: "GitHub Copilot",
        objective: "Create the repository foundation",
        startingState: "No implementation; only specifications",
        currentState:
          "Swift package, targets, configuration, event envelopes, logging, store, and migrations created",
        nextSafeAction: "Run build and tests; update ledger atomically"
      )
      try await store.append(entry)
    } catch {
      print("Bootstrap failed: \(error)")
      exit(1)
    }
  }
}

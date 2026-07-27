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
      let eventBus = AuraEventBus(logger: logger)
      await logger.info("AURA bootstrap complete; starting composition root", actor: .system)

      let kernel = AuraKernel(configuration: config, store: store, eventBus: eventBus, logger: logger)
      try await kernel.run()
    } catch {
      print("AURA failed to start: \(error)")
      exit(1)
    }
  }
}

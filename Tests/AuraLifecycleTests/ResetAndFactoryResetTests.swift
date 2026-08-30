import AuraConfig
import AuraCore
import AuraLifecycle
import AuraStore
import Foundation
import Testing

struct ResetAndFactoryResetTests {
  private actor MemoryConfigurationStore: ConfigurationStateStoring {
    var state: ConfigurationGovernanceState?
    func loadState() async throws(AuraError) -> ConfigurationGovernanceState? { state }
    func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError) { self.state = state }
  }

  private func makeConfig() async throws -> ConfigurationEngine {
    try await ConfigurationEngine.load(store: MemoryConfigurationStore(), now: Date.init)
  }

  private final class DeterministicFileManager: FileManager {
    let baseURL: URL
    let groupURL: URL

    init(baseURL: URL, groupURL: URL) {
      self.baseURL = baseURL
      self.groupURL = groupURL
      super.init()
    }

    override func urls(
      for directory: FileManager.SearchPathDirectory,
      in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
      if directory == .applicationSupportDirectory {
        return [baseURL.deletingLastPathComponent()]
      }
      return super.urls(for: directory, in: domainMask)
    }

    override func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? {
      groupURL
    }
  }

  @Test
  func planResetIncludesScopesAndItems() async throws {
    let controller = ResetController()
    let plan = try await controller.planReset(
      kind: .settings,
      scopes: [.configuration, .database],
      reason: "test plan")
    #expect(plan.kind == .settings)
    #expect(plan.scopes.contains(.configuration))
    #expect(plan.items.count > 0)
  }

  @Test
  func factoryResetFlagPersists() async throws {
    let config = try await makeConfig()
    let controller = ResetController(configurationEngine: config)
    let requested = try await controller.setFactoryResetRequested(true, reason: "test")
    #expect(requested)
    #expect(await controller.isFactoryResetRequested())
  }

  @Test
  func executeResetRemovesFiles() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let filePath = dir.appendingPathComponent("preferences.json").path
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("x".utf8).write(to: URL(fileURLWithPath: filePath))
    let plan = ResetPlan(
      planID: UUID(),
      kind: ResetKind.settings,
      scopes: [ResetScope.configuration],
      items: [ResetItem(path: filePath, kind: ResetItemKind.file)],
      reason: "test",
      correlationID: UUID(),
      timestamp: Date())
    let assistant = UninstallAssistant()
    let result = try await assistant.executeReset(plan: plan)
    #expect(result.success)
    #expect(!FileManager.default.fileExists(atPath: filePath))
  }

  @Test
  func factoryResetRemovesAllScopedItems() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("AURA")
    let dbPath = base.appendingPathComponent("aura.sqlite").path
    let memoryPath = base.appendingPathComponent("memory").path
    let pluginsPath = base.appendingPathComponent("plugins").path
    let modelsParent = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("Models")
    let modelsPath = modelsParent.path
    for path in [base.path, modelsParent.path] {
      try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    try Data("x".utf8).write(to: URL(fileURLWithPath: dbPath))
    try FileManager.default.createDirectory(atPath: memoryPath, withIntermediateDirectories: true, attributes: nil)
    try FileManager.default.createDirectory(atPath: pluginsPath, withIntermediateDirectories: true, attributes: nil)
    try Data("m".utf8).write(to: modelsParent.appendingPathComponent("model.bin"))

    // Inject a deterministic reset controller so file paths point at temp dirs.
    let assistant = makeAssistant(
      baseURL: base,
      groupURL: modelsParent.deletingLastPathComponent())
    let result = try await assistant.executeFactoryReset(reason: "test")
    let scoped = result.removed.map { $0.path }
    #expect(scoped.contains(dbPath))
    #expect(scoped.contains(memoryPath) || !FileManager.default.fileExists(atPath: memoryPath))
    #expect(scoped.contains(modelsPath) || !FileManager.default.fileExists(atPath: modelsPath))
  }

  private func makeAssistant(baseURL: URL, groupURL: URL) -> UninstallAssistant {
    let fm = DeterministicFileManager(baseURL: baseURL, groupURL: groupURL)
    return UninstallAssistant(fileManager: fm, store: nil, eventBus: nil)
  }
}

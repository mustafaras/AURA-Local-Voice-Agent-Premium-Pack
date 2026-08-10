import AuraAgent
import Foundation
import Testing

private func makeTempRepo() throws -> URL {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir
}

@Test
func scannerReturnsEmptyResultForRepositoryWithNoCustomizationFiles() throws {
  let repo = try makeTempRepo()
  defer { try? FileManager.default.removeItem(at: repo) }

  let result = RepositoryInstructionsScanner.scan(repositoryRoot: repo.path)
  #expect(result.filesScanned.isEmpty)
  #expect(!result.secretsDetected)
  #expect(result.blockedFiles.isEmpty)
}

@Test
func scannerFindsCleanCopilotInstructionsFile() throws {
  let repo = try makeTempRepo()
  defer { try? FileManager.default.removeItem(at: repo) }
  let githubDir = repo.appendingPathComponent(".github")
  try FileManager.default.createDirectory(at: githubDir, withIntermediateDirectories: true)
  try "Use tabs, not spaces. Prefer functional style."
    .write(
      to: githubDir.appendingPathComponent("copilot-instructions.md"), atomically: true,
      encoding: .utf8)

  let result = RepositoryInstructionsScanner.scan(repositoryRoot: repo.path)
  #expect(result.filesScanned.count == 1)
  #expect(!result.secretsDetected)
  #expect(result.blockedFiles.isEmpty)
}

@Test
func scannerDetectsSecretInCopilotInstructionsFile() throws {
  let repo = try makeTempRepo()
  defer { try? FileManager.default.removeItem(at: repo) }
  let githubDir = repo.appendingPathComponent(".github")
  try FileManager.default.createDirectory(at: githubDir, withIntermediateDirectories: true)
  let fakeKey = "sk-" + String(repeating: "a", count: 40)
  try "Use our API key \(fakeKey) when testing."
    .write(
      to: githubDir.appendingPathComponent("copilot-instructions.md"), atomically: true,
      encoding: .utf8)

  let result = RepositoryInstructionsScanner.scan(repositoryRoot: repo.path)
  #expect(result.secretsDetected)
  #expect(result.blockedFiles.count == 1)
  #expect(result.blockedFiles.first?.hasSuffix("copilot-instructions.md") == true)
}

@Test
func scannerDetectsPrivateKeyHeader() throws {
  let repo = try makeTempRepo()
  defer { try? FileManager.default.removeItem(at: repo) }
  // REPO_HYGIENE_SECRET_FIXTURE: private_key_block
  try "-----BEGIN RSA PRIVATE KEY-----\nMIIC...\n-----END RSA PRIVATE KEY-----"
    .write(to: repo.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

  let result = RepositoryInstructionsScanner.scan(repositoryRoot: repo.path)
  #expect(result.secretsDetected)
  #expect(result.blockedFiles.first?.hasSuffix("AGENTS.md") == true)
}

@Test
func scannerFindsFilesInInstructionsAgentsAndPromptsDirectories() throws {
  let repo = try makeTempRepo()
  defer { try? FileManager.default.removeItem(at: repo) }

  let instructionsDir = repo.appendingPathComponent(".github/instructions")
  let agentsDir = repo.appendingPathComponent(".github/agents")
  let promptsDir = repo.appendingPathComponent(".github/prompts")
  for dir in [instructionsDir, agentsDir, promptsDir] {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  }
  try "Swift files use 2-space indent."
    .write(
      to: instructionsDir.appendingPathComponent("swift.instructions.md"), atomically: true,
      encoding: .utf8)
  try "You are a focused reviewer agent."
    .write(
      to: agentsDir.appendingPathComponent("reviewer.agent.md"), atomically: true, encoding: .utf8)
  try "Summarize the diff."
    .write(
      to: promptsDir.appendingPathComponent("summarize.prompt.md"), atomically: true,
      encoding: .utf8)
  // A non-matching file in the same directory must not be picked up.
  try "irrelevant"
    .write(
      to: instructionsDir.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)

  let result = RepositoryInstructionsScanner.scan(repositoryRoot: repo.path)
  #expect(result.filesScanned.count == 3)
  #expect(!result.secretsDetected)
  #expect(result.filesScanned.contains { $0.hasSuffix("swift.instructions.md") })
  #expect(result.filesScanned.contains { $0.hasSuffix("reviewer.agent.md") })
  #expect(result.filesScanned.contains { $0.hasSuffix("summarize.prompt.md") })
  #expect(!result.filesScanned.contains { $0.hasSuffix("readme.txt") })
}

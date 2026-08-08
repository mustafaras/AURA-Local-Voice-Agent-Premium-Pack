import AuraAgent
import AuraCore
import AuraShell
import Foundation
import Testing

struct FixtureBackendCommandRunner: AgentBackendCommandRunning {
  func run(
    backend: AgentBackendID,
    executablePath: String,
    arguments: [String]
  ) async -> Result<ProcessResult, AuraError> {
    Result.success(
      ProcessResult(
        executionID: UUID(),
        exitCode: 0,
        stdout: arguments == ["--version"] ? "codex-cli 9.9.9" : "--sandbox --cd",
        stderr: "",
        durationSeconds: 0,
        wasCancelled: false,
        wasTimedOut: false,
        stdoutTruncated: false,
        stderrTruncated: false))
  }
}

@Suite("Agent backend health")
struct AgentBackendHealthTests {
  @Test("unprobed health does not equate executable presence with readiness")
  func unprobedIsDegraded() async {
    let probe = UnprobedAgentBackendHealthProbe(
      executablePaths: [.codex: "/bin/sh", .claude: "/does/not/exist", .copilot: "/bin/sh"])
    let health = await probe.probe(backend: .codex, workspacePath: "/tmp")
    #expect(health.state == .degraded)
    #expect(health.authentication == .unverified)
    #expect(health.version == nil)
    #expect(health.detail.contains("have not been probed"))
  }

  @Test("missing backend health is explicitly unavailable")
  func missingBackendIsUnavailable() async {
    let probe = UnprobedAgentBackendHealthProbe(executablePaths: [.codex: "/does/not/exist"])
    let health = await probe.probe(backend: .claude, workspacePath: nil)
    #expect(health.state == .unavailable)
    #expect(health.authentication == .unverified)
    #expect(health.detail.contains("unavailable"))
  }

  @Test("registry refreshes and returns sorted backend evidence")
  func registryRefreshesAll() async {
    let probe = StaticAgentBackendHealthProbe(
      healthByBackend: [
        .codex: Self.fixture(.codex),
        .claude: Self.fixture(.claude),
        .copilot: Self.fixture(.copilot),
      ])
    let registry = AgentBackendHealthRegistry(probe: probe)
    _ = await registry.refreshAll()
    let snapshot = await registry.snapshot()
    #expect(snapshot.map(\.backend) == [.claude, .codex, .copilot])
    #expect((await registry.health(for: .codex))?.state == .ready)
  }

  @Test("CLI probe records version/interface but keeps auth unverified")
  func cliProbeIsTruthful() async {
    let probe = CLIAgentBackendHealthProbe(
      executablePaths: [.codex: "/bin/sh"],
      runner: FixtureBackendCommandRunner())
    let health = await probe.probe(backend: .codex, workspacePath: "/tmp")
    #expect(health.state == .degraded)
    #expect(health.version == "codex-cli 9.9.9")
    #expect(health.authentication == .unverified)
    #expect(health.interfaceDescription.contains("--version and --help passed"))
  }

  private static func fixture(_ backend: AgentBackendID) -> AgentBackendHealth {
    AgentBackendHealth(
      backend: backend,
      state: .ready,
      executablePath: "/bin/sh",
      version: "fixture",
      interfaceDescription: "fixture",
      authentication: .verified,
      modelAvailability: "fixture model",
      sandboxPolicy: "fixture sandbox",
      cancellation: "fixture cancellation",
      networkPolicy: "offline",
      workingDirectoryPolicy: "/tmp",
      budgetPolicy: "fixture budget",
      detail: "fixture ready")
  }
}

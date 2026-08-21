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

// MARK: - Live CLI probe (Procedure 1)

/// Runs the real `CLIAgentBackendHealthProbe` against the installed CLIs.
/// SP-013 requires probing exact CLI version/interface and exposing
/// unverified auth/model as not-ready. This test drives the production
/// `AuraShellAgentBackendCommandRunner` (the same one the kernel uses) and
/// asserts the health state is truthful: presence + version/help is only
/// `.degraded`, never `.ready`, because authentication and model availability
/// remain unverified.
@Suite("Agent backend health live probe", .serialized)
struct AgentBackendHealthLiveProbeTests {
  private func makeLiveRunner(_ backend: AgentBackendID) -> AuraShellAgentBackendCommandRunner {
    let executablePath: String
    switch backend {
    case .codex: executablePath = "/opt/homebrew/bin/codex"
    case .claude: executablePath = "/opt/homebrew/bin/claude"
    case .copilot: executablePath = "/opt/homebrew/bin/copilot"
    }
    // The shell must allowlist the exact backend executable (mirroring each
    // backend's `derivedShellConfiguration()`), otherwise AuraShell refuses
    // to spawn it and the probe would report .unavailable for a false reason.
    let shell = AuraShell(
      configuration: ShellConfiguration(
        allowedExecutablePaths: [executablePath],
        allowedWorkingDirectories: ["$HOME", "$TMPDIR"]))
    return AuraShellAgentBackendCommandRunner(shells: [backend: shell])
  }

  @Test("codex live probe reports version and keeps auth/model unverified")
  func codexLiveProbe() async {
    guard FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/codex") else {
      return  // CLI not installed on this host; not a product failure.
    }
    let probe = CLIAgentBackendHealthProbe(
      executablePaths: [.codex: "/opt/homebrew/bin/codex"],
      runner: makeLiveRunner(.codex))
    let health = await probe.probe(backend: .codex, workspacePath: "/tmp")
    #expect(health.state == .degraded, "version+help pass is only .degraded, got \(health.state)")
    #expect(health.version?.isEmpty == false, "live Codex version must be captured")
    #expect(health.authentication == .unverified, "auth must stay unverified without onboarding evidence")
    #expect(health.modelAvailability == "unverified")
  }

  @Test("claude live probe reports version and keeps auth/model unverified")
  func claudeLiveProbe() async {
    guard FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/claude") else {
      return
    }
    let probe = CLIAgentBackendHealthProbe(
      executablePaths: [.claude: "/opt/homebrew/bin/claude"],
      runner: makeLiveRunner(.claude))
    let health = await probe.probe(backend: .claude, workspacePath: "/tmp")
    #expect(health.state == .degraded, "got \(health.state)")
    #expect(health.version?.isEmpty == false)
    #expect(health.authentication == .unverified)
    #expect(health.modelAvailability == "unverified")
  }

  @Test("copilot live probe reports version and keeps auth/model unverified")
  func copilotLiveProbe() async {
    guard FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/copilot") else {
      return
    }
    let probe = CLIAgentBackendHealthProbe(
      executablePaths: [.copilot: "/opt/homebrew/bin/copilot"],
      runner: makeLiveRunner(.copilot))
    let health = await probe.probe(backend: .copilot, workspacePath: "/tmp")
    #expect(health.state == .degraded, "got \(health.state)")
    #expect(health.version?.isEmpty == false)
    #expect(health.authentication == .unverified)
    #expect(health.modelAvailability == "unverified")
  }
}

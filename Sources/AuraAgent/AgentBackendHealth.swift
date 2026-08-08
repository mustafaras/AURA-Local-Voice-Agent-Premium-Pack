import AuraCore
import AuraShell
import Foundation

/// Stable identifiers for the coding-agent backends that AURA can route to.
public enum AgentBackendID: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case codex
  case claude
  case copilot
}

public enum AgentBackendHealthState: String, Codable, Sendable, Equatable {
  case ready
  case degraded
  case unavailable
  case unauthorized
  case versionMismatch
}

public enum AgentBackendAuthenticationState: String, Codable, Sendable, Equatable {
  case verified
  case unverified
  case unavailable
}

/// Bounded readiness evidence. A path existing is not treated as proof that a
/// backend is authenticated, model-ready, or safe to run.
public struct AgentBackendHealth: Codable, Sendable, Equatable {
  public let backend: AgentBackendID
  public let state: AgentBackendHealthState
  public let executablePath: String
  public let version: String?
  public let interfaceDescription: String
  public let authentication: AgentBackendAuthenticationState
  public let modelAvailability: String
  public let sandboxPolicy: String
  public let cancellation: String
  public let networkPolicy: String
  public let workingDirectoryPolicy: String
  public let budgetPolicy: String
  public let detail: String
  public let observedAt: Date

  public init(
    backend: AgentBackendID,
    state: AgentBackendHealthState,
    executablePath: String,
    version: String? = nil,
    interfaceDescription: String,
    authentication: AgentBackendAuthenticationState,
    modelAvailability: String,
    sandboxPolicy: String,
    cancellation: String,
    networkPolicy: String,
    workingDirectoryPolicy: String,
    budgetPolicy: String,
    detail: String,
    observedAt: Date = Date()
  ) {
    self.backend = backend
    self.state = state
    self.executablePath = executablePath
    self.version = version
    self.interfaceDescription = interfaceDescription
    self.authentication = authentication
    self.modelAvailability = modelAvailability
    self.sandboxPolicy = sandboxPolicy
    self.cancellation = cancellation
    self.networkPolicy = networkPolicy
    self.workingDirectoryPolicy = workingDirectoryPolicy
    self.budgetPolicy = budgetPolicy
    self.detail = detail
    self.observedAt = observedAt
  }
}

public protocol AgentBackendHealthProbing: Sendable {
  func probe(backend: AgentBackendID, workspacePath: String?) async -> AgentBackendHealth
}

public protocol AgentBackendCommandRunning: Sendable {
  func run(
    backend: AgentBackendID,
    executablePath: String,
    arguments: [String]
  ) async -> Result<ProcessResult, AuraError>
}

/// Production command runner for read-only `--version`/`--help` health probes.
/// It uses each backend's derived shell allowlist and never runs a model turn.
public struct AuraShellAgentBackendCommandRunner: AgentBackendCommandRunning {
  public let shells: [AgentBackendID: AuraShell]

  public init(shells: [AgentBackendID: AuraShell]) {
    self.shells = shells
  }

  public func run(
    backend: AgentBackendID,
    executablePath: String,
    arguments: [String]
  ) async -> Result<ProcessResult, AuraError> {
    guard let shell = shells[backend] else {
      return .failure(.invalidConfiguration("no derived shell is configured for " + backend.rawValue))
    }
    let command = Command(
      executable: executablePath,
      arguments: arguments,
      timeoutSeconds: 15,
      riskTier: .observation)
    return await shell.execute(
      command: command,
      actor: .system,
      sessionID: UUID(),
      correlationID: UUID(),
      causationID: UUID())
  }
}

/// Local CLI readiness probe. It verifies executable presence, exact version
/// output, and the allowlisted interface flags, while keeping authentication
/// and model availability explicitly unverified.
public struct CLIAgentBackendHealthProbe: AgentBackendHealthProbing {
  public let executablePaths: [AgentBackendID: String]
  public let expectedInterfaceFlags: [AgentBackendID: [String]]
  private let runner: any AgentBackendCommandRunning

  public init(
    executablePaths: [AgentBackendID: String],
    runner: any AgentBackendCommandRunning,
    expectedInterfaceFlags: [AgentBackendID: [String]] = [
      .codex: ["exec", "--sandbox", "--cd"],
      .claude: ["-p", "--permission-mode", "--worktree"],
      .copilot: ["-p", "--allow-tool"],
    ]
  ) {
    self.executablePaths = executablePaths
    self.runner = runner
    self.expectedInterfaceFlags = expectedInterfaceFlags
  }

  public func probe(backend: AgentBackendID, workspacePath: String?) async -> AgentBackendHealth {
    let path = executablePaths[backend] ?? ""
    guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
      return unavailable(backend: backend, path: path, detail: "configured executable is not executable")
    }
    let versionResult = await runner.run(
      backend: backend,
      executablePath: path,
      arguments: ["--version"])
    let version: String
    switch versionResult {
    case .success(let result) where result.exitCode == 0:
      version = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    case .success(let result):
      return unavailable(
        backend: backend,
        path: path,
        detail: "--version exited " + String(result.exitCode))
    case .failure(let error):
      return unavailable(backend: backend, path: path, detail: error.localizedDescription)
    }
    guard !version.isEmpty else {
      return unavailable(backend: backend, path: path, detail: "--version returned no version evidence")
    }

    let helpResult = await runner.run(
      backend: backend,
      executablePath: path,
      arguments: ["--help"])
    switch helpResult {
    case .success(let result) where result.exitCode == 0:
      let flags = expectedInterfaceFlags[backend] ?? []
      return AgentBackendHealth(
        backend: backend,
        state: .degraded,
        executablePath: path,
        version: String(version.prefix(160)),
        interfaceDescription: "--version and --help passed; expected typed flags: " + flags.joined(separator: ", "),
        authentication: .unverified,
        modelAvailability: "unverified",
        sandboxPolicy: "adapter configuration and policy grant required",
        cancellation: "process cancellation path configured; live turn not run",
        networkPolicy: "backend-specific policy; not exercised by health probe",
        workingDirectoryPolicy: workspacePath.map { "allowlisted workspace: " + $0 } ?? "workspace not resolved",
        budgetPolicy: "adapter-configured timeout/output/cost/file bounds",
        detail: "local CLI version/interface verified; authentication and model availability still require onboarding evidence")
    case .success(let result):
      return unavailable(
        backend: backend,
        path: path,
        detail: "--help exited " + String(result.exitCode))
    case .failure(let error):
      return unavailable(backend: backend, path: path, detail: error.localizedDescription)
    }
  }

  private func unavailable(
    backend: AgentBackendID,
    path: String,
    detail: String
  ) -> AgentBackendHealth {
    AgentBackendHealth(
      backend: backend,
      state: .unavailable,
      executablePath: path,
      interfaceDescription: "CLI readiness not verified",
      authentication: .unavailable,
      modelAvailability: "unavailable",
      sandboxPolicy: "unavailable",
      cancellation: "unavailable",
      networkPolicy: "not exercised",
      workingDirectoryPolicy: "unresolved",
      budgetPolicy: "unavailable",
      detail: detail)
  }
}

/// Safe default probe used before an explicit local version/help/auth check.
/// It records the configured executable and keeps the backend unavailable until
/// the missing live evidence is supplied.
public struct UnprobedAgentBackendHealthProbe: AgentBackendHealthProbing {
  public let executablePaths: [AgentBackendID: String]

  public init(executablePaths: [AgentBackendID: String]) {
    self.executablePaths = executablePaths
  }

  public func probe(backend: AgentBackendID, workspacePath: String?) async -> AgentBackendHealth {
    let path = executablePaths[backend] ?? ""
    let exists = !path.isEmpty && FileManager.default.isExecutableFile(atPath: path)
    let state: AgentBackendHealthState = exists ? .degraded : .unavailable
    let pathDescription = path.isEmpty ? "an empty path" : path
    let detail = exists
      ? "executable is present, but version, authentication, model availability, and live cancellation have not been probed"
      : "configured executable is unavailable at " + pathDescription
    return AgentBackendHealth(
      backend: backend,
      state: state,
      executablePath: path,
      interfaceDescription: "local CLI adapter; exact flags are owned by the backend adapter",
      authentication: .unverified,
      modelAvailability: "unverified",
      sandboxPolicy: "adapter configuration required; dangerous bypass flags are unreachable",
      cancellation: "adapter cancellation path configured; live process probe pending",
      networkPolicy: "backend-specific policy; not inferred from executable presence",
      workingDirectoryPolicy: workspacePath.map { "allowlisted workspace: " + $0 } ?? "workspace not resolved",
      budgetPolicy: "adapter-configured output/time/cost/file limits; live probe pending",
      detail: detail)
  }
}

public struct StaticAgentBackendHealthProbe: AgentBackendHealthProbing {
  public let healthByBackend: [AgentBackendID: AgentBackendHealth]

  public init(healthByBackend: [AgentBackendID: AgentBackendHealth]) {
    self.healthByBackend = healthByBackend
  }

  public func probe(backend: AgentBackendID, workspacePath: String?) async -> AgentBackendHealth {
    healthByBackend[backend]
      ?? AgentBackendHealth(
        backend: backend,
        state: .unavailable,
        executablePath: "",
        interfaceDescription: "not configured",
        authentication: .unavailable,
        modelAvailability: "unavailable",
        sandboxPolicy: "unavailable",
        cancellation: "unavailable",
        networkPolicy: "unavailable",
        workingDirectoryPolicy: workspacePath ?? "unresolved",
        budgetPolicy: "unavailable",
        detail: "no backend health fixture is configured")
  }
}

/// Durable-session-local registry for backend readiness evidence.
public actor AgentBackendHealthRegistry {
  private let probe: any AgentBackendHealthProbing
  private var entries: [AgentBackendID: AgentBackendHealth] = [:]

  public init(probe: any AgentBackendHealthProbing) {
    self.probe = probe
  }

  @discardableResult
  public func refresh(
    backend: AgentBackendID,
    workspacePath: String? = nil
  ) async -> AgentBackendHealth {
    let health = await probe.probe(backend: backend, workspacePath: workspacePath)
    entries[backend] = health
    return health
  }

  public func refreshAll(workspacePath: String? = nil) async -> [AgentBackendHealth] {
    var results: [AgentBackendHealth] = []
    for backend in AgentBackendID.allCases {
      results.append(await refresh(backend: backend, workspacePath: workspacePath))
    }
    return results
  }

  public func health(for backend: AgentBackendID) -> AgentBackendHealth? {
    entries[backend]
  }

  public func snapshot() -> [AgentBackendHealth] {
    entries.values.sorted { $0.backend.rawValue < $1.backend.rawValue }
  }
}

import AuraCore
import Foundation

/// Health reported by the companion extension bridge.
public struct VSCodeBridgeHealth: Codable, Sendable, Equatable {
  public enum State: String, Codable, Sendable, Equatable {
    case ready
    case degraded
    case disconnected
    case unauthorized
    case versionMismatch
  }

  public let state: State
  public let protocolVersion: Int
  public let extensionID: String?
  public let detail: String
  public let observedAt: Date

  public init(
    state: State,
    protocolVersion: Int = VSCodeBridgeSignedPayload.currentProtocolVersion,
    extensionID: String? = nil,
    detail: String,
    observedAt: Date = Date()
  ) {
    self.state = state
    self.protocolVersion = protocolVersion
    self.extensionID = extensionID
    self.detail = detail
    self.observedAt = observedAt
  }
}

/// The complete allowlisted command vocabulary exposed over the extension IPC.
/// It intentionally contains no arbitrary command text or extension API name.
public struct VSCodeBridgeCommand: Codable, Sendable, Equatable, Hashable {
  public enum Kind: String, Codable, Sendable, Equatable, Hashable {
    case health
    case workspace
    case editor
    case diagnostics
    case tasks
    case tests
    case terminalSessions
    case runTask
    case cancelTask
    case runTests
    case cancelTests
  }

  public let kind: Kind
  public let name: String?
  public let target: String?
  public let workspacePath: String?
  public let taskID: String?
  public let testID: String?

  public init(
    kind: Kind,
    name: String? = nil,
    target: String? = nil,
    workspacePath: String? = nil,
    taskID: String? = nil,
    testID: String? = nil
  ) {
    self.kind = kind
    self.name = name
    self.target = target
    self.workspacePath = workspacePath
    self.taskID = taskID
    self.testID = testID
  }

  public static var health: Self { Self(kind: .health) }
  public static var workspace: Self { Self(kind: .workspace) }
  public static var editor: Self { Self(kind: .editor) }
  public static var diagnostics: Self { Self(kind: .diagnostics) }
  public static var tasks: Self { Self(kind: .tasks) }
  public static var tests: Self { Self(kind: .tests) }
  public static var terminalSessions: Self { Self(kind: .terminalSessions) }

  public static func runTask(name: String, workspacePath: String? = nil) -> Self {
    Self(kind: .runTask, name: name, workspacePath: workspacePath)
  }

  public static func cancelTask(taskID: String) -> Self {
    Self(kind: .cancelTask, taskID: taskID)
  }

  public static func runTests(target: String? = nil, workspacePath: String? = nil) -> Self {
    Self(kind: .runTests, target: target, workspacePath: workspacePath)
  }

  public static func cancelTests(testID: String) -> Self {
    Self(kind: .cancelTests, testID: testID)
  }
}

public struct VSCodeTaskInfo: Codable, Sendable, Equatable, Hashable {
  public let name: String
  public let state: String
  public let detail: String?

  public init(name: String, state: String, detail: String? = nil) {
    self.name = name
    self.state = state
    self.detail = detail
  }
}

public struct VSCodeTestInfo: Codable, Sendable, Equatable, Hashable {
  public let testID: String
  public let state: String
  public let detail: String?

  public init(testID: String, state: String, detail: String? = nil) {
    self.testID = testID
    self.state = state
    self.detail = detail
  }
}

public struct VSCodeBridgeCommandResult: Codable, Sendable, Equatable {
  public enum Outcome: String, Codable, Sendable, Equatable {
    case accepted
    case completed
    case cancelled
    case unavailable
  }

  public let outcome: Outcome
  public let message: String
  public let health: VSCodeBridgeHealth?
  public let workspace: VSCodeWorkspaceInfo?
  public let editor: VSCodeEditorState?
  public let diagnostics: [VSCodeDiagnostic]
  public let tasks: [VSCodeTaskInfo]
  public let tests: [VSCodeTestInfo]
  public let terminals: [VSCodeTerminalState]

  public init(
    outcome: Outcome,
    message: String,
    health: VSCodeBridgeHealth? = nil,
    workspace: VSCodeWorkspaceInfo? = nil,
    editor: VSCodeEditorState? = nil,
    diagnostics: [VSCodeDiagnostic] = [],
    tasks: [VSCodeTaskInfo] = [],
    tests: [VSCodeTestInfo] = [],
    terminals: [VSCodeTerminalState] = []
  ) {
    self.outcome = outcome
    self.message = message
    self.health = health
    self.workspace = workspace
    self.editor = editor
    self.diagnostics = diagnostics
    self.tasks = tasks
    self.tests = tests
    self.terminals = terminals
  }
}

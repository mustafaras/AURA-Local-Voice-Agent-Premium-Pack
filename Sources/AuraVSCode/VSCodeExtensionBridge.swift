import AuraCore
import Foundation

/// Abstraction over the companion VS Code extension that writes editor,
/// terminal, and diagnostics state to a JSON file.
///
/// A live bridge reads the file written by the extension. Tests and fallback
/// paths use the `Static` implementation.
public protocol VSCodeExtensionBridge: Sendable {
  /// Read current editor state, if available.
  func editorState(maxStalenessSeconds: Double) async -> VSCodeEditorState?

  /// Read current active terminal state, if available.
  func terminalState(maxStalenessSeconds: Double) async -> VSCodeTerminalState?

  /// Read current workspace diagnostics, if available.
  func diagnostics(maxStalenessSeconds: Double) async -> [VSCodeDiagnostic]

  /// Whether the bridge can be reached on this system.
  var isAvailable: Bool { get }
}

/// File-based bridge that reads JSON state emitted by the companion extension.
public actor VSCodeFileBridge: VSCodeExtensionBridge {
  private let statePath: String?

  public init(statePath: String?) {
    self.statePath = statePath
  }

  nonisolated public var isAvailable: Bool {
    guard let path = statePath else { return false }
    return FileManager.default.fileExists(atPath: path)
  }

  public func editorState(maxStalenessSeconds: Double) async -> VSCodeEditorState? {
    try? snapshot(maxStalenessSeconds: maxStalenessSeconds).editor
  }

  public func terminalState(maxStalenessSeconds: Double) async -> VSCodeTerminalState? {
    try? snapshot(maxStalenessSeconds: maxStalenessSeconds).terminal
  }

  public func diagnostics(maxStalenessSeconds: Double) async -> [VSCodeDiagnostic] {
    (try? snapshot(maxStalenessSeconds: maxStalenessSeconds).diagnostics) ?? []
  }

  private func snapshot(maxStalenessSeconds: Double) throws -> VSCodeBridgeSnapshot {
    guard let path = statePath else {
      throw AuraError.invalidConfiguration("extension bridge state path is nil")
    }
    let url = URL(fileURLWithPath: path)
    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    let modificationDate = attributes[.modificationDate] as? Date ?? Date.distantPast
    let age = Date().timeIntervalSince(modificationDate)
    guard age <= maxStalenessSeconds else {
      throw AuraError.invalidConfiguration("extension bridge state is stale (age \(age)s)")
    }
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(VSCodeBridgeSnapshot.self, from: data)
  }
}

/// Static bridge for tests or headless fallback.
public struct VSCodeStaticBridge: VSCodeExtensionBridge {
  public let editor: VSCodeEditorState?
  public let terminal: VSCodeTerminalState?
  public let diagnostics: [VSCodeDiagnostic]
  public var isAvailable: Bool { true }

  public init(
    editor: VSCodeEditorState? = nil,
    terminal: VSCodeTerminalState? = nil,
    diagnostics: [VSCodeDiagnostic] = []
  ) {
    self.editor = editor
    self.terminal = terminal
    self.diagnostics = diagnostics
  }

  public func editorState(maxStalenessSeconds: Double) async -> VSCodeEditorState? { editor }
  public func terminalState(maxStalenessSeconds: Double) async -> VSCodeTerminalState? { terminal }
  public func diagnostics(maxStalenessSeconds: Double) async -> [VSCodeDiagnostic] { diagnostics }
}

// MARK: - Bridge DTO

/// Internal shape of the JSON file written by the companion extension.
public struct VSCodeBridgeSnapshot: Codable, Sendable, Equatable {
  public let editor: VSCodeEditorState?
  public let terminal: VSCodeTerminalState?
  public let diagnostics: [VSCodeDiagnostic]
  public let timestamp: Date?

  public init(
    editor: VSCodeEditorState? = nil,
    terminal: VSCodeTerminalState? = nil,
    diagnostics: [VSCodeDiagnostic] = [],
    timestamp: Date? = nil
  ) {
    self.editor = editor
    self.terminal = terminal
    self.diagnostics = diagnostics
    self.timestamp = timestamp
  }
}

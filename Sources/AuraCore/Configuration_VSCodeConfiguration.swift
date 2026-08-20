import Foundation

/// Configuration for the Visual Studio Code adapter.
public struct VSCodeConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `code` CLI executable.
  public var cliPath: String

  /// Timeout in seconds for any `code` CLI invocation.
  public var cliTimeoutSeconds: Double

  /// File path where a companion extension writes editor/terminal state JSON.
  public var bridgeStatePath: String?

  /// Optional explicit command input file path for the extension bridge.
  /// When omitted, it is derived from `bridgeStatePath`'s parent directory.
  public var bridgeCommandPath: String?

  /// Optional explicit response output file path for the extension bridge.
  /// When omitted, it is derived from `bridgeStatePath`'s parent directory.
  public var bridgeResponsePath: String?

  /// Maximum staleness allowed for extension bridge state before it is ignored.
  public var bridgeMaxStalenessSeconds: Double

  /// Approved VS Code extension identifier the bridge authenticates.
  /// Empty means no extension is provisioned; capabilities stay disabled.
  public var extensionID: String

  /// Keychain service name for the symmetric bridge secret.
  public var secretServiceName: String

  /// Whether terminal command injection requires cwd/shell verification.
  public var requireTerminalVerification: Bool

  /// Whether dirty-editor confirmation must be obtained before closing editors.
  public var requireDirtyEditorConfirmation: Bool

  /// Shell executables that may be used as integrated terminal targets.
  public var allowedTerminalShells: Set<String>

  public init(
    cliPath: String = "/usr/local/bin/code",
    cliTimeoutSeconds: Double = 10.0,
    bridgeStatePath: String? = nil,
    bridgeCommandPath: String? = nil,
    bridgeResponsePath: String? = nil,
    bridgeMaxStalenessSeconds: Double = 30.0,
    extensionID: String = "",
    secretServiceName: String = "ai.aura.vscode-bridge",
    requireTerminalVerification: Bool = true,
    requireDirtyEditorConfirmation: Bool = true,
    allowedTerminalShells: Set<String> = [
      "/bin/zsh",
      "/bin/bash",
      "/bin/sh",
    ]
  ) {
    self.cliPath = cliPath
    self.cliTimeoutSeconds = cliTimeoutSeconds
    self.bridgeStatePath = bridgeStatePath
    self.bridgeCommandPath = bridgeCommandPath
    self.bridgeResponsePath = bridgeResponsePath
    self.bridgeMaxStalenessSeconds = bridgeMaxStalenessSeconds
    self.extensionID = extensionID
    self.secretServiceName = secretServiceName
    self.requireTerminalVerification = requireTerminalVerification
    self.requireDirtyEditorConfirmation = requireDirtyEditorConfirmation
    self.allowedTerminalShells = allowedTerminalShells
  }

  public func validate() throws(AuraError) {
    guard !cliPath.isEmpty else {
      throw AuraError.invalidConfiguration("vscode cliPath must not be empty")
    }
    guard cliTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("vscode cliTimeoutSeconds must be positive")
    }
    guard bridgeMaxStalenessSeconds >= 0 else {
      throw AuraError.invalidConfiguration("vscode bridgeMaxStalenessSeconds must be non-negative")
    }
    guard !allowedTerminalShells.isEmpty else {
      throw AuraError.invalidConfiguration("vscode allowedTerminalShells must not be empty")
    }
    if let commandPath = bridgeCommandPath, commandPath.isEmpty {
      throw AuraError.invalidConfiguration("vscode bridgeCommandPath must not be empty when set")
    }
    if let responsePath = bridgeResponsePath, responsePath.isEmpty {
      throw AuraError.invalidConfiguration("vscode bridgeResponsePath must not be empty when set")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> VSCodeConfiguration {
    VSCodeConfiguration(
      cliPath: self.cliPath.isEmpty ? VSCodeConfiguration().cliPath : self.cliPath,
      cliTimeoutSeconds: self.cliTimeoutSeconds <= 0
        ? VSCodeConfiguration().cliTimeoutSeconds
        : self.cliTimeoutSeconds,
      bridgeStatePath: self.bridgeStatePath ?? VSCodeConfiguration().bridgeStatePath,
      bridgeCommandPath: self.bridgeCommandPath ?? VSCodeConfiguration().bridgeCommandPath,
      bridgeResponsePath: self.bridgeResponsePath ?? VSCodeConfiguration().bridgeResponsePath,
      bridgeMaxStalenessSeconds: self.bridgeMaxStalenessSeconds < 0
        ? VSCodeConfiguration().bridgeMaxStalenessSeconds
        : self.bridgeMaxStalenessSeconds,
      extensionID: self.extensionID,
      secretServiceName: self.secretServiceName.isEmpty
        ? VSCodeConfiguration().secretServiceName
        : self.secretServiceName,
      requireTerminalVerification: self.requireTerminalVerification,
      requireDirtyEditorConfirmation: self.requireDirtyEditorConfirmation,
      allowedTerminalShells: self.allowedTerminalShells.isEmpty
        ? VSCodeConfiguration().allowedTerminalShells
        : self.allowedTerminalShells
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    cliPath = try container.decodeIfPresent(String.self, forKey: .cliPath) ?? "/usr/local/bin/code"
    cliTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .cliTimeoutSeconds) ?? 10.0
    bridgeStatePath = try container.decodeIfPresent(String.self, forKey: .bridgeStatePath)
    bridgeCommandPath = try container.decodeIfPresent(String.self, forKey: .bridgeCommandPath)
    bridgeResponsePath = try container.decodeIfPresent(String.self, forKey: .bridgeResponsePath)
    bridgeMaxStalenessSeconds =
      try container.decodeIfPresent(Double.self, forKey: .bridgeMaxStalenessSeconds) ?? 30.0
    extensionID = try container.decodeIfPresent(String.self, forKey: .extensionID) ?? ""
    secretServiceName =
      try container.decodeIfPresent(String.self, forKey: .secretServiceName)
      ?? "ai.aura.vscode-bridge"
    requireTerminalVerification =
      try container.decodeIfPresent(Bool.self, forKey: .requireTerminalVerification) ?? true
    requireDirtyEditorConfirmation =
      try container.decodeIfPresent(Bool.self, forKey: .requireDirtyEditorConfirmation) ?? true
    allowedTerminalShells =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedTerminalShells)
      ?? [
        "/bin/zsh",
        "/bin/bash",
        "/bin/sh",
      ]
  }

  enum CodingKeys: String, CodingKey {
    case cliPath
    case cliTimeoutSeconds
    case bridgeStatePath
    case bridgeCommandPath
    case bridgeResponsePath
    case bridgeMaxStalenessSeconds
    case extensionID
    case secretServiceName
    case requireTerminalVerification
    case requireDirtyEditorConfirmation
    case allowedTerminalShells
  }
}

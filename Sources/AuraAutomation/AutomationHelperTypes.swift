import Foundation

// MARK: - Automation helper typed operations

/// A typed app-lifecycle operation the automation helper may execute. This is
/// deliberately a closed enum, not a free-form string, so a model or external
/// input can never name an arbitrary operation. Accessibility/generated-input
/// operations are intentionally absent: they require a per-executable TCC
/// grant that is outside the current helper's authority.
public enum AutomationHelperOperation: Codable, Sendable, Equatable {
  case launch(bundleIdentifier: String)
  case activate(bundleIdentifier: String)
  case hide(bundleIdentifier: String)
  case quit(bundleIdentifier: String)

  private enum Kind: String, Codable {
    case launch
    case activate
    case hide
    case quit
  }

  private struct Box: Codable {
    let kind: Kind
    let bundleIdentifier: String
  }

  public init(from decoder: Decoder) throws {
    let box = try Box(from: decoder)
    switch box.kind {
    case .launch: self = .launch(bundleIdentifier: box.bundleIdentifier)
    case .activate: self = .activate(bundleIdentifier: box.bundleIdentifier)
    case .hide: self = .hide(bundleIdentifier: box.bundleIdentifier)
    case .quit: self = .quit(bundleIdentifier: box.bundleIdentifier)
    }
  }

  public func encode(to encoder: Encoder) throws {
    let box: Box
    switch self {
    case .launch(let id): box = Box(kind: .launch, bundleIdentifier: id)
    case .activate(let id): box = Box(kind: .activate, bundleIdentifier: id)
    case .hide(let id): box = Box(kind: .hide, bundleIdentifier: id)
    case .quit(let id): box = Box(kind: .quit, bundleIdentifier: id)
    }
    try box.encode(to: encoder)
  }
}

/// A typed result of an automation helper operation.
public enum AutomationHelperResult: Codable, Sendable, Equatable {
  case success(NativeApplicationDescriptor)
  case failure(String)

  private enum Kind: String, Codable {
    case success
    case failure
  }

  private struct SuccessBox: Codable {
    let kind: Kind
    let descriptor: NativeApplicationDescriptor
  }

  private struct FailureBox: Codable {
    let kind: Kind
    let message: String
  }

  public init(from decoder: Decoder) throws {
    if let success = try? SuccessBox(from: decoder) {
      self = .success(success.descriptor)
      return
    }
    let failure = try FailureBox(from: decoder)
    self = .failure(failure.message)
  }

  public func encode(to encoder: Encoder) throws {
    switch self {
    case .success(let descriptor):
      try SuccessBox(kind: .success, descriptor: descriptor).encode(to: encoder)
    case .failure(let message):
      try FailureBox(kind: .failure, message: message).encode(to: encoder)
    }
  }
}

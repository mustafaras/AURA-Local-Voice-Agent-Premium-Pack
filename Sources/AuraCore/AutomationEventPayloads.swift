import Foundation

// MARK: - Automation lifecycle and observation event payloads

/// Emitted when an application is discovered or its runtime state is refreshed.
public struct ApplicationDiscoveredEvent: EventPayload {
  public static let eventType = "automation.application.discovered"

  /// Bundle identifier such as "com.apple.finder".
  public let bundleIdentifier: String

  /// Localized display name, if known.
  public let name: String

  /// Process identifier, or 0 if not running.
  public let processID: Int32

  /// Whether the application is currently the active frontmost app.
  public let isActive: Bool

  /// Whether the application is hidden.
  public let isHidden: Bool

  /// Monotonic timestamp of the observation.
  public let observedAt: TimeInterval

  public init(
    bundleIdentifier: String,
    name: String,
    processID: Int32,
    isActive: Bool,
    isHidden: Bool,
    observedAt: TimeInterval = Date().timeIntervalSince1970
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.name = name
    self.processID = processID
    self.isActive = isActive
    self.isHidden = isHidden
    self.observedAt = observedAt
  }
}

/// Emitted when an application lifecycle action succeeds or fails.
public struct ApplicationActionEvent: EventPayload {
  public static let eventType = "automation.application.action"

  public enum Action: String, Codable, Sendable, Equatable {
    case launch
    case activate
    case hide
    case quit
  }

  public enum Outcome: String, Codable, Sendable, Equatable {
    case succeeded
    case failed
    case degraded
  }

  public let bundleIdentifier: String
  public let action: Action
  public let outcome: Outcome
  public let errorMessage: String?
  public let elapsedSeconds: Double

  public init(
    bundleIdentifier: String,
    action: Action,
    outcome: Outcome,
    errorMessage: String? = nil,
    elapsedSeconds: Double
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.action = action
    self.outcome = outcome
    self.errorMessage = errorMessage
    self.elapsedSeconds = elapsedSeconds
  }
}

/// Describes the current state of Accessibility permission trust.
public enum AccessibilityTrustState: String, Codable, Sendable, Equatable {
  case granted
  case denied
  case unknown
}

/// Emitted when Accessibility permission health is checked.
public struct AccessibilityPermissionEvent: EventPayload {
  public static let eventType = "automation.accessibility.permission"

  public let source: String
  public let state: AccessibilityTrustState
  public let timestamp: TimeInterval

  public init(source: String, state: AccessibilityTrustState, timestamp: Date) {
    self.source = source
    self.state = state
    self.timestamp = timestamp.timeIntervalSince1970
  }
}

/// A single accessible element observation without raw screen content.
public struct AccessibleElementObservation: Codable, Sendable, Equatable {
  public let bundleIdentifier: String
  public let processID: Int32
  public let elementRole: String?
  public let elementTitle: String?
  public let elementValue: String?
  public let timestamp: TimeInterval

  public init(
    bundleIdentifier: String,
    processID: Int32,
    elementRole: String? = nil,
    elementTitle: String? = nil,
    elementValue: String? = nil,
    timestamp: Date
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.processID = processID
    self.elementRole = elementRole
    self.elementTitle = elementTitle
    self.elementValue = elementValue
    self.timestamp = timestamp.timeIntervalSince1970
  }
}

/// Emitted when the focused accessible element is observed.
public struct AccessibilityObservationEvent: EventPayload {
  public static let eventType = "automation.accessibility.observation"

  public let bundleIdentifier: String?
  public let windowTitle: String?
  public let element: AccessibleElementObservation
  public let observedAt: TimeInterval
  public let freshnessDeadline: TimeInterval

  public init(
    bundleIdentifier: String?,
    windowTitle: String?,
    element: AccessibleElementObservation,
    observedAt: TimeInterval,
    freshnessDeadline: TimeInterval
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.windowTitle = windowTitle
    self.element = element
    self.observedAt = observedAt
    self.freshnessDeadline = freshnessDeadline
  }
}

/// Emitted when an automation operation fails.
public struct AutomationErrorEvent: EventPayload {
  public static let eventType = "automation.error"

  public let operation: String
  public let errorMessage: String
  public let recoverable: Bool

  public init(operation: String, errorMessage: String, recoverable: Bool) {
    self.operation = operation
    self.errorMessage = errorMessage
    self.recoverable = recoverable
  }
}

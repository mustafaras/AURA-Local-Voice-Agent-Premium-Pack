import Foundation

/// Non-user policy bounds. A preference may narrow these bounds but can never
/// widen them (for example, enabling cloud context while the machine policy is
/// local-only).
public struct PreferencePolicyBounds: Sendable, Equatable {
  public let cloudContextAllowed: Bool

  public init(cloudContextAllowed: Bool = false) {
    self.cloudContextAllowed = cloudContextAllowed
  }

  public func validate(_ profile: UserPreferenceProfile) throws(AuraError) {
    try profile.validate()
    guard profile.localOnly || cloudContextAllowed else {
      throw AuraError.permissionDenied(
        "user preference cannot enable remote context while machine policy is local-only")
    }
  }
}

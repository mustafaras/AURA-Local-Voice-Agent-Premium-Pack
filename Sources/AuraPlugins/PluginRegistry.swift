import AuraCore
import AuraPolicy
import AuraStore
import Foundation

public enum PluginLifecycleState: String, Codable, Sendable, Equatable, CaseIterable {
  case installed
  case enabled
  case disabled
  case quarantined
  case uninstalled
}

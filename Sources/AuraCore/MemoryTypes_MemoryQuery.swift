import Foundation

// MARK: - Query filter

/// Filter used by `MemoryEngine` query/projection/export methods.
public struct MemoryQuery: Sendable, Equatable {
  public let memoryClass: MemoryClass?
  public let subject: String?
  public let scope: MemoryScope?
  public let includeSuperseded: Bool

  public init(
    memoryClass: MemoryClass? = nil,
    subject: String? = nil,
    scope: MemoryScope? = nil,
    includeSuperseded: Bool = false
  ) {
    self.memoryClass = memoryClass
    self.subject = subject
    self.scope = scope
    self.includeSuperseded = includeSuperseded
  }

  public static let all = MemoryQuery(includeSuperseded: true)
}

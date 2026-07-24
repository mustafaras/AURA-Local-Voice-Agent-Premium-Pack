import Foundation

/// A simple actor-wrapped mutable box for shared state in test or internal contexts.
public actor AtomicBox<T: Sendable> {
  private var storage: T

  public init(_ value: T) {
    self.storage = value
  }

  public var value: T { storage }

  public func mutate(_ newValue: T) {
    storage = newValue
  }

  public func withValue(_ mutation: @Sendable (T) async -> T) async {
    storage = await mutation(storage)
  }
}

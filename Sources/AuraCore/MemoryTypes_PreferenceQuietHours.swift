import Foundation

public struct PreferenceQuietHours: Codable, Sendable, Equatable {
  public let startHour: Int
  public let endHour: Int

  public init(startHour: Int, endHour: Int) {
    self.startHour = startHour
    self.endHour = endHour
  }

  public func validate() throws(AuraError) {
    guard (0..<24).contains(startHour), (0..<24).contains(endHour) else {
      throw AuraError.memoryError("quiet hours must use 0...23 hour values")
    }
  }
}

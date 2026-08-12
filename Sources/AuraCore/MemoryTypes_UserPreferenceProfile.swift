import Foundation

/// User-controlled personalization data. It is intentionally a bounded,
/// typed profile rather than an arbitrary key/value memory bag.
public struct UserPreferenceProfile: Codable, Sendable, Equatable {
  public var preferredLanguage: String
  public var responseLength: PreferenceResponseLength
  public var browserAccount: String?
  public var mailAccount: String?
  public var calendarAccount: String?
  public var codingBackend: String?
  public var codingModel: String?
  public var workingDirectories: [String]
  public var projects: [String]
  public var voicePreference: String?
  public var activationPreference: String?
  public var localOnly: Bool
  public var quietHours: PreferenceQuietHours?
  public var enabledMemoryClasses: Set<MemoryClass>
  public var retentionOverrides: [MemoryClass: MemoryRetentionPolicy]

  public init(
    preferredLanguage: String = "tr-TR",
    responseLength: PreferenceResponseLength = .balanced,
    browserAccount: String? = nil,
    mailAccount: String? = nil,
    calendarAccount: String? = nil,
    codingBackend: String? = nil,
    codingModel: String? = nil,
    workingDirectories: [String] = [],
    projects: [String] = [],
    voicePreference: String? = nil,
    activationPreference: String? = nil,
    localOnly: Bool = true,
    quietHours: PreferenceQuietHours? = nil,
    enabledMemoryClasses: Set<MemoryClass> = Set(
      MemoryClass.allCases.filter { $0 != .auditSecurity }),
    retentionOverrides: [MemoryClass: MemoryRetentionPolicy] = [:]
  ) {
    self.preferredLanguage = preferredLanguage
    self.responseLength = responseLength
    self.browserAccount = browserAccount
    self.mailAccount = mailAccount
    self.calendarAccount = calendarAccount
    self.codingBackend = codingBackend
    self.codingModel = codingModel
    self.workingDirectories = workingDirectories
    self.projects = projects
    self.voicePreference = voicePreference
    self.activationPreference = activationPreference
    self.localOnly = localOnly
    self.quietHours = quietHours
    self.enabledMemoryClasses = enabledMemoryClasses
    self.retentionOverrides = retentionOverrides
  }

  public func validate() throws(AuraError) {
    guard !preferredLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.memoryError("preferred language must not be empty")
    }
    guard !enabledMemoryClasses.contains(.auditSecurity) else {
      throw AuraError.memoryError("audit/security memory cannot be user-enabled or disabled")
    }
    guard
      workingDirectories.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    else {
      throw AuraError.memoryError("working directory preferences must not be empty")
    }
    try quietHours?.validate()
  }
}

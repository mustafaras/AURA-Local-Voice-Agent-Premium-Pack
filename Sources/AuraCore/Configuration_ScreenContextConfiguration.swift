import Foundation

/// Configuration for `ScreenContextEngine` (Phase 17) — off-by-default
/// capture, sensitive-app/self exclusion, redaction thresholds, and
/// diagnostic raw-frame retention (governed by `PrivacyConfiguration.
/// screenshotRetentionDays`, not a duplicate field here).
public struct ScreenContextConfiguration: Codable, Sendable, Equatable {
  /// Master switch. Screen capture is off until this is explicitly set —
  /// "off until granted and actively needed."
  public var enabled: Bool

  /// Application bundle identifiers that must never be captured: password
  /// managers, Notification Center, and system security surfaces.
  public var sensitiveApplicationBundleIdentifiers: Set<String>

  /// Rectangular regions (normalized `[0, 1]`, window-relative) that are
  /// always redacted regardless of recognized content.
  public var userDefinedRedactionRegions: [UserDefinedRedactionRegion]

  /// Regex-based patterns applied to OCR-recognized text to catch financial
  /// data, authentication codes, and other configured secret shapes.
  public var redactionPatterns: [RedactionRule]

  /// Whether OCR-based text redaction runs at all. Disabling this leaves
  /// only sensitive-app exclusion and user-defined-region redaction active —
  /// a deliberate degrade path, not a silent capability loss, if Vision text
  /// recognition is ever unavailable or undesired.
  public var ocrRedactionEnabled: Bool

  /// Whether a captured raw image may be retained in memory for diagnostics.
  /// Off by default — "no retained screen data unless diagnostic opt-in."
  /// When enabled, retention duration is governed by the existing
  /// `PrivacyConfiguration.screenshotRetentionDays`, not a separate field.
  public var retainRawFrames: Bool

  /// Seconds after capture that an observation is still considered fresh.
  public var freshnessSeconds: Double

  /// Maximum width/height, in pixels, requested from the capture API —
  /// bounds both cost and the amount of detail retained even transiently.
  public var maxCaptureDimension: Int

  public init(
    enabled: Bool = false,
    sensitiveApplicationBundleIdentifiers: Set<String> = [
      "com.apple.keychainaccess",
      "com.apple.SecurityAgent",
      "com.apple.notificationcenterui",
      "com.1password.1password",
      "com.agilebits.onepassword7",
      "com.bitwarden.desktop",
      "com.lastpass.LastPass",
      "com.dashlane.dashlanephonefinal",
    ],
    userDefinedRedactionRegions: [UserDefinedRedactionRegion] = [],
    redactionPatterns: [RedactionRule] = ScreenContextConfiguration.defaultRedactionPatterns,
    ocrRedactionEnabled: Bool = true,
    retainRawFrames: Bool = false,
    freshnessSeconds: Double = 5.0,
    maxCaptureDimension: Int = 2048
  ) {
    self.enabled = enabled
    self.sensitiveApplicationBundleIdentifiers = sensitiveApplicationBundleIdentifiers
    self.userDefinedRedactionRegions = userDefinedRedactionRegions
    self.redactionPatterns = redactionPatterns
    self.ocrRedactionEnabled = ocrRedactionEnabled
    self.retainRawFrames = retainRawFrames
    self.freshnessSeconds = freshnessSeconds
    self.maxCaptureDimension = maxCaptureDimension
  }

  /// Financial-data and authentication-code shapes, in addition to
  /// `OutputRedactor.default`'s generic secret-token patterns.
  public static let defaultRedactionPatterns: [RedactionRule] = [
    RedactionRule(pattern: "\\b(?:\\d[ -]*?){13,19}\\b", replacement: "<redacted-card-number>"),
    RedactionRule(pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b", replacement: "<redacted-ssn-shaped>"),
    RedactionRule(
      pattern: "\\b(?:[Cc]ode|OTP|otp)[:\\s]+\\d{4,8}\\b",
      replacement: "<redacted-auth-code>"),
    RedactionRule(pattern: "sk-[a-zA-Z0-9]{20,}", replacement: "<redacted-api-key>"),
    RedactionRule(
      pattern: "eyJ[A-Za-z0-9_-]*\\.eyJ[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*",
      replacement: "<redacted-jwt>"),
  ]

  public func validate() throws(AuraError) {
    guard freshnessSeconds > 0 else {
      throw AuraError.invalidConfiguration("screen freshnessSeconds must be positive")
    }
    guard maxCaptureDimension > 0 else {
      throw AuraError.invalidConfiguration("screen maxCaptureDimension must be positive")
    }
    for region in userDefinedRedactionRegions {
      guard region.width > 0, region.height > 0 else {
        throw AuraError.invalidConfiguration(
          "screen userDefinedRedactionRegions entries must have positive width/height")
      }
      guard (0...1).contains(region.originX), (0...1).contains(region.originY) else {
        throw AuraError.invalidConfiguration(
          "screen userDefinedRedactionRegions entries must have x/y in [0, 1]")
      }
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> ScreenContextConfiguration {
    let defaults = ScreenContextConfiguration()
    return ScreenContextConfiguration(
      enabled: self.enabled,
      sensitiveApplicationBundleIdentifiers: self.sensitiveApplicationBundleIdentifiers.isEmpty
        ? defaults.sensitiveApplicationBundleIdentifiers
        : self.sensitiveApplicationBundleIdentifiers,
      userDefinedRedactionRegions: self.userDefinedRedactionRegions,
      redactionPatterns: self.redactionPatterns.isEmpty
        ? defaults.redactionPatterns
        : self.redactionPatterns,
      ocrRedactionEnabled: self.ocrRedactionEnabled,
      retainRawFrames: self.retainRawFrames,
      freshnessSeconds: self.freshnessSeconds <= 0
        ? defaults.freshnessSeconds
        : self.freshnessSeconds,
      maxCaptureDimension: self.maxCaptureDimension <= 0
        ? defaults.maxCaptureDimension
        : self.maxCaptureDimension
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = ScreenContextConfiguration()
    enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
    sensitiveApplicationBundleIdentifiers =
      try container.decodeIfPresent(
        Set<String>.self, forKey: .sensitiveApplicationBundleIdentifiers)
      ?? defaults.sensitiveApplicationBundleIdentifiers
    userDefinedRedactionRegions =
      try container.decodeIfPresent(
        [UserDefinedRedactionRegion].self, forKey: .userDefinedRedactionRegions)
      ?? defaults.userDefinedRedactionRegions
    redactionPatterns =
      try container.decodeIfPresent([RedactionRule].self, forKey: .redactionPatterns)
      ?? defaults.redactionPatterns
    ocrRedactionEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .ocrRedactionEnabled)
      ?? defaults.ocrRedactionEnabled
    retainRawFrames =
      try container.decodeIfPresent(Bool.self, forKey: .retainRawFrames) ?? defaults.retainRawFrames
    freshnessSeconds =
      try container.decodeIfPresent(Double.self, forKey: .freshnessSeconds)
      ?? defaults.freshnessSeconds
    maxCaptureDimension =
      try container.decodeIfPresent(Int.self, forKey: .maxCaptureDimension)
      ?? defaults.maxCaptureDimension
  }
}

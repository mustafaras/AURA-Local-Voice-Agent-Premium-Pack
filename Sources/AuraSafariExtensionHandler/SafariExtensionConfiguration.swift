import Foundation

/// The appex's own view of the bridge contract.
///
/// The extension process cannot read `AuraConfiguration`: it is launched by
/// Safari, not by AURA, so it inherits none of the app's environment. Every
/// value therefore comes from its own `Info.plist`, which the build script
/// fills from the same defaults the app uses. Reading them here rather than
/// hard-coding keeps one place to change when a profile or container moves,
/// and makes the mismatch visible as a refusal instead of a silent no-op.
struct SafariExtensionConfiguration: Equatable {
  let extensionID: String
  let profileID: String
  let secretServiceName: String
  let sharedContainerURL: URL

  static let extensionIDKey = "AURAExtensionID"
  static let profileIDKey = "AURAProfileID"
  static let secretServiceNameKey = "AURASecretServiceName"
  static let sharedContainerPathKey = "AURASharedContainerPath"

  /// Build the configuration from an Info.plist projection.
  ///
  /// A blank or absent value falls back to the shipped default rather than
  /// producing an empty identity: an empty `extensionID` would compare equal
  /// to a hostile message that also omits it, which is exactly the check the
  /// native handler exists to make.
  init(infoDictionary: [String: Any], homeDirectory: URL) {
    func string(_ key: String, default fallback: String) -> String {
      guard let raw = infoDictionary[key] as? String else { return fallback }
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? fallback : trimmed
    }
    extensionID = string(Self.extensionIDKey, default: "com.aura.safari-extension")
    profileID = string(Self.profileIDKey, default: "personal")
    secretServiceName = string(Self.secretServiceNameKey, default: "com.aura.safari-bridge")
    let rawPath = string(
      Self.sharedContainerPathKey,
      default: "Library/Application Support/AURA/SafariBridge/observation.json")
    sharedContainerURL =
      rawPath.hasPrefix("/")
      ? URL(fileURLWithPath: rawPath)
      : homeDirectory.appending(path: rawPath)
  }
}

import AuraCore
import Foundation
import Security

/// Whether the running code carries AURA's stable local signing identity
/// (ADR-030), evaluated with the Security framework against the code's own
/// signature (ADR-065 §2).
///
/// The answer decides the Keychain namespace: only code signed by
/// `AURA Stable Local Signing` reads and writes the production service names;
/// anything else — a `swift build` debug binary, a test host, an ad-hoc bundle
/// — is routed to the `.dev` namespace by `AppConfiguration.effectiveServiceName`.
/// That is what stops macOS from raising the Keychain password dialog when a
/// foreign identity touches the installed app's items, and stops a foreign
/// identity from re-ACL'ing them.
///
/// The requirement text names the certificate's subject CN rather than a
/// hash, so a re-provisioned certificate with the same name still counts as
/// stable (the identity inventory in `personal-assistant-plan/evidence/PA-1/`
/// records the hash for the diff check that PA-6 runs).
public enum CodeIdentity: String, Sendable, Equatable {
  /// Signed by `AURA Stable Local Signing`.
  case stable
  /// Signed, but not by the stable identity (ad-hoc, Apple, anything else).
  case foreign
  /// No valid signature could be evaluated.
  case unsigned
}

public protocol CodeIdentityProbing: Sendable {
  func identity() -> CodeIdentity
}

public struct CodeIdentityProbe: CodeIdentityProbing {
  public static let stableIdentityName = "AURA Stable Local Signing"
  private static let stableRequirement =
    "certificate leaf[subject.CN] = \"\(stableIdentityName)\""

  private let codeURL: URL

  /// Probes the main bundle (or, for an unbundled executable, the executable
  /// itself). Injected paths let tests evaluate other code objects.
  public init(codeURL: URL = Bundle.main.bundleURL) {
    self.codeURL = codeURL
  }

  public func identity() -> CodeIdentity {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(codeURL as CFURL, [], &staticCode) == errSecSuccess,
      let code = staticCode
    else { return .unsigned }
    // A code object with no usable signature at all fails validity against
    // an empty requirement; that is the `.unsigned` case.
    guard SecStaticCodeCheckValidityWithErrors(code, [], nil, nil) == errSecSuccess else {
      return .unsigned
    }
    var requirement: SecRequirement?
    guard
      SecRequirementCreateWithString(Self.stableRequirement as CFString, [], &requirement)
        == errSecSuccess, let stable = requirement
    else { return .foreign }
    return SecStaticCodeCheckValidityWithErrors(code, [], stable, nil) == errSecSuccess
      ? .stable : .foreign
  }
}

/// A probe with a fixed answer, for tests and for callers that already know.
public struct FixedCodeIdentityProbe: CodeIdentityProbing {
  public let fixed: CodeIdentity
  public init(_ fixed: CodeIdentity) { self.fixed = fixed }
  public func identity() -> CodeIdentity { fixed }
}

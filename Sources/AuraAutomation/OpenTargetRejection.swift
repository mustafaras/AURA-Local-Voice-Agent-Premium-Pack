import Foundation

/// Why a filesystem or URL open target was refused.
///
/// `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md` requires the filesystem
/// and URL capabilities to "reject unknown or unsafe targets" rather than
/// hand an unvalidated path or URL to LaunchServices. Each case is a distinct,
/// separately testable refusal so an adversarial test can assert the *reason*
/// a target was refused, not merely that something threw.
///
/// These are refusals, not failures: nothing has been opened when one is
/// thrown, so there is nothing to roll back.
public enum OpenTargetRejection: Error, Sendable, Equatable {
  case emptyTarget
  case notAnAbsolutePath
  case containsNullByte
  case targetTooLong(limit: Int)
  case doesNotExist
  case notARegularFile
  case notADirectory
  /// A `.app` (or other launchable bundle). Opening one executes it, which is
  /// far above `file.open`'s `.reversible` risk tier.
  case applicationBundle
  /// The resolved file would be executed rather than opened for viewing —
  /// either its extension is a known executable/script/bundle type, or its
  /// POSIX owner-executable bit is set, which makes LaunchServices run it.
  case executableTarget(detail: String)
  /// A location whose contents are credentials or privacy state. Opening one
  /// hands its contents to whatever application claims the type.
  case sensitiveLocation(detail: String)
  /// The target resolved (after symlink resolution) outside every approved
  /// root supplied by the caller.
  case outsideApprovedRoots
  case malformedURL
  case disallowedScheme(scheme: String)
  case missingHost
  /// A `user:password@host` URL. Refused because it leaks a credential into
  /// the opened application and is a standard phishing shape.
  case embeddedCredentials
  case controlCharactersInTarget

  /// A truthful, user-presentable reason. Never a placeholder, and never the
  /// raw path or URL — refusal reasons reach logs and ledgers, so they must
  /// not carry the private target itself.
  public var reason: String {
    switch self {
    case .emptyTarget:
      return "The target is empty."
    case .notAnAbsolutePath:
      return "The path must be absolute."
    case .containsNullByte:
      return "The target contains a null byte."
    case .targetTooLong(let limit):
      return "The target is longer than the \(limit)-character limit."
    case .doesNotExist:
      return "The target does not exist."
    case .notARegularFile:
      return "The target is not a regular file."
    case .notADirectory:
      return "The target is not a folder."
    case .applicationBundle:
      return "The target is an application bundle; opening it would launch it."
    case .executableTarget(let detail):
      return "The target would be executed rather than opened (\(detail))."
    case .sensitiveLocation(let detail):
      return "The target is in a protected location (\(detail))."
    case .outsideApprovedRoots:
      return "The target is outside the approved folders."
    case .malformedURL:
      return "The link is not a valid URL."
    case .disallowedScheme(let scheme):
      return "The \"\(scheme)\" link type is not allowed."
    case .missingHost:
      return "The link has no host."
    case .embeddedCredentials:
      return "The link embeds a username or password."
    case .controlCharactersInTarget:
      return "The target contains control characters."
    }
  }
}

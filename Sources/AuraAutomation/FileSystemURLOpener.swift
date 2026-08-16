import AppKit
import AuraCore
import Foundation

/// The LaunchServices surface the filesystem/URL capabilities need, isolated
/// behind a protocol so the adapter's validation, postcondition, and
/// cancellation behaviour are testable without opening anything on the machine
/// running the tests.
///
/// Both operations return `Bool`. That is the whole reason this protocol is
/// shaped around these two calls rather than the more familiar
/// `NSWorkspace.open(_:configuration:)`: they give a real success signal to
/// verify against, so the adapter never has to claim an unverified outcome.
public protocol LaunchServicesOpening: Sendable {
  /// `NSWorkspace.open(_:)` — returns whether the open was accepted.
  func open(_ url: URL) -> Bool
  /// `NSWorkspace.selectFile(_:inFileViewerRootedAtPath:)` — returns whether
  /// Finder accepted the selection.
  func selectFile(_ path: String, inFileViewerRootedAtPath root: String) -> Bool
}

/// Production implementation. Both `NSWorkspace` calls used here are safe to
/// invoke from a non-`MainActor` context under Swift 6 strict concurrency,
/// verified by a `swiftc -typecheck` probe before this type was written.
public struct SystemLaunchServices: LaunchServicesOpening {
  public init() {}

  public func open(_ url: URL) -> Bool {
    NSWorkspace.shared.open(url)
  }

  public func selectFile(_ path: String, inFileViewerRootedAtPath root: String) -> Bool {
    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: root)
  }
}

/// The result of an accepted open. `target` is the canonical, symlink-resolved
/// path or normalized URL that was actually handed to LaunchServices — not the
/// caller's raw input — so an audit record shows what was really opened.
public struct OpenOutcome: Sendable, Equatable {
  public let capabilityID: String
  public let target: String

  public init(capabilityID: String, target: String) {
    self.capabilityID = capabilityID
    self.target = target
  }
}

/// Typed adapter behind `filesystem.open_file`, `filesystem.open_folder`,
/// `filesystem.reveal`, and `url.open`.
///
/// Every method follows the same three-step contract:
///
/// 1. **Refuse first.** `OpenTargetValidator` runs before any side effect, so
///    a rejected target is never handed to LaunchServices and there is nothing
///    to roll back. Refusals surface as `AuraError.securityError`.
/// 2. **Check cancellation immediately before the side effect.** These
///    operations declare `supportsCancellation: false` because a handoff to
///    LaunchServices cannot be recalled once issued — but a task cancelled
///    *before* the handoff must not open anything, so the check sits as late
///    as it can while still preceding the effect.
/// 3. **Verify the postcondition.** Both underlying calls return a real
///    success flag; a `false` return is reported as
///    `AuraError.automationError` rather than being swallowed into a success.
///
/// What this adapter deliberately does *not* claim: that the handler
/// application became frontmost, or finished loading the target. LaunchServices
/// reports acceptance of the request, not completion by the receiving app, and
/// asserting more than the OS actually returns is the exact substitution this
/// program forbids.
///
/// A second limitation of the same kind: the validator checks what is opened,
/// not which application handles it once opened. A user whose default handler
/// for a file type has been replaced by a malicious application is not
/// protected here — the validator accepts the legitimate document and the
/// system runs the attacker's handler. Refusing executable extensions, the
/// POSIX executable bit, and location-forwarding types raises the floor for
/// direct code execution; it does not cover compromised handler applications.
/// This is deliberately outside SP-004's bounded objective and is recorded on
/// the risk register as `RISK-SP-004-HANDLER-COMPROMISE`.
public actor FileSystemURLOpener {
  private let validator: OpenTargetValidator
  private let launchServices: any LaunchServicesOpening
  private let logger: AuraLogger

  public init(
    validator: OpenTargetValidator = OpenTargetValidator(),
    launchServices: any LaunchServicesOpening = SystemLaunchServices(),
    logger: AuraLogger = AuraLogger(subsystem: "AuraAutomation", category: "open")
  ) {
    self.validator = validator
    self.launchServices = launchServices
    self.logger = logger
  }

  public func openFile(path: String) throws(AuraError) -> OpenOutcome {
    let url: URL
    do {
      url = try validator.validateFile(path: path)
    } catch let rejection as OpenTargetRejection {
      throw AuraError.securityError(rejection.reason)
    } catch {
      // Defensive: the validator's typed `throws(OpenTargetRejection)` makes
      // this unreachable today, but if someone widens it, fail closed rather
      // than silently swallowing an unknown refusal reason.
      throw AuraError.securityError("validation failed for an unknown reason")
    }
    return try perform(capabilityID: "filesystem.open_file", target: url.path) {
      launchServices.open(url)
    }
  }

  public func openFolder(path: String) throws(AuraError) -> OpenOutcome {
    let url: URL
    do {
      url = try validator.validateFolder(path: path)
    } catch let rejection as OpenTargetRejection {
      throw AuraError.securityError(rejection.reason)
    } catch {
      throw AuraError.securityError("validation failed for an unknown reason")
    }
    return try perform(capabilityID: "filesystem.open_folder", target: url.path) {
      launchServices.open(url)
    }
  }

  public func reveal(path: String) throws(AuraError) -> OpenOutcome {
    let url: URL
    do {
      url = try validator.validateRevealTarget(path: path)
    } catch let rejection as OpenTargetRejection {
      throw AuraError.securityError(rejection.reason)
    } catch {
      throw AuraError.securityError("validation failed for an unknown reason")
    }
    return try perform(capabilityID: "filesystem.reveal", target: url.path) {
      // An empty root string means "no particular Finder root", which is the
      // documented way to select an item in whatever window Finder chooses.
      launchServices.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
  }

  public func openURL(_ raw: String) throws(AuraError) -> OpenOutcome {
    let url: URL
    do {
      url = try validator.validateURL(raw)
    } catch let rejection as OpenTargetRejection {
      throw AuraError.securityError(rejection.reason)
    } catch {
      throw AuraError.securityError("validation failed for an unknown reason")
    }
    return try perform(capabilityID: "url.open", target: url.absoluteString) {
      launchServices.open(url)
    }
  }

  // MARK: - Shared execution contract

  /// Refusals surface as `AuraError.securityError` and failures as
  /// `AuraError.automationError`, kept distinct so a caller can tell
  /// "we would not do that" from "we tried and it failed".
  private func perform(
    capabilityID: String,
    target: String,
    _ effect: () -> Bool
  ) throws(AuraError) -> OpenOutcome {
    guard !Task.isCancelled else {
      throw AuraError.automationError("\(capabilityID) was cancelled before it opened anything")
    }
    guard effect() else {
      throw AuraError.automationError(
        "\(capabilityID) was refused by the system; nothing was opened")
    }
    return OpenOutcome(capabilityID: capabilityID, target: target)
  }
}

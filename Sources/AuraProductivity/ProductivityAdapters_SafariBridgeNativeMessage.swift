import AuraCore
import Foundation

/// The native message the Safari Web Extension sends to the containing app's
/// app extension. It is the wire form of one user-gated active-tab
/// observation. It carries observations only — never cookies, passwords,
/// hidden page state, page scripts, or authority to act.
public struct SafariBridgeNativeMessage: Codable, Sendable, Equatable {
  public static let messageType = "aura.activeTabObservation"

  public let type: String
  public let protocolVersion: Int
  public let extensionID: String
  public let profileID: String
  public let tab: SafariWebExtensionTabResponse

  public init(
    type: String = SafariBridgeNativeMessage.messageType,
    protocolVersion: Int = SafariBridgeSignedPayload.currentProtocolVersion,
    extensionID: String,
    profileID: String,
    tab: SafariWebExtensionTabResponse
  ) {
    self.type = type
    self.protocolVersion = protocolVersion
    self.extensionID = extensionID
    self.profileID = profileID
    self.tab = tab
  }
}

/// Receives the extension's native message, validates it against the expected
/// identity and protocol, and hands it to `SafariBridgeEnvelopeWriter` to be
/// signed into the shared container.
///
/// This is the testable core of the Safari app-extension entry point. The
/// Xcode `SafariWebExtensionHandler` shim is a thin wrapper that decodes the
/// message body and calls `handle(messageData:)`; keeping the logic here means
/// the whole extension-to-app path is exercised by the regression suite rather
/// than living in unbuilt glue code.
///
/// The message is untrusted input: identity, protocol version, profile scope,
/// and size are all checked before anything is signed.
public struct SafariBridgeNativeMessageHandler: Sendable {
  /// Upper bound on the raw native message, independent of the text bound, so
  /// a hostile or broken extension cannot force an unbounded decode.
  public static let maxMessageBytes = 1_048_576

  private let expectedExtensionID: String
  private let expectedProfileID: String
  private let writer: SafariBridgeEnvelopeWriter

  public init(
    expectedExtensionID: String,
    expectedProfileID: String,
    writer: SafariBridgeEnvelopeWriter
  ) {
    self.expectedExtensionID = expectedExtensionID
    self.expectedProfileID = expectedProfileID
    self.writer = writer
  }

  /// Validate and persist one observation. Returns the accepted tab so the
  /// app extension can log a redacted, non-content acknowledgement.
  @discardableResult
  public func handle(
    messageData: Data
  ) async throws(SafariBridgeTransportError) -> SafariWebExtensionTabResponse {
    guard messageData.count <= Self.maxMessageBytes else {
      throw .malformedMessage
    }

    let message: SafariBridgeNativeMessage
    do {
      message = try JSONDecoder().decode(SafariBridgeNativeMessage.self, from: messageData)
    } catch {
      throw .malformedMessage
    }

    guard message.type == SafariBridgeNativeMessage.messageType,
      message.protocolVersion == SafariBridgeSignedPayload.currentProtocolVersion
    else {
      throw .malformedMessage
    }
    // A message claiming another extension's identity is an impersonation
    // attempt, not a malformed payload.
    guard message.extensionID == expectedExtensionID else {
      throw .authenticationFailed
    }
    // The observation must stay inside the onboarded profile scope, and the
    // envelope's profile must match the tab's own.
    guard message.profileID == expectedProfileID,
      message.tab.profileID == message.profileID
    else {
      throw .profileMismatch
    }
    guard message.tab.tabID.utf8.count <= 256,
      message.tab.url.absoluteString.utf8.count <= 4_096,
      message.tab.title.utf8.count <= 1_024
    else {
      throw .malformedMessage
    }

    try await writer.write(tab: message.tab)
    return message.tab
  }
}

import AuraProductivity
import AuraSecurity
import Foundation
import SafariServices
import os

/// The Safari Web Extension's native half.
///
/// Safari launches this appex, hands it the extension's native message, and
/// expects a reply. Everything it does is delegated to
/// `SafariBridgeNativeMessageHandler`, which validates the untrusted message
/// and signs it into the shared container — the logic stays in
/// `AuraProductivity` so the regression suite covers the whole path instead of
/// this glue.
///
/// Before SP-011 this class did not exist. `SafariBridgeNativeMessageHandler`
/// documented itself as "the testable core of the Safari app-extension entry
/// point" and named a shim that was never written, so the producing half of
/// the bridge had no way to run: the app validated an envelope nothing could
/// place. That is why `browser.read` could not reach `.ready` on a real Mac.
///
/// The reply is a status word only. No page text, URL, title, secret, or
/// envelope field is echoed back into the extension's JavaScript context: the
/// web side already had the observation, and anything else returned would be
/// new information crossing into a less trusted process.
@objc(SafariWebExtensionHandler)
public final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
  private static let log = Logger(
    subsystem: "ai.aura.local.agent.safari-extension", category: "bridge")

  public func beginRequest(with context: NSExtensionContext) {
    guard let item = context.inputItems.first as? NSExtensionItem,
      let body = item.userInfo?[SFExtensionMessageKey]
    else {
      Self.reply(context, status: "rejected")
      return
    }

    let messageData: Data
    do {
      // Safari delivers the message as a property-list object graph, not as
      // JSON bytes. Re-encoding it here keeps one decoder — the validated,
      // bounded one in `SafariBridgeNativeMessageHandler` — rather than a
      // second, looser parse of the same untrusted input.
      messageData = try JSONSerialization.data(withJSONObject: body)
    } catch {
      Self.reply(context, status: "rejected")
      return
    }

    let configuration = SafariExtensionConfiguration(
      infoDictionary: Bundle.main.infoDictionary ?? [:],
      homeDirectory: SafariExtensionConfiguration.realHomeDirectory())

    // `NSExtensionContext` is not `Sendable` and the protocol requirement is
    // not actor-isolated, so the context has to be carried into the task by
    // hand. It is safe here for a reason narrower than "Apple objects usually
    // are": this handler receives exactly one request, touches the context
    // nowhere else, and completes it exactly once at the end of the task —
    // there is no second reference that could race it.
    let pending = PendingRequest(context: context)
    Task {
      let status = await Self.accept(messageData: messageData, configuration: configuration)
      Self.reply(pending.context, status: status)
    }
  }

  /// One in-flight request's context, moved into the completion task.
  private struct PendingRequest: @unchecked Sendable {
    let context: NSExtensionContext
  }

  /// Validate and persist one observation, returning the status word to echo.
  ///
  /// `internal` rather than private so the regression suite can exercise the
  /// same path the appex takes, including the failure words.
  static func accept(
    messageData: Data,
    configuration: SafariExtensionConfiguration
  ) async -> String {
    do {
      try FileManager.default.createDirectory(
        at: configuration.sharedContainerURL.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    } catch {
      log.error("shared container directory is unavailable")
      return "unavailable"
    }

    let writer = SafariBridgeEnvelopeWriter(
      extensionID: configuration.extensionID,
      profileID: configuration.profileID,
      sharedContainerURL: configuration.sharedContainerURL,
      secretStore: SafariBridgeSecretStore(
        secretStore: KeychainSecretStore(serviceName: configuration.secretServiceName),
        serviceName: configuration.secretServiceName))
    let handler = SafariBridgeNativeMessageHandler(
      expectedExtensionID: configuration.extensionID,
      expectedProfileID: configuration.profileID,
      writer: writer)

    do {
      _ = try await handler.handle(messageData: messageData)
      return "accepted"
    } catch {
      // The reason is logged as a bare case name — never the message, the
      // page, or the secret — and the extension learns only that the bridge
      // refused.
      log.error("bridge refused an observation: \(String(describing: error), privacy: .public)")
      switch error {
      case .notProvisioned: return "notProvisioned"
      case .authenticationFailed, .profileMismatch: return "rejected"
      case .malformedMessage: return "malformed"
      case .stale, .unavailable: return "unavailable"
      }
    }
  }

  private static func reply(_ context: NSExtensionContext, status: String) {
    let response = NSExtensionItem()
    response.userInfo = [SFExtensionMessageKey: ["status": status]]
    context.completeRequest(returningItems: [response])
  }
}

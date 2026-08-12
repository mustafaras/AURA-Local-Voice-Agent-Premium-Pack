import AuraCore
import AuraSecurity
import Foundation

public struct SafariBrowserReadAdapter: BrowserReadAdapter, Sendable {
  private let profile: BrowserProfileScope
  private let networkPolicy: ProductivityNetworkPolicy
  private let transport: any SafariWebExtensionTransport
  private let classifier: PromptInjectionClassifier

  public init(
    profile: BrowserProfileScope,
    networkPolicy: ProductivityNetworkPolicy,
    transport: any SafariWebExtensionTransport,
    classifier: PromptInjectionClassifier = PromptInjectionClassifier()
  ) {
    self.profile = profile
    self.networkPolicy = networkPolicy
    self.transport = transport
    self.classifier = classifier
  }

  public func readActiveTab() async throws(ProductivityError) -> BrowserTabSnapshot {
    let response: SafariWebExtensionTabResponse
    do {
      response = try await transport.readActiveTab(profileID: profile.profileID)
    } catch {
      throw .providerUnavailable
    }
    guard response.profileID == profile.profileID else {
      throw .profileAmbiguous(candidates: [profile.profileID, response.profileID])
    }
    try networkPolicy.validate(response.url)
    let title = ExternalContent(
      sourceID: "browser:\(response.tabID):title",
      text: response.title,
      provenance: .webContent,
      classifier: classifier)
    let visibleText = ExternalContent(
      sourceID: "browser:\(response.tabID):visible-text",
      text: response.visibleText,
      provenance: .webContent,
      classifier: classifier)
    guard !visibleText.isBlocked else {
      throw .privacyBlocked(reason: "page text matched an injection-blocking rule")
    }
    return BrowserTabSnapshot(
      id: response.tabID,
      profileID: response.profileID,
      url: response.url,
      title: title,
      visibleText: visibleText)
  }
}

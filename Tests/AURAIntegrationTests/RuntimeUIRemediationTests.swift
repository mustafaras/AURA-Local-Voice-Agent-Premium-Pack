import AuraCore
import Foundation
import Testing

@testable import AURA

@Suite("Runtime and UI remediation")
struct RuntimeUIRemediationTests {
  @Test("clean profile creates private application support directory")
  func cleanProfileCreatesApplicationSupportDirectory() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let databaseURL = try ApplicationSupportBootstrap.databaseURL(baseDirectory: root)

    #expect(databaseURL.lastPathComponent == "aura.db")
    #expect(FileManager.default.fileExists(atPath: databaseURL.deletingLastPathComponent().path))
    let attributes = try FileManager.default.attributesOfItem(
      atPath: databaseURL.deletingLastPathComponent().path)
    let permissions = attributes[.posixPermissions] as? NSNumber
    #expect(permissions?.intValue == 0o700)
  }

  @Test("safe production fallback denies confirmation")
  func safeFallbackDeniesConfirmation() async {
    let challenge = makeChallenge()
    let response = await SafeDenyConfirmationPresenter().present(challenge: challenge)

    #expect(response.requestID == challenge.requestID)
    #expect(response.nonce == challenge.nonce)
    #expect(response.responseHash == challenge.expectedHash)
    #expect(response.accepted == false)
  }

  @Test("interactive presenter denies without a connected UI")
  func interactivePresenterDeniesWithoutUI() async {
    let presenter = UIConfirmationPresenter()
    let response = await presenter.present(challenge: makeChallenge())
    #expect(response.accepted == false)
  }

  private func makeChallenge() -> PolicyConfirmationChallenge {
    PolicyConfirmationChallenge(
      requestID: UUID(),
      sessionID: UUID(),
      nonce: UUID().uuidString,
      issuedAt: Date(),
      requestedAction: .shellExec,
      targetSummary: "/usr/bin/true",
      riskTier: .mutation,
      expiresAt: Date().addingTimeInterval(30),
      expectedHash: "test-confirmation-hash")
  }
}

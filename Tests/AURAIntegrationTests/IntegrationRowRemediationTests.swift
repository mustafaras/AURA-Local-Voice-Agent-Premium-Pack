import AuraCore
import AuraIntent
import AuraProductivity
import Foundation
import Testing

@testable import AURA

/// The integrations row must never be a dead end: whatever blocks a leg, the
/// row has to offer the control that lifts it — or, when only macOS owns the
/// decision, name the exact System Settings pane.
///
/// These tests pin the projection rules introduced when the calendar and
/// contacts legs became composed by default and every blocked row gained a
/// reachable remediation button.
@Suite("Integration row remediation projection")
struct IntegrationRowRemediationTests {
  private func snapshot(
    capabilityID: String,
    availability: CapabilityAvailability,
    remediation: String,
    isRevocable: Bool = false,
    canConnect: Bool = false,
    canGrantAccess: Bool = false
  ) -> ProductivityIntegrationSnapshot {
    ProductivityIntegrationSnapshot(
      capabilityID: capabilityID,
      availability: availability,
      accountLabel: nil, sourceFingerprint: nil,
      remediation: remediation,
      isRevocable: isRevocable,
      canConnect: canConnect,
      canGrantAccess: canGrantAccess)
  }

  private func uncomposedNativeLeg(
    capabilityID: String, configurationKey: String, name: String
  ) -> ProductivityIntegrationSnapshot {
    ProductivityRuntime.nativeSnapshot(
      capabilityID: capabilityID,
      isComposed: false,
      state: .notDetermined,
      name: name,
      settingsPaneName: name,
      configurationKey: configurationKey)
  }

  // MARK: - The enable action

  @Test("an uncomposed native leg offers the enable-in-configuration action")
  @MainActor
  func uncomposedLegOffersEnable() {
    let model = AuraAppModel(startRuntime: false)
    defer { model.bootTask?.cancel() }

    let calendar = uncomposedNativeLeg(
      capabilityID: InitialCapabilitySet.calendarRead.id,
      configurationKey: "calendarReadEnabled", name: "Calendar")
    let row = model.integrationRowForTesting(calendar)
    #expect(row.canEnableInConfiguration)
    #expect(!row.canOpenSystemSettings)
    #expect(row.systemSettingsAnchor == nil)
  }

  @Test("a denied native leg offers the System Settings pane, not the enable action")
  @MainActor
  func deniedLegOffersSettings() {
    let model = AuraAppModel(startRuntime: false)
    defer { model.bootTask?.cancel() }

    let denied = ProductivityRuntime.nativeSnapshot(
      capabilityID: InitialCapabilitySet.contactsLookup.id,
      isComposed: true,
      state: .denied,
      name: "Contacts",
      settingsPaneName: "Contacts",
      configurationKey: "contactsReadEnabled")
    let row = model.integrationRowForTesting(denied)
    #expect(!row.canEnableInConfiguration)
    #expect(row.canOpenSystemSettings)
    #expect(row.systemSettingsAnchor == "Contacts")
  }

  @Test("the calendar denial anchors the Calendars pane")
  @MainActor
  func calendarDenialAnchorsCalendarsPane() {
    let model = AuraAppModel(startRuntime: false)
    defer { model.bootTask?.cancel() }

    let denied = ProductivityRuntime.nativeSnapshot(
      capabilityID: InitialCapabilitySet.calendarRead.id,
      isComposed: true,
      state: .denied,
      name: "Calendar",
      settingsPaneName: "Calendars",
      configurationKey: "calendarReadEnabled")
    let row = model.integrationRowForTesting(denied)
    #expect(row.canOpenSystemSettings)
    #expect(row.systemSettingsAnchor == "Calendars")
  }

  @Test("mail and browser rows never offer native-leg actions")
  @MainActor
  func providerLegsCarryNoNativeActions() {
    let model = AuraAppModel(startRuntime: false)
    defer { model.bootTask?.cancel() }

    let mail = snapshot(
      capabilityID: InitialCapabilitySet.mailRead.id,
      availability: .disabled(reason: "No mail account is approved yet."),
      remediation: "Approve a mail account in Setup, then connect it.")
    let mailRow = model.integrationRowForTesting(mail)
    #expect(!mailRow.canEnableInConfiguration)
    #expect(!mailRow.canOpenSystemSettings)
    #expect(mailRow.systemSettingsAnchor == nil)

    let browser = snapshot(
      capabilityID: InitialCapabilitySet.browserRead.id,
      availability: .disabled(reason: "Safari bridge is not provisioned for this profile"),
      remediation: "Connect the Safari profile in Setup to provision the bridge secret.",
      canConnect: true)
    let browserRow = model.integrationRowForTesting(browser)
    #expect(!browserRow.canEnableInConfiguration)
    #expect(!browserRow.canOpenSystemSettings)
    #expect(browserRow.systemSettingsAnchor == nil)
  }

  // MARK: - Reconnection

  @Test("an expired Gmail credential offers the reconnect action")
  @MainActor
  func expiredCredentialOffersReconnect() {
    let model = AuraAppModel(startRuntime: false)
    defer { model.bootTask?.cancel() }

    let expired = snapshot(
      capabilityID: InitialCapabilitySet.mailRead.id,
      availability: .degraded(reason: "The stored credential for p•••@example.com is no longer valid."),
      remediation: "Reconnect Gmail to restore read-only access.")
    let row = model.integrationRowForTesting(expired)
    #expect(row.canReconnect)
  }

  @Test("a disabled mail row does not offer reconnection")
  @MainActor
  func disabledMailOffersNoReconnect() {
    let model = AuraAppModel(startRuntime: false)
    defer { model.bootTask?.cancel() }

    let unconnected = snapshot(
      capabilityID: InitialCapabilitySet.mailRead.id,
      availability: .disabled(reason: "No mail account is approved yet."),
      remediation: "Approve a mail account in Setup, then connect it.")
    #expect(!model.integrationRowForTesting(unconnected).canReconnect)

    let uncomposed = snapshot(
      capabilityID: InitialCapabilitySet.mailRead.id,
      availability: .disabled(reason: "Mail is not composed: integration is not configured."),
      remediation: "Correct the mail endpoint and allowed hosts in configuration.")
    #expect(!model.integrationRowForTesting(uncomposed).canReconnect)
  }

  // MARK: - Ready rows offer nothing

  @Test("a ready row offers no remediation actions at all")
  @MainActor
  func readyRowIsQuiet() {
    let model = AuraAppModel(startRuntime: false)
    defer { model.bootTask?.cancel() }

    let ready = ProductivityRuntime.nativeSnapshot(
      capabilityID: InitialCapabilitySet.calendarRead.id,
      isComposed: true,
      state: .authorized,
      name: "Calendar",
      settingsPaneName: "Calendars",
      configurationKey: "calendarReadEnabled")
    let row = model.integrationRowForTesting(ready)
    #expect(row.isReady)
    #expect(!row.canEnableInConfiguration)
    #expect(!row.canOpenSystemSettings)
    #expect(!row.canReconnect)
    #expect(row.remediation.isEmpty)
  }

  // MARK: - Turkish remediation localization

  @Test("the known remediation strings localize to Turkish")
  @MainActor
  func remediationLocalizesToTurkish() {
    let model = AuraAppModel(startRuntime: false)
    defer { model.bootTask?.cancel() }
    model.productUIState.language = .turkish

    #expect(
      model.localizedReason("Set productivity.calendarReadEnabled to enable calendar reads.")
        .contains("calendarReadEnabled"))
    #expect(
      model.localizedReason("Set productivity.contactsReadEnabled to enable contacts reads.")
        != "Set productivity.contactsReadEnabled to enable contacts reads.")
    #expect(
      model.localizedReason("Calendar access is denied for AURA.")
        .contains("reddedildi"))
    #expect(
      model.localizedReason("Allow AURA in System Settings › Privacy & Security › Calendars.")
        .contains("Sistem Ayarları"))
    #expect(
      model.localizedReason("Connect the Safari profile in Setup to provision the bridge secret.")
        .contains("Kurulum"))
    #expect(
      model.localizedReason("No mail account is approved yet.")
        == "Henüz onaylanmış posta hesabı yok.")
    #expect(
      model.localizedReason("Reconnect Gmail to restore read-only access.")
        == "Salt okunur erişimi geri yüklemek için Gmail'i yeniden bağlayın.")

    // English stays unchanged.
    model.productUIState.language = .english
    #expect(
      model.localizedReason("No mail account is approved yet.")
        == "No mail account is approved yet.")
  }
}
import AuraAgent
import AuraCore
import Foundation
import SwiftUI

struct AuraLatencyHistoryPoint: Equatable {
  let measuredAt: Date
  let p50Milliseconds: Double
  let p95Milliseconds: Double
  let p99Milliseconds: Double
}

struct AuraMenuView: View {
  @ObservedObject var model: AuraAppModel
  @Environment(\.openSettings) var openSettings

  /// Whether the transcript viewport is at the bottom. Auto-scroll follows
  /// the stream only while this holds; scrolling up pauses it (UI-1 G1-4).
  /// Internal (not private): the conversation surface lives in an extension
  /// in `AuraMenuView_Content.swift`.
  @State var isStickToBottom = true
  /// Whether the jump-to-latest affordance is visible (user scrolled up).
  @State var showJumpToLatest = false
  /// Pull-cadence latency history. This remains in memory at the view layer;
  /// it is never persisted or written to a file (UI-3 G3-3).
  @State var latencyHistory: [LatencyMeasuredEvent.Kind: [AuraLatencyHistoryPoint]] = [:]
  @State var isCommandPalettePresented = false

  var language: AuraUILanguage { model.productUIState.language }

}

struct AuraConfirmationCard: View {
  @ObservedObject var model: AuraAppModel
  let challenge: PolicyConfirmationChallenge

  private var language: AuraUILanguage { model.productUIState.language }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  var body: some View {
    // The highest-stakes surface in the product: the user is authorizing a real
    // action. It is deliberately the most prominent panel — tinted heading,
    // risk stated in words, and the safe choice (Deny) reachable first in both
    // reading and tab order.
    AuraPanel(title: copy("confirmation.title"), tint: .orange) {
      VStack(alignment: .leading, spacing: AuraDesign.Spacing.s) {
        Text("\(challenge.requestedAction.domain).\(challenge.requestedAction.action)")
          .font(AuraDesign.Typography.sectionTitle)
        Text(challenge.targetSummary)
          .font(AuraDesign.Typography.body)
          .fixedSize(horizontal: false, vertical: true)
        Label(
          "\(copy("confirmation.riskPrefix")): \(challenge.riskTier.rawValue) · "
            + "\(copy("confirmation.expires")) \(challenge.expiresAt.formatted())",
          systemImage: "exclamationmark.shield"
        )
        .font(AuraDesign.Typography.meta)
        .foregroundStyle(.secondary)
        if let turnContext = challenge.turnContext {
          let traceText = AuraTraceDisplay.summary(
            correlationID: turnContext.correlationID, causationID: turnContext.causationID)
          Text(traceText)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .accessibilityLabel("\(copy("a11y.tracePrefix")): \(traceText)")
        }
        HStack {
          Button(copy("confirmation.deny"), role: .cancel) {
            model.resolveConfirmation(accepted: false, outcome: .denied)
          }
          .keyboardShortcut(.cancelAction)
          Spacer()
          Button(copy("confirmation.allowOnce")) {
            model.resolveConfirmation(accepted: true, outcome: .accepted)
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
    .accessibilityIdentifier(AuraCommandPaletteID.confirmationCard)
  }
}

struct MemoryRowView: View {
  @ObservedObject var model: AuraAppModel
  let record: AuraMemoryRow

  private var language: AuraUILanguage { model.productUIState.language }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 6) {
        Text(record.statement).fixedSize(horizontal: false, vertical: true)
        Text("\(record.memoryClass) · \(record.subject)")
          .font(.caption).foregroundStyle(.secondary)
        Text(
          "\(copy("memory.purpose")): \(record.purpose) · "
            + "\(copy("memory.provenance")): \(record.provenance)")
          .font(.caption2).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(
          "\(copy("memory.confidence")): \(Int(record.confidence * 100))% · "
            + "\(copy("memory.sensitivity")): \(record.sensitivity)")
          .font(.caption2).foregroundStyle(.secondary)
        Text(
          "\(copy("memory.retention")): \(String(describing: record.retention)) · "
            + "\(copy("memory.scope")): \(scopeSummary)")
          .font(.caption2).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if record.canMutate {
          HStack {
            Button(copy("memory.correctShort")) { model.beginMemoryCorrection(record) }
            Button(copy("memory.deleteShort"), role: .destructive) {
              model.deleteMemory(record.id)
            }
          }
        } else {
          Text(copy("memory.immutable"))
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .contain)
  }

  private var scopeSummary: String {
    let values = [
      record.scope.projectID.map { "project=\($0)" },
      record.scope.taskID.map { "task=\($0.uuidString.prefix(8))" },
      record.scope.sessionID.map { "session=\($0.uuidString.prefix(8))" },
    ].compactMap { $0 }
    return values.isEmpty ? copy("memory.global") : values.joined(separator: ", ")
  }
}

struct MemoryCorrectionSheet: View {
  @ObservedObject var model: AuraAppModel
  let record: AuraMemoryRow
  let draft: AuraMemoryCorrectionDraft

  init(model: AuraAppModel, record: AuraMemoryRow) {
    self.model = model
    self.record = record
    self.draft = AuraMemoryCorrectionDraft(statement: record.statement)
  }

  private var language: AuraUILanguage { model.productUIState.language }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(copy("privacy.correct")).font(.headline)
      TextEditor(
        text: Binding(
          get: { draft.statement },
          set: { draft.statement = $0 })
      )
      .frame(minHeight: 120)
      .border(.secondary)
      .accessibilityLabel(copy("a11y.correctedMemory"))
      HStack {
        Button(copy("action.cancel"), role: .cancel) { model.memoryCorrectionTarget = nil }
        Spacer()
        Button(copy("memory.saveCorrection")) {
          model.correctMemory(record.id, statement: draft.statement)
          model.memoryCorrectionTarget = nil
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
    .frame(width: 480, height: 260)
  }
}

final class AuraMemoryCorrectionDraft: ObservableObject {
  var statement: String

  init(statement: String) {
    self.statement = statement
  }
}

struct AuraOnboardingView: View {
  @ObservedObject var model: AuraAppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var orbAppeared = false
  private var language: AuraUILanguage { model.productUIState.language }
  private let totalSteps = AuraStepIndicator.totalStepCount

  private var stage: AuraOnboardingStage { model.productUIState.onboarding.stage }

  private var stepCounter: String {
    String(format: copy("onboarding.stepCounter"), stage.rawValue + 1, totalSteps)
  }

  private var stepAccessibilityLabel: String {
    String(format: copy("onboarding.stepAccessibilityLabel"), stage.rawValue + 1, totalSteps)
  }

  private var orbScale: CGFloat {
    Self.onboardingOrbScale(appeared: orbAppeared, reduceMotion: reduceMotion)
  }

  nonisolated static func onboardingOrbScale(appeared: Bool, reduceMotion: Bool) -> CGFloat {
    if reduceMotion {
      return AuraDesign.Measure.onboardingHeroOrbScale
    }
    if appeared {
      return AuraDesign.Measure.onboardingHeroOrbScale
    }
    return AuraDesign.Measure.onboardingEntryOrbScale
  }

  private var orbAccessibilityLabel: String {
    let layers = AuraOrbStateMapping.resolve(
      status: model.status,
      inputLevel: model.inputLevel,
      isSpeakingResponse: model.status == .speaking,
      language: language)
    return "\(copy("onboarding.iris")). \(layers.accessibilityLabel)"
  }

  var body: some View {
    HStack(alignment: .top, spacing: AuraDesign.Spacing.l) {
      VStack(spacing: AuraDesign.Spacing.s) {
        AuraOrb(
          status: model.status,
          inputLevel: model.inputLevel,
          isSpeakingResponse: model.status == .speaking,
          language: language,
          restrictedReason: model.status == .restricted ? model.displayStatusDetail : "")
          .scaleEffect(orbScale)
          .animation(AuraDesign.Motion.motion(AuraDesign.Motion.emergent), value: orbAppeared)
          .onAppear { orbAppeared = true }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(orbAccessibilityLabel)
          .accessibilityIdentifier("aura.onboarding.iris")
        Text(copy("onboarding.iris"))
          .font(AuraDesign.Typography.meta.weight(.semibold))
          .foregroundStyle(AuraDesign.Palette.biolume)
          .accessibilityIdentifier("aura.onboarding.irisReadout")
          .accessibilityLabel(orbAccessibilityLabel)
          .accessibilityValue(orbAccessibilityLabel)
      }
      .frame(width: 120)

      VStack(alignment: .leading, spacing: AuraDesign.Spacing.s) {
        HStack(alignment: .firstTextBaseline) {
          Text(copy("onboarding.title"))
            .font(.title2.bold())
          Spacer(minLength: AuraDesign.Spacing.s)
          Button(copy("onboarding.close")) { model.closeOnboarding() }
            .accessibilityIdentifier(AuraAccessibilityID.onboardingClose)
        }

        AuraStepIndicator(
          currentStep: stage.rawValue,
          optionalSteps: Set(
            AuraOnboardingStage.allCases.filter(\.isOptional).map(\.rawValue)),
          accessibilityLabel: stepAccessibilityLabel)
        Text(stepCounter)
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(AuraDesign.Palette.textSecondary)

        HStack(alignment: .top, spacing: AuraDesign.Spacing.s) {
          Image(systemName: stageIconName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(AuraDesign.Palette.biolume)
            .frame(width: 44, height: 44)
            .background(
              AuraDesign.Palette.biolume.opacity(0.14),
              in: RoundedRectangle(cornerRadius: AuraDesign.Radius.medium, style: .continuous))
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: AuraDesign.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AuraDesign.Spacing.s) {
              Text(copy(stage.copyKey))
                .font(.title3.bold())
              if stage.isOptional {
                Text(copy("onboarding.optionalChip"))
                  .font(AuraDesign.Typography.meta.weight(.semibold))
                  .foregroundStyle(AuraDesign.Palette.cautious)
                  .padding(.horizontal, AuraDesign.Spacing.xs)
                  .padding(.vertical, AuraDesign.Spacing.xxs)
                  .background(
                    AuraDesign.Palette.cautious.opacity(0.14),
                    in: Capsule())
              }
            }
            Text(explanation)
              .font(AuraDesign.Typography.body)
              .fixedSize(horizontal: false, vertical: true)
            if stage == .privilegedAccess {
              consentPassRows
            }
            if stage == .launchAtLogin {
              launchAtLoginStatusRow
            }
          }
        }

        Spacer(minLength: 0)
        HStack {
          if stage.isOptional {
            Button(copy("onboarding.skip")) { model.skipOptionalOnboardingStep() }
              .accessibilityIdentifier(AuraAccessibilityID.onboardingSkip)
          }
          Spacer(minLength: 0)
          Button(primaryLabel) { model.onboardingPrimaryAction() }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(AuraAccessibilityID.onboardingPrimary)
        }
      }
    }
    .padding(AuraDesign.Spacing.xl)
    .frame(width: 560, height: 300)
  }

  /// ADR-065 §3: the single consent pass — one live row per permission, in
  /// request order, with a System Settings fallback once macOS will no
  /// longer prompt for it (any decided, non-granted state). Presentation
  /// only; the stage machine and its actions are unchanged.
  private var consentPassRows: some View {
    LazyVGrid(
      columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
      alignment: .leading, spacing: AuraDesign.Spacing.xxs
    ) {
      ForEach(PermissionKind.allCases, id: \.rawValue) { kind in
        let state = model.permissions.state(for: kind)
        HStack(spacing: AuraDesign.Spacing.xs) {
          Image(systemName: state == .granted ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(
              state == .granted ? AuraDesign.Palette.signal : AuraDesign.Palette.cautious)
            .accessibilityHidden(true)
          Text(copy(kind.copyKey))
            .font(AuraDesign.Typography.meta)
          Text(state.title(for: language))
            .font(AuraDesign.Typography.meta)
            .foregroundStyle(.secondary)
          if state != .granted && state != .notDetermined {
            Button {
              model.openPrivacySettings(for: kind)
            } label: {
              Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
              "\(copy("integrations.systemSettings")): \(copy(kind.copyKey))")
            .accessibilityIdentifier(
              AuraAccessibilityID.onboardingPermissionSettings(kind.rawValue))
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy(kind.copyKey)): \(state.title(for: language))")
        .accessibilityIdentifier(AuraAccessibilityID.onboardingPermissionRow(kind.rawValue))
      }
    }
    .padding(.top, AuraDesign.Spacing.xxs)
  }

  /// ADR-066 (PA-2): the `launchAtLogin` stage is informational — one live
  /// status row (on / awaiting approval / off) and, in the approval state,
  /// the Login Items deep link verified in G2-1. Presentation only; the
  /// stage machine, its optionality, and its actions are unchanged.
  private var launchAtLoginStatus: String {
    if model.launchAtLoginRequiresApproval { return copy("onboarding.launchAtLogin.awaitingApproval") }
    return copy(model.launchAtLoginEnabled ? "onboarding.launchAtLogin.on" : "onboarding.launchAtLogin.off")
  }

  private var launchAtLoginStatusRow: some View {
    VStack(alignment: .leading, spacing: AuraDesign.Spacing.xxs) {
      HStack(spacing: AuraDesign.Spacing.xs) {
        Image(systemName: model.launchAtLoginEnabled ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(
            model.launchAtLoginEnabled ? AuraDesign.Palette.signal : AuraDesign.Palette.cautious)
          .accessibilityHidden(true)
        Text(copy("settings.launchAtLogin"))
          .font(AuraDesign.Typography.meta)
        Text(launchAtLoginStatus)
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(copy("settings.launchAtLogin")): \(launchAtLoginStatus)")
      .accessibilityValue(launchAtLoginStatus)
      .accessibilityIdentifier(AuraAccessibilityID.onboardingLaunchAtLoginStatus)
      if model.launchAtLoginRequiresApproval {
        Text(copy("settings.launchAtLoginRequiresApproval"))
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Button(copy("settings.openLoginItems")) { model.openLoginItemsSettings() }
          .accessibilityIdentifier(AuraAccessibilityID.onboardingLaunchAtLoginOpenLoginItems)
      }
    }
    .padding(.top, AuraDesign.Spacing.xxs)
    .onAppear { model.refreshLaunchAtLogin() }
  }

  private var explanation: String {
    switch stage {
    case .privacy: return copy("onboarding.explain.privacy")
    case .health: return copy("onboarding.explain.health")
    case .voicePermissions: return copy("onboarding.explain.voicePermissions")
    case .voiceTest: return copy("onboarding.explain.voiceTest")
    case .ttsTest: return copy("onboarding.explain.ttsTest")
    case .wakeWord: return copy("onboarding.explain.wakeWord")
    case .privilegedAccess: return copy("onboarding.explain.privilegedAccess")
    case .localModel: return copy("onboarding.explain.localModel")
    case .integrations: return copy("onboarding.explain.integrations")
    case .emergencyStop: return copy("onboarding.explain.emergencyStop")
    case .safeCommand: return copy("onboarding.explain.safeCommand")
    case .launchAtLogin: return copy("onboarding.explain.launchAtLogin")
    case .complete: return copy("onboarding.explain.complete")
    }
  }

  private var primaryLabel: String {
    switch stage {
    case .voicePermissions: return copy("onboarding.primary.voicePermissions")
    case .voiceTest: return copy("onboarding.primary.voiceTest")
    case .emergencyStop: return copy("onboarding.primary.emergencyStop")
    case .complete: return copy("onboarding.primary.complete")
    default: return copy("onboarding.next")
    }
  }

  private var stageIconName: String {
    switch stage {
    case .privacy: return "lock.shield"
    case .health: return "stethoscope"
    case .voicePermissions: return "mic"
    case .voiceTest: return "waveform"
    case .ttsTest: return "speaker.wave.2"
    case .wakeWord: return "ear"
    case .privilegedAccess: return "hand.raised"
    case .localModel: return "cpu"
    case .integrations: return "link"
    case .emergencyStop: return "stop.circle"
    case .safeCommand: return "questionmark.circle"
    case .launchAtLogin: return "power"
    case .complete: return "checkmark.seal"
    }
  }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }
}

enum AuraSettingsCategory: String, CaseIterable, Identifiable, Sendable {
  case general
  case permissions
  case integrations
  case privacyConfig

  var id: String { rawValue }

  var copyKey: String {
    switch self {
    case .general: "settings.category.general"
    case .permissions: "settings.category.permissions"
    case .integrations: "settings.category.integrations"
    case .privacyConfig: "settings.category.privacyConfig"
    }
  }

  var symbolName: String {
    switch self {
    case .general: "gearshape"
    case .permissions: "lock.shield"
    case .integrations: "link"
    case .privacyConfig: "lock.doc"
    }
  }
}

struct AuraSettingsView: View {
  @ObservedObject var model: AuraAppModel
  @State private var selectedCategory: AuraSettingsCategory

  init(model: AuraAppModel, initialCategory: AuraSettingsCategory = .general) {
    self.model = model
    _selectedCategory = State(initialValue: initialCategory)
  }

  private var language: AuraUILanguage { model.productUIState.language }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  private static let confirmationCardAnchorID = "settings.pendingConfirmationCard"

  private static func categoryAccessibilityID(_ category: AuraSettingsCategory) -> String {
    "aura.settings.category.\(category.rawValue)"
  }

  var body: some View {
    ScrollViewReader { scrollProxy in
      VStack(spacing: 0) {
        Picker(copy("settings.categoryPicker"), selection: $selectedCategory) {
          ForEach(AuraSettingsCategory.allCases) { category in
            Text(copy(category.copyKey))
              .tag(category)
              .accessibilityIdentifier(Self.categoryAccessibilityID(category))
          }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("aura.settings.categoryPicker")
        .padding(.horizontal)
        .padding(.top, AuraDesign.Spacing.s)
        .padding(.bottom, AuraDesign.Spacing.xs)

        Form {
          categoryContent(selectedCategory)
        }
        .formStyle(.grouped)
        .padding()
      }
      .frame(width: 620, height: 600)
      .onAppear { model.refreshLaunchAtLogin() }
      // Closing this window with a confirmation still unanswered fails closed
      // rather than leaving the challenge to lapse on its 60 s timer.
      .onDisappear { model.denyConfirmationIfStillPending() }
      // Bring the first-row card into view the instant it appears, regardless
      // of which category raised the challenge or where the user was scrolled.
      .onChange(of: model.pendingConfirmation != nil) { _, isPending in
        guard isPending else { return }
        withAnimation {
          scrollProxy.scrollTo(Self.confirmationCardAnchorID, anchor: .top)
        }
      }
    }
  }

  @ViewBuilder
  private func categoryContent(_ category: AuraSettingsCategory) -> some View {
    // The confirmation card is deliberately the first element in every
    // category. It stays inline because a Settings-scene sheet can become
    // invisible when focus moves, which is the incident recorded in
    // EV-SP-030-20260831-R11-LIVE-GATE-02.
    if let challenge = model.pendingConfirmation {
      AuraConfirmationCard(model: model, challenge: challenge)
        .id(Self.confirmationCardAnchorID)
    }

    switch category {
    case .general:
      generalCategory
    case .permissions:
      permissionsCategory
    case .integrations:
      integrationsCategory
    case .privacyConfig:
      privacyConfigCategory
    }
  }

  @ViewBuilder
  private var generalCategory: some View {
    Section {
      Picker(
        copy("settings.language"),
        selection: Binding(
          get: { model.productUIState.language },
          set: { model.setUILanguage($0) })
      ) {
        Text("English").tag(AuraUILanguage.english)
        Text("Türkçe").tag(AuraUILanguage.turkish)
      }
      Button(copy("settings.openGuidedSetup")) { model.beginOnboarding() }
    } header: {
      settingsSectionHeader("settings.productUI", symbol: "slider.horizontal.3")
    }

    Section {
      Toggle(
        copy("settings.launchAtLogin"),
        isOn: Binding(
          get: { model.launchAtLoginEnabled },
          set: { model.setLaunchAtLogin($0) }))
        .accessibilityIdentifier(AuraAccessibilityID.launchAtLoginToggle)
      Text(copy("settings.launchAtLoginNote"))
        .font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if model.launchAtLoginRequiresApproval {
        // PA-2 / ADR-066: `.requiresApproval` is macOS's decision — shown,
        // not worked around. The link is the anchor verified in G2-1.
        Label(copy("settings.launchAtLoginRequiresApproval"), systemImage: "exclamationmark.triangle")
          .font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier(AuraAccessibilityID.launchAtLoginRequiresApproval)
        Button(copy("settings.openLoginItems")) { model.openLoginItemsSettings() }
          .accessibilityIdentifier(AuraAccessibilityID.launchAtLoginOpenLoginItems)
      }
      if !model.launchAtLoginDetail.isEmpty {
        Text(model.launchAtLoginDetail)
          .font(.caption2).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    } header: {
      settingsSectionHeader("settings.startup", symbol: "arrow.right.to.line.compact")
    }
  }

  @ViewBuilder
  private var permissionsCategory: some View {
    Section {
      permissionRow("perm.microphone", state: model.permissions.microphone)
      permissionRow("perm.speechRecognition", state: model.permissions.speechRecognition)
      permissionRow("perm.accessibility", state: model.permissions.accessibility)
      permissionRow("perm.screenRecording", state: model.permissions.screenRecording)
    } header: {
      settingsSectionHeader("settings.permissions.status", symbol: "checkmark.shield")
    }

    Section {
      Button(copy("settings.requestMicSpeech")) { model.requestVoicePermissions() }
      Button(copy("settings.requestAccessibility")) { model.requestAccessibilityPermission() }
      Button(copy("settings.requestScreenRecording")) {
        model.requestScreenRecordingPermission()
      }
    } header: {
      settingsSectionHeader("settings.permissions.grant", symbol: "hand.raised")
    }

    Section {
      Button {
        model.openMicrophoneSettings()
      } label: {
        Label(copy("settings.openMicSettings"), systemImage: "gearshape")
      }
      Button {
        model.openSpeechSettings()
      } label: {
        Label(copy("settings.openSpeechSettings"), systemImage: "gearshape")
      }
      Button {
        model.openAccessibilitySettings()
      } label: {
        Label(copy("settings.openAccessibilitySettings"), systemImage: "gearshape")
      }
      Button {
        model.openScreenRecordingSettings()
      } label: {
        Label(copy("settings.openScreenRecordingSettings"), systemImage: "gearshape")
      }
      Button(copy("settings.refreshPermissions")) { model.refreshPermissions() }
    } header: {
      settingsSectionHeader("settings.permissions.systemSettings", symbol: "gearshape")
    }
  }

  @ViewBuilder
  private var integrationsCategory: some View {
    Section {
      if model.isVSCodeBridgeAcceptanceEnabled {
        Text(copy("settings.bridgeSecretNote"))
          .foregroundStyle(.secondary)
        LabeledContent(copy("settings.extensionID"), value: model.vscodeBridgeExtensionID)
        SecureField(copy("settings.sharedSecret"), text: $model.vscodeBridgeSecret)
          .textContentType(.password)
        HStack {
          Button(copy("settings.provision")) { model.provisionVSCodeBridge() }
            .disabled(model.vscodeBridgeSecret.utf8.count < 16)
          Button(copy("settings.revoke")) { model.revokeVSCodeBridge() }
            .disabled(!model.isVSCodeBridgeProvisioned)
        }
        LabeledContent(
          copy("settings.auraKeychain"),
          value: model.isVSCodeBridgeProvisioned
            ? copy("settings.provisioned") : copy("settings.notProvisioned"))
      } else {
        Text(copy("settings.bridgeDisabled"))
          .foregroundStyle(.secondary)
      }
    } header: {
      settingsSectionHeader("settings.vscodeBridge", symbol: "link")
    }
  }

  @ViewBuilder
  private var privacyConfigCategory: some View {
    Section {
      Text(copy("settings.onDeviceNote"))
      Text(copy("settings.pluginIsolation"))
    } header: {
      settingsSectionHeader("settings.privacy", symbol: "lock")
    }

    Section {
      Toggle(
        copy("recovery.localTuning"),
        isOn: Binding(
          get: { model.localRecommendationsEnabled },
          set: { model.setLocalRecommendationsEnabled($0) }))
      Text(copy("settings.aggregateNote"))
        .foregroundStyle(.secondary)
      LabeledContent(copy("settings.effectiveKeys"), value: "\(model.effectiveConfiguration.count)")
      LabeledContent(copy("settings.auditRecords"), value: "\(model.configurationAuditCount)")
      ForEach(
        model.effectiveConfiguration.filter(\.differsFromDefault).prefix(8), id: \.key
      ) { entry in
        LabeledContent(entry.key, value: entry.value.displayValue)
      }
      Button(copy("settings.refreshConfig")) { model.refreshConfigurationInspection() }
    } header: {
      settingsSectionHeader("settings.configGovernance", symbol: "checklist")
    }
  }

  private func settingsSectionHeader(_ key: String, symbol: String) -> some View {
    AuraSectionHeader(title: copy(key), symbol: symbol)
      .accessibilityAddTraits(.isHeader)
  }

  private func permissionRow(_ key: String, state: PermissionState) -> some View {
    let title = copy(key)
    let localizedState = state.title(for: language)
    return AuraStatusRow(
      symbol: "checkmark.shield",
      title: title,
      detail: localizedState,
      state: localizedState,
      tint: AuraDesign.Palette.signal)
      .accessibilityLabel("\(title): \(localizedState)")
  }
}

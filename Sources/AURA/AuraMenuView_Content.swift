import AuraAgent
import AuraCore
import AuraIntent
import AppKit
import Foundation
import SwiftUI

/// Scroll anchor and threshold for the transcript's honest auto-scroll
/// (G1-4). The anchor id is stable across rebuilds; `stickiness` is the
/// bottom-proximity epsilon (pt) inside which "at the bottom" is true.
private enum AuraScrollAnchor {
  static let bottom = "aura.scroll.bottom"
  static let top = "aura.scroll.top"
  static let stickiness: CGFloat = 24
}

/// Gate for the G1-4 acceptance-harness scroll-away scaffold (see
/// `AuraAccessibilityID.debugScrollToTop`). False for every real user launch;
/// true only when an acceptance run explicitly sets the environment variable,
/// exactly like `AURA_TEXT_DEMO_SCRIPT` gates the text-turn driver. Not
/// `private` so the default-off contract is directly testable from
/// `@testable import AURA`.
enum AuraAcceptanceTestHooks {
  static let isEnabled =
    ProcessInfo.processInfo.environment["AURA_ACCEPTANCE_TEST_HOOKS"] == "1"
}

extension AuraMenuView {

  var body: some View {
    NavigationSplitView {
      sidebar
    } detail: {
      VStack(alignment: .leading, spacing: AuraDesign.Spacing.m) {
        header
        // Conversation owns the window: its transcript grows and the composer
        // stays anchored at the bottom, the way an assistant should read. The
        // other tabs are lists of arbitrary length, so those still scroll as a
        // whole. Wrapping conversation in the outer ScrollView too was what left
        // a band of dead space under the composer.
        if model.productUIState.selectedTab == .conversation {
          tabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
          ScrollView {
            tabContent
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.bottom, AuraDesign.Spacing.s)
          }
        }
      }
      .padding(AuraDesign.Spacing.l)
    }
    // L0 — the observatory canvas. The owned neutral is the point of the
    // palette; the window kept windowBackgroundColor and the identity never
    // reached the surface behind everything.
    .background(AuraDesign.Materials.base)
    .frame(minWidth: 820, minHeight: 720)
    .onAppear {
      model.refreshProductSnapshots()
      // A macOS privacy decision made outside this window (a TCC prompt in
      // another app, a change in System Settings) leaves the snapshot stale
      // until something re-reads it. Re-reading on every appear keeps the
      // permission indicators and the row buttons honest without a manual
      // refresh click.
      model.refreshPermissions()
    }
    .onChange(of: model.latencySummaries) { _, summaries in
      recordLatencyHistory(summaries)
    }
    .sheet(
      isPresented: Binding(
        get: { model.productUIState.onboarding.isPresented },
        set: { isPresented in
          if !isPresented { model.closeOnboarding() }
        })
    ) {
      AuraOnboardingView(model: model)
    }
    .sheet(item: $model.memoryCorrectionTarget) { record in
      MemoryCorrectionSheet(model: model, record: record)
    }
    .overlay {
      if isCommandPalettePresented {
        AuraCommandPalette(
          title: copy("settings.productUI"),
          cancelLabel: copy("action.cancel"),
          entries: commandPaletteEntries,
          onDismiss: { isCommandPalettePresented = false },
          onRequestDestructive: { entry in
            entry.action()
            isCommandPalettePresented = false
          })
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
      }
    }
  }

  /// Appends the pull result to a bounded, in-memory history. The percentile
  /// summary remains authoritative; this history only shows how the readout
  /// changed across explicit refreshes in this process.
  func recordLatencyHistory(_ summaries: [LatencyPercentileSummary]) {
    latencyHistory = Self.appendingLatencyHistory(
      existing: latencyHistory, summaries: summaries, measuredAt: Date())
  }

  nonisolated static func appendingLatencyHistory(
    existing: [LatencyMeasuredEvent.Kind: [AuraLatencyHistoryPoint]],
    summaries: [LatencyPercentileSummary],
    measuredAt: Date
  ) -> [LatencyMeasuredEvent.Kind: [AuraLatencyHistoryPoint]] {
    var result = existing
    for summary in summaries {
      var points = result[summary.kind, default: []]
      let point = AuraLatencyHistoryPoint(
        measuredAt: measuredAt,
        p50Milliseconds: summary.p50Milliseconds,
        p95Milliseconds: summary.p95Milliseconds,
        p99Milliseconds: summary.p99Milliseconds)
      if points.last?.p50Milliseconds != point.p50Milliseconds
        || points.last?.p95Milliseconds != point.p95Milliseconds
        || points.last?.p99Milliseconds != point.p99Milliseconds {
        points.append(point)
      }
      result[summary.kind] = Array(points.suffix(60))
    }
    return result
  }

  /// The command table is static in shape. Closures only dispatch to existing
  /// reducers, controls, or the existing confirmation-backed setting path.
  var commandPaletteEntries: [AuraCommandPaletteEntry] {
    let tabs = AuraProductTab.allCases.map { tab in
      AuraCommandPaletteEntry(
        id: "tab.\(tab.rawValue)",
        title: copy(tab.copyKey),
        symbol: tab.symbolName,
        requiresConfirmation: false,
        action: { model.selectTab(tab) })
    }
    return tabs + [
      AuraCommandPaletteEntry(
        id: "pushToTalk",
        title: copy("conversation.pushToTalk"),
        symbol: "mic.fill",
        requiresConfirmation: false,
        action: { model.pushToTalk() }),
      AuraCommandPaletteEntry(
        id: "settings",
        title: copy("settings.productUI"),
        symbol: "gearshape",
        requiresConfirmation: false,
        action: { openSettings() }),
      AuraCommandPaletteEntry(
        id: "emergencyStop",
        title: copy("emergency.stop"),
        symbol: "hand.raised.fill",
        requiresConfirmation: false,
        action: { model.triggerEmergencyStop() }),
      AuraCommandPaletteEntry(
        id: "launchAtLogin",
        title: copy("settings.launchAtLogin"),
        symbol: "power",
        requiresConfirmation: true,
        action: { model.setLaunchAtLogin(!model.launchAtLoginEnabled) }),
      AuraCommandPaletteEntry(
        id: "copyTranscript",
        title: copy("conversation.title"),
        symbol: "doc.on.doc",
        requiresConfirmation: false,
        action: copyTranscript),
      AuraCommandPaletteEntry(
        id: "clearComposer",
        title: copy("conversation.input"),
        symbol: "xmark.circle",
        requiresConfirmation: false,
        action: { model.textInput = "" }),
    ]
  }

  func copyTranscript() {
    let transcript = model.conversationMessages
      .map { "\($0.role.rawValue): \($0.text)" }
      .joined(separator: "\n")
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(transcript, forType: .string)
  }

  var header: some View {
    HStack(alignment: .center, spacing: AuraDesign.Spacing.m) {
      // Identity mark. The status colour is carried by the pill beside it, not
      // by the icon, so the app's identity stays visually stable while state
      // changes around it.
      ZStack {
        RoundedRectangle(cornerRadius: AuraDesign.Radius.medium, style: .continuous)
          .fill(AuraDesign.Palette.biolume.opacity(0.14))
        Image(systemName: model.status.symbolName)
          .font(.subheadline.weight(.semibold))
          // The mark's field and its glyph have to be the same accent. The
          // field was the system accent and the glyph `.tint`; once the field
          // became biolume the two read as two different brands.
          .foregroundStyle(AuraDesign.Palette.biolume)
      }
      .frame(
        width: AuraDesign.Measure.identityMark,
        height: AuraDesign.Measure.identityMark)
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: AuraDesign.Spacing.xxs) {
        Text("AURA")
          .font(AuraDesign.Typography.wordmark)
        Text(language == .turkish ? "Yerel sesli asistan" : "Local voice assistant")
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: AuraDesign.Spacing.s)

      HStack(spacing: AuraDesign.Spacing.xs) {
        AuraStatusPill(
          status: model.status,
          title: model.status.title(for: language),
          detail: model.displayStatusDetail,
          inputLevel: model.inputLevel)
        if model.isSpeakingResponse {
          AuraEqualizer()
            .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .bottom)))
        }
      }
      // G2-3: the equalizer's one-shot rise/drop is its own choreography
      // moment, keyed only on isSpeakingResponse — the pill's own three
      // status-keyed animations above are unaffected.
      .animation(
        AuraDesign.Motion.motion(AuraDesign.Motion.snappy), value: model.isSpeakingResponse)

      if model.emergencyStopActive {
        AuraEmergencyBadge(
          title: language == .turkish ? "Acil durdurma etkin" : "Emergency stop active"
        )
        .transition(.scale(scale: 1.3).combined(with: .opacity))
        .animation(
          AuraDesign.Motion.motion(AuraDesign.Motion.emergent),
          value: model.emergencyStopActive)
      }

      Picker(
        "Language",
        selection: Binding(
          get: { model.productUIState.language },
          set: { model.setUILanguage($0) })
      ) {
        Text("EN").tag(AuraUILanguage.english)
        Text("TR").tag(AuraUILanguage.turkish)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: AuraDesign.Measure.languageSwitchWidth)
      .accessibilityLabel(language == .turkish ? "Arayüz dili" : "Interface language")
      .accessibilityIdentifier(AuraAccessibilityID.languageSwitch)

      Button {
        model.beginOnboarding()
      } label: {
        Image(systemName: "wand.and.stars")
          .font(.footnote.weight(.medium))
      }
      .buttonStyle(.bordered)
      .help(copy("onboarding.title"))
      .accessibilityLabel(copy("onboarding.title"))
      .accessibilityHint(language == .turkish ? "Kurulum adımlarını açar" : "Opens guided setup")
      .accessibilityIdentifier(AuraAccessibilityID.onboardingButton)

      Button {
        openSettings()
      } label: {
        Image(systemName: "gearshape")
          .font(.footnote.weight(.medium))
      }
      .buttonStyle(.bordered)
      .help(language == .turkish ? "Ayarlar" : "Settings")
      .accessibilityLabel(language == .turkish ? "Ayarlar" : "Settings")
      .accessibilityHint(
        language == .turkish ? "AURA ayarlarını açar" : "Opens AURA settings")
      .accessibilityIdentifier(AuraAccessibilityID.settingsButton)

      Button {
        isCommandPalettePresented = true
      } label: {
        Image(systemName: "command")
      }
      .keyboardShortcut("k", modifiers: .command)
      .frame(width: 1, height: 1)
      .opacity(0.01)
      .accessibilityHidden(true)
    }
    .accessibilityElement(children: .contain)
  }

  /// Sidebar navigation keeps the product destinations visible without
  /// compressing Turkish labels into a horizontal strip. Each row remains a
  /// real button so keyboard traversal and the existing AX identifier-based
  /// driver address the same stable compatibility anchors.
  var sidebar: some View {
    List(
      selection: Binding<AuraProductTab?>(
        get: { model.productUIState.selectedTab },
        set: { selected in
          if let selected { model.selectTab(selected) }
        })
    ) {
      Section {
        ForEach(AuraProductTab.allCases) { tab in
          Button {
            model.selectTab(tab)
          } label: {
            Label(copy(tab.copyKey), systemImage: tab.symbolName)
              .font(
                AuraDesign.Typography.meta.weight(
                  model.productUIState.selectedTab == tab ? .semibold : .regular))
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
          .tag(tab)
          .accessibilityAddTraits(
            model.productUIState.selectedTab == tab
              ? [.isButton, .isSelected]
              : .isButton)
          .accessibilityLabel(copy(tab.copyKey))
          .accessibilityIdentifier(AuraAccessibilityID.tab(tab.rawValue))
        }
      }
    }
    .listStyle(.sidebar)
    .navigationTitle(language == .turkish ? "Bölümler" : "Sections")
    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(language == .turkish ? "AURA bölümleri" : "AURA sections")
  }

  @ViewBuilder
  var tabContent: some View {
    switch model.productUIState.selectedTab {
    case .conversation: conversationTab
    case .tasks: tasksTab
    case .capabilities: capabilitiesTab
    case .models: modelsTab
    case .privacy: privacyTab
    case .recovery: recoveryTab
    }
  }

  var conversationTab: some View {
    VStack(alignment: .leading, spacing: AuraDesign.Spacing.m) {
      sectionTitle("conversation.title", symbol: "bubble.left.and.bubble.right")
      HStack(alignment: .center, spacing: AuraDesign.Spacing.m) {
        Label(copy("conversation.local"), systemImage: "lock.fill")
          .foregroundStyle(.secondary)
          .accessibilityLabel(
            "\(copy("conversation.local")). \(model.cloudContextStatusLabel)")
        Spacer(minLength: 0)
        // The Orb heads the conversation as its living core (13 §2): one
        // instrument, every layer driven by real signals — status, the live
        // mic level while listening, and the real TTS-speaking signal.
        AuraOrb(
          status: model.status,
          inputLevel: model.inputLevel,
          isSpeakingResponse: model.status == .speaking,
          language: language,
          restrictedReason: model.status == .restricted
            ? model.displayStatusDetail : "")
          .accessibilityIdentifier(AuraAccessibilityID.conversationOrb)
      }
      if model.isVSCodeBridgeAcceptanceEnabled {
        GroupBox(copy("vscode.bridge")) {
          VStack(alignment: .leading, spacing: 8) {
            Text(copy("vscode.probeNote"))
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Text(
              "AURA Keychain: \(model.isVSCodeBridgeProvisioned ? "Provisioned" : "Not provisioned")"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Button {
              model.readVSCodeEditorState()
            } label: {
              Label(copy("a11y.vscodeRead"), systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!model.isVSCodeBridgeProvisioned)
            .accessibilityLabel(copy("a11y.vscodeRead"))
            .accessibilityHint(copy("a11y.vscodeReadHint"))
            if !model.vscodeBridgeRoundTripStatus.isEmpty {
              Text(model.vscodeBridgeRoundTripStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      if let gmail = model.integrationRows.first(where: {
        $0.id == InitialCapabilitySet.mailRead.id
      }), gmail.canConnect {
        GroupBox {
          Button {
            model.connectMailIntegration()
          } label: {
            Label(copy("integrations.connect"), systemImage: "envelope.badge.plus")
          }
          .accessibilityLabel(copy("integrations.connect"))
        }
      }
      conversationTranscript

      // Composer: text and voice are the same action to the user, so they sit
      // on one row rather than stacking a full-width bar under the field.
      // The whole row is one `GlassEffectContainer`. That is not decoration:
      // the container is what lets sibling glass shapes merge and morph, and
      // it is the documented way to avoid paying for several independent
      // glass passes sitting side by side.
      GlassEffectContainer(spacing: AuraDesign.Spacing.s) {
        HStack(spacing: AuraDesign.Spacing.s) {
          HStack(spacing: AuraDesign.Spacing.s) {
            TextField(copy("conversation.input"), text: $model.textInput)
              .textFieldStyle(.plain)
              .font(AuraDesign.Typography.body)
              .onSubmit { model.submitText() }
              .accessibilityLabel(copy("conversation.input"))
              .accessibilityIdentifier(AuraAccessibilityID.composerInput)
            Button {
              model.submitText()
            } label: {
              Image(systemName: "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(
                  model.textInput.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            }
            .buttonStyle(.plain)
            .disabled(model.textInput.isEmpty)
            .accessibilityLabel(copy("conversation.submit"))
            .accessibilityIdentifier(AuraAccessibilityID.composerSubmit)
          }
          .padding(.horizontal, AuraDesign.Spacing.m)
          .padding(.vertical, AuraDesign.Spacing.s)
          .glassEffect(
            .regular.interactive(), in: .rect(cornerRadius: AuraDesign.Radius.bubble))

          Button {
            model.pushToTalk()
          } label: {
            Label(copy("conversation.pushToTalk"), systemImage: "mic.fill")
              .font(AuraDesign.Typography.meta.weight(.semibold))
              .padding(.horizontal, AuraDesign.Spacing.s)
          }
          .buttonStyle(.glassProminent)
          .controlSize(.large)
          .disabled(model.emergencyStopActive)
          .keyboardShortcut(.space, modifiers: [.command, .shift])
          .accessibilityHint(copy("conversation.pushHint"))
          .accessibilityIdentifier(AuraAccessibilityID.composerPushToTalk)
        }
      }

      if let challenge = model.pendingConfirmation {
        // G2-5: fast, sober entrance — no bounce, no staged reveal, so the
        // tinted heading is present at first paint like every other frame of
        // the transition (11-motion-system.md §4's "prominence rule"). Uses
        // `motion.emergent`: the token's own definition (AuraDesign.swift)
        // has named "confirmation cards" as an emergent use case since UI-0,
        // and UI-2.prompt.md's G2-5 procedure says so explicitly — the
        // authoritative pairing, even though 11 §4's choreography table row
        // for this moment says `standard` (stale relative to both).
        AuraConfirmationCard(model: model, challenge: challenge)
          .id(challenge.requestID)
          .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
          .animation(
            AuraDesign.Motion.motion(AuraDesign.Motion.emergent), value: challenge.requestID)
      }
      if !model.lastOperationMessage.isEmpty {
        let message = model.localizedOperationMessage(model.lastOperationMessage)
        Text(message)
          .font(.callout)
          .foregroundStyle(
            model.status == .error
              ? AuraDesign.Palette.critical : AuraDesign.Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("\(copy("a11y.diagnosticPrefix")): \(message)")
      }
      emergencyControls
    }
  }

  /// The transcript scroll (G1-4): honest stick-to-bottom auto-scroll with a
  /// jump-to-latest affordance. Auto-scroll engages only when the user is
  /// already at the bottom; scrolling up pauses it and shows the affordance —
  /// the view never fights the user for the scroll position.
  var conversationTranscript: some View {
    ScrollViewReader { proxy in
      ZStack(alignment: .bottomTrailing) {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: AuraDesign.Spacing.s) {
            // Top anchor for the G1-4 acceptance-harness scaffold below —
            // stable across rebuilds, exactly like the bottom anchor.
            Color.clear
              .frame(height: 1)
              .id(AuraScrollAnchor.top)
            if model.conversationMessages.isEmpty, model.partialTranscript.isEmpty,
              model.status != .thinking
            {
              Text(copy("conversation.empty"))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(model.conversationMessages) { message in
              conversationMessage(message)
            }
            // The in-flight spoken input lives *in* the transcript as a
            // draft bubble (G1-3) — where the eye already is.
            if !model.partialTranscript.isEmpty {
              AuraDraftBubble(language: language, text: model.partialTranscript)
            }
            // Pending assistant turn (G1-5), rendered from the real
            // .thinking status where the answer will land.
            if model.status == .thinking {
              AuraThinkingIndicator(language: language)
                .id(AuraAccessibilityID.conversationThinking)
            }
            Color.clear
              .frame(height: 1)
              .id(AuraScrollAnchor.bottom)
          }
          .padding(.bottom, AuraDesign.Spacing.s)
        }
        .frame(
          minHeight: AuraDesign.Measure.transcriptMinHeight,
          maxHeight: .infinity)
        // The read path the acceptance driver addresses. Without it the only
        // way to reach the transcript is by position, which is what made the
        // G1-4 driver leg fail against the rebuilt hierarchy.
        .accessibilityIdentifier(AuraAccessibilityID.conversationTranscript)
        .background(
          // Ambient canvas (G1-7): the conversation surface sits on the
          // observatory base (palette.void) per the materials ladder; the
          // window chrome around it stays native.
          RoundedRectangle(cornerRadius: AuraDesign.Radius.large, style: .continuous)
            .fill(AuraDesign.Palette.void)
            .overlay(
              RoundedRectangle(cornerRadius: AuraDesign.Radius.large, style: .continuous)
                .stroke(AuraDesign.Palette.hairline, lineWidth: AuraDesign.Measure.hairline)))
        .onScrollGeometryChange(for: Bool.self) { geometry in
          // True when the user's viewport reaches the content bottom (within
          // a small epsilon so sub-pixel rounding never breaks stickiness).
          let bottom = geometry.contentOffset.y + geometry.containerSize.height
          return bottom >= geometry.contentSize.height - AuraScrollAnchor.stickiness
        } action: { _, isAtBottom in
          isStickToBottom = isAtBottom
          if isAtBottom {
            // Re-engaged at the bottom: dismiss the affordance.
            showJumpToLatest = false
          } else {
            showJumpToLatest = true
          }
        }
        .onChange(of: model.conversationMessages.count) { _, _ in
          scrollToLatestIfFollowing(proxy)
        }
        .onChange(of: model.partialTranscript) { _, _ in
          scrollToLatestIfFollowing(proxy)
        }
        .onChange(of: model.status) { _, _ in
          scrollToLatestIfFollowing(proxy)
        }

        if showJumpToLatest {
          Button {
            isStickToBottom = true
            showJumpToLatest = false
            withAnimation(AuraDesign.Motion.motion(AuraDesign.Motion.snappy)) {
              proxy.scrollTo(AuraScrollAnchor.bottom, anchor: .bottom)
            }
          } label: {
            Label(copy("conversation.jumpToLatest"), systemImage: "arrow.down.circle")
              .font(AuraDesign.Typography.meta.weight(.semibold))
              .padding(.horizontal, AuraDesign.Spacing.s)
              .padding(.vertical, AuraDesign.Spacing.xs)
              .glassEffect(.regular, in: .capsule)
          }
          .buttonStyle(.plain)
          .padding(AuraDesign.Spacing.s)
          .accessibilityLabel(copy("conversation.jumpToLatest"))
          .accessibilityIdentifier(AuraAccessibilityID.conversationJumpToLatest)
        }

        if AuraAcceptanceTestHooks.isEnabled {
          // Acceptance-harness-only (G1-4): a real ScrollViewProxy.scrollTo
          // call, so onScrollGeometryChange fires and the jump-to-latest
          // affordance becomes provable by the AX driver's existing `click`
          // command. Never present unless AURA_ACCEPTANCE_TEST_HOOKS=1.
          Button {
            withAnimation(AuraDesign.Motion.motion(AuraDesign.Motion.snappy)) {
              proxy.scrollTo(AuraScrollAnchor.top, anchor: .top)
            }
          } label: {
            Image(systemName: "arrow.up.to.line")
          }
          .buttonStyle(.plain)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(AuraDesign.Spacing.s)
          .accessibilityLabel("Debug: scroll away from bottom")
          .accessibilityIdentifier(AuraAccessibilityID.debugScrollToTop)
        }
      }
      .accessibilityElement(children: .contain)
    }
  }

  /// Follow the stream only while the user is at the bottom; never scroll
  /// while they are reading history. Partial-transcript updates use an
  /// unanimated jump (they arrive rapidly); message arrivals ride `snappy`.
  private func scrollToLatestIfFollowing(_ proxy: ScrollViewProxy) {
    guard isStickToBottom else { return }
    proxy.scrollTo(AuraScrollAnchor.bottom, anchor: .bottom)
  }

  func conversationMessage(_ message: AuraConversationMessage) -> some View {
    let role: String
    switch message.role {
    case .user: role = language == .turkish ? "Siz" : "You"
    case .assistant: role = "AURA"
    case .system: role = language == .turkish ? "Sistem" : "System"
    }
    if message.role == .assistant {
      // Assistant replies carry markdown (G1-2): inline semantics primary,
      // verbatim plain-text fallback on malformed input.
      return AnyView(
        AuraMarkdownMessageBubble(
          language: language,
          roleLabel: role,
          text: message.text,
          isDegraded: message.isDegraded,
          sourceSummary: message.sourceSummary,
          traceSummary: message.traceSummary))
    }
    return AnyView(
      AuraMessageBubble(
        language: language,
        roleLabel: role,
        text: message.text,
        isUser: message.role == .user,
        isDegraded: message.isDegraded,
        sourceSummary: message.sourceSummary,
        traceSummary: message.traceSummary))
  }

}

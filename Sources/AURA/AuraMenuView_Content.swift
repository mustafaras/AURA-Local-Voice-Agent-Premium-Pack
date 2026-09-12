import AuraAgent
import AuraCore
import AuraIntent
import SwiftUI

/// Scroll anchor and threshold for the transcript's honest auto-scroll
/// (G1-4). The anchor id is stable across rebuilds; `stickiness` is the
/// bottom-proximity epsilon (pt) inside which "at the bottom" is true.
private enum AuraScrollAnchor {
  static let bottom = "aura.scroll.bottom"
  static let stickiness: CGFloat = 24
}

extension AuraMenuView {

  var body: some View {
    VStack(alignment: .leading, spacing: AuraDesign.Spacing.m) {
      header
      tabPicker
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
    // L0 — the observatory canvas. The owned neutral is the point of the
    // palette; the window kept `windowBackgroundColor` and the identity never
    // reached the surface behind everything.
    .background(AuraDesign.Materials.base)
    .frame(minWidth: 680, minHeight: 720)
    .onAppear {
      model.refreshProductSnapshots()
      // A macOS privacy decision made outside this window (a TCC prompt in
      // another app, a change in System Settings) leaves the snapshot stale
      // until something re-reads it. Re-reading on every appear keeps the
      // permission indicators and the row buttons honest without a manual
      // refresh click.
      model.refreshPermissions()
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

      AuraStatusPill(
        status: model.status,
        title: model.status.title(for: language),
        detail: model.displayStatusDetail)

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
    }
    .accessibilityElement(children: .contain)
  }

  /// Six destinations in a segmented control leave each label a few
  /// characters wide and unreadable in Turkish, where the words are longer.
  /// Discrete pills give every section its icon plus its full name, and make
  /// the selected one unambiguous.
  var tabPicker: some View {
    GlassEffectContainer(spacing: AuraDesign.Spacing.xs) {
      HStack(spacing: AuraDesign.Spacing.xs) {
        ForEach(AuraProductTab.allCases) { tab in
          tabButton(tab)
        }
        Spacer(minLength: 0)
      }
      .padding(AuraDesign.Spacing.xs)
      .glassEffect(.regular, in: .rect(cornerRadius: AuraDesign.Radius.medium))
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(language == .turkish ? "AURA bölümleri" : "AURA sections")
  }

  private func tabButton(_ tab: AuraProductTab) -> some View {
    let isSelected = model.productUIState.selectedTab == tab
    return Button {
      model.selectTab(tab)
    } label: {
      HStack(spacing: AuraDesign.Spacing.xs) {
        Image(systemName: tab.symbolName)
          .font(.caption2.weight(.medium))
        Text(copy(tab.copyKey))
          .font(AuraDesign.Typography.meta.weight(isSelected ? .semibold : .regular))
          .lineLimit(1)
      }
      .padding(.horizontal, AuraDesign.Spacing.s)
      .padding(.vertical, AuraDesign.Spacing.xs + 1)
      .background(
        RoundedRectangle(cornerRadius: AuraDesign.Radius.small, style: .continuous)
          .fill(
            isSelected
              ? AuraDesign.Palette.biolume.opacity(0.18) : Color.clear)
      )
      .foregroundStyle(
        isSelected ? AuraDesign.Palette.biolume : AuraDesign.Palette.textSecondary)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    // Selection is announced through the trait rather than only by tint, so it
    // is conveyed without relying on colour.
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    // The pill's label is an icon plus text inside a `.plain` button, which
    // SwiftUI did not surface as an accessible name: every tab read as a bare
    // "button" to VoiceOver and to the acceptance driver alike.
    .accessibilityLabel(copy(tab.copyKey))
    .accessibilityIdentifier(AuraAccessibilityID.tab(tab.rawValue))
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
        AuraConfirmationCard(model: model, challenge: challenge)
          .id(challenge.requestID)
      }
      if let plan = model.lastPlanSummary, !plan.isEmpty {
        GroupBox(copy("plan.title")) {
          Text(plan)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
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

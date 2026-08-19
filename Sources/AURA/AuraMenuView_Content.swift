import AuraAgent
import AuraCore
import AuraIntent
import SwiftUI

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
    .background(Color(nsColor: .windowBackgroundColor))
    .frame(minWidth: 680, minHeight: 720)
    .onAppear { model.refreshProductSnapshots() }
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
          .fill(Color.accentColor.opacity(0.14))
        Image(systemName: model.status.symbolName)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.tint)
      }
      .frame(width: 34, height: 34)
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
        title: model.status.title,
        detail: model.statusDetail)

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
      .frame(width: 84)
      .accessibilityLabel(language == .turkish ? "Arayüz dili" : "Interface language")

      Button {
        model.beginOnboarding()
      } label: {
        Image(systemName: "wand.and.stars")
          .font(.system(size: 13, weight: .medium))
      }
      .buttonStyle(.bordered)
      .help(copy("onboarding.title"))
      .accessibilityLabel(copy("onboarding.title"))
      .accessibilityHint(language == .turkish ? "Kurulum adımlarını açar" : "Opens guided setup")
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
          .font(.system(size: 11, weight: .medium))
        Text(copy(tab.copyKey))
          .font(AuraDesign.Typography.meta.weight(isSelected ? .semibold : .regular))
          .lineLimit(1)
      }
      .padding(.horizontal, AuraDesign.Spacing.s)
      .padding(.vertical, AuraDesign.Spacing.xs + 1)
      .background(
        RoundedRectangle(cornerRadius: AuraDesign.Radius.small, style: .continuous)
          .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
      )
      .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    // Selection is announced through the trait rather than only by tint, so it
    // is conveyed without relying on colour.
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("conversation.title", symbol: "bubble.left.and.bubble.right")
      Label(copy("conversation.local"), systemImage: "lock.fill")
        .foregroundStyle(.secondary)
        .accessibilityLabel("\(copy("conversation.local")). \(copy("conversation.cloudDisabled"))")
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
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if model.conversationMessages.isEmpty {
            Text(copy("conversation.empty"))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          ForEach(model.conversationMessages) { message in
            conversationMessage(message)
          }
          if !model.partialTranscript.isEmpty {
            GroupBox(copy("conversation.partial")) {
              Text(model.partialTranscript)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(copy("conversation.partial")): \(model.partialTranscript)")
          }
        }
      }
      .frame(minHeight: 180, maxHeight: .infinity)
      .accessibilityElement(children: .contain)

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
            Button {
              model.submitText()
            } label: {
              Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(
                  model.textInput.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            }
            .buttonStyle(.plain)
            .disabled(model.textInput.isEmpty)
            .accessibilityLabel(copy("conversation.submit"))
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
        }
      }

      if let challenge = model.pendingConfirmation {
        AuraConfirmationCard(model: model, challenge: challenge)
          .id(challenge.requestID)
      }
      if let plan = model.lastPlanSummary, !plan.isEmpty {
        GroupBox("Plan / Verification") {
          Text(plan)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
      }
      if !model.lastOperationMessage.isEmpty {
        Text(model.lastOperationMessage)
          .font(.callout)
          .foregroundStyle(model.status == .error ? .red : .secondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Diagnostic: \(model.lastOperationMessage)")
      }
      emergencyControls
    }
  }

  func conversationMessage(_ message: AuraConversationMessage) -> some View {
    let role: String
    switch message.role {
    case .user: role = language == .turkish ? "Siz" : "You"
    case .assistant: role = "AURA"
    case .system: role = language == .turkish ? "Sistem" : "System"
    }
    return AuraMessageBubble(
      roleLabel: role,
      text: message.text,
      isUser: message.role == .user,
      isDegraded: message.isDegraded,
      sourceSummary: message.sourceSummary,
      traceSummary: message.traceSummary)
  }

}

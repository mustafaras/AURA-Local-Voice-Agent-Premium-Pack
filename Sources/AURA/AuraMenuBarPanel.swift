import SwiftUI

/// The menu bar surface.
///
/// Intentionally a summary, not a second copy of the app. The previous build
/// rendered the entire `AuraMenuView` here *and* in the main window, so the
/// same conversation, the same tabs, and the same runtime list existed twice
/// with independent scroll state — which is what read as "there are two AURA
/// interfaces". A menu bar item's job is to answer "is it healthy, and can I
/// talk to it right now" at a glance, then get out of the way.
struct AuraMenuBarPanel: View {
  @ObservedObject var model: AuraAppModel
  let mainWindowID: String

  @Environment(\.openWindow) private var openWindow
  private var language: AuraUILanguage { model.productUIState.language }

  var body: some View {
    VStack(alignment: .leading, spacing: AuraDesign.Spacing.m) {
      AuraStatusPill(
        status: model.status,
        title: model.status.title(for: language),
        detail: model.displayStatusDetail)

      GlassEffectContainer(spacing: AuraDesign.Spacing.s) {
        VStack(spacing: AuraDesign.Spacing.s) {
          Button {
            model.pushToTalk()
          } label: {
            Label(copy("conversation.pushToTalk"), systemImage: "mic.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.glassProminent)
          .disabled(model.emergencyStopActive)
          .accessibilityHint(copy("conversation.pushHint"))

          Button {
            openWindow(id: mainWindowID)
          } label: {
            Label(openWindowTitle, systemImage: "macwindow")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.glass)
        }
      }

      if model.emergencyStopActive {
        Label(emergencyTitle, systemImage: "hand.raised.fill")
          .font(AuraDesign.Typography.meta)
          .foregroundStyle(.orange)
      }

      Divider()

      Button(quitTitle) { NSApplication.shared.terminate(nil) }
        .buttonStyle(.plain)
        .font(AuraDesign.Typography.meta)
        .foregroundStyle(.secondary)
    }
    .padding(AuraDesign.Spacing.l)
    .frame(width: 280)
    .accessibilityElement(children: .contain)
  }

  private var openWindowTitle: String {
    language == .turkish ? "AURA'yı aç" : "Open AURA"
  }

  private var emergencyTitle: String {
    language == .turkish ? "Acil durdurma etkin" : "Emergency stop active"
  }

  private var quitTitle: String {
    language == .turkish ? "AURA'dan çık" : "Quit AURA"
  }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }
}

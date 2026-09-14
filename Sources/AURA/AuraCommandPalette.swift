import SwiftUI

enum AuraCommandPaletteID {
  static let panel = "aura.commandPalette"
  static let cancel = "aura.commandPalette.cancel"
  static let confirmationCard = "aura.confirmation.card"
  static func entry(_ rawValue: String) -> String {
    "aura.commandPalette.entry.\(rawValue)"
  }
}

struct AuraCommandPaletteEntry: Identifiable {
  let id: String
  let title: String
  let symbol: String
  let requiresConfirmation: Bool
  let action: () -> Void
}

/// Static, keyboard-first command table. It has no fuzzy search, async work,
/// or alternate policy path; confirmed actions are handed back to the owner.
struct AuraCommandPalette: View {
  let title: String
  let cancelLabel: String
  let entries: [AuraCommandPaletteEntry]
  let onDismiss: () -> Void
  let onRequestDestructive: (AuraCommandPaletteEntry) -> Void

  var body: some View {
    GlassEffectContainer(spacing: AuraDesign.Spacing.s) {
      VStack(alignment: .leading, spacing: AuraDesign.Spacing.s) {
        HStack {
          Label(title, systemImage: "command")
            .font(AuraDesign.Typography.sectionTitle)
          Spacer()
          Button(cancelLabel, role: .cancel, action: onDismiss)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier(AuraCommandPaletteID.cancel)
        }
        ForEach(entries) { entry in
          Button {
            if entry.requiresConfirmation {
              onRequestDestructive(entry)
            } else {
              entry.action()
              onDismiss()
            }
          } label: {
            Label(entry.title, systemImage: entry.symbol)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(AuraCommandPaletteID.entry(entry.id))
        }
      }
      .padding(AuraDesign.Spacing.l)
      .frame(width: 360)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(AuraCommandPaletteID.panel)
    .onExitCommand(perform: onDismiss)
  }
}

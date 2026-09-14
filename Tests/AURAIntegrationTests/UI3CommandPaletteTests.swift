import Foundation
import Testing

@testable import AURA

/// UI-3 G3-5 pins the palette as a static dispatch table with stable IDs and
/// an explicit confirmation hand-off for the one mutating command.
struct UI3CommandPaletteTests {
  @Test("command palette table is static, addressable, and tab-complete")
  @MainActor
  func commandTablePreservesTabIdentifiers() {
    let model = AuraAppModel(startRuntime: false)
    let menu = AuraMenuView(model: model)
    let entries = menu.commandPaletteEntries
    #expect(entries.count == AuraProductTab.allCases.count + 6)
    for tab in AuraProductTab.allCases {
      #expect(entries.contains(where: { $0.id == "tab.\(tab.rawValue)" }))
      #expect(AuraCommandPaletteID.entry("tab.\(tab.rawValue)") == "aura.commandPalette.entry.tab.\(tab.rawValue)")
    }
    #expect(entries.contains(where: { $0.id == "pushToTalk" }))
    #expect(entries.contains(where: { $0.id == "emergencyStop" }))
    #expect(entries.contains(where: { $0.id == "copyTranscript" }))
    #expect(entries.contains(where: { $0.id == "clearComposer" }))
  }

  @Test("mutating palette entry is marked for the existing confirmation path")
  @MainActor
  func destructiveEntryRequiresConfirmation() {
    let model = AuraAppModel(startRuntime: false)
    let menu = AuraMenuView(model: model)
    let entries = menu.commandPaletteEntries
    let launchAtLogin = entries.first(where: { $0.id == "launchAtLogin" })
    #expect(launchAtLogin?.requiresConfirmation == true)
    #expect(entries.first(where: { $0.id == "emergencyStop" })?.requiresConfirmation == false)
  }

  @Test("palette view constructs with stable panel and cancel IDs")
  @MainActor
  func paletteViewConstructs() {
    let model = AuraAppModel(startRuntime: false)
    let menu = AuraMenuView(model: model)
    let palette = AuraCommandPalette(
      title: "Product UI",
      cancelLabel: "Cancel",
      entries: menu.commandPaletteEntries,
      onDismiss: {},
      onRequestDestructive: { _ in })
    _ = palette.body
    #expect(AuraCommandPaletteID.panel == "aura.commandPalette")
    #expect(AuraCommandPaletteID.cancel == "aura.commandPalette.cancel")
  }

  @Test("palette dismissal is Escape-driven and does not present a second card")
  func paletteUsesExistingDismissalAndCardSurface() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let palette = try String(
      contentsOf: root.appendingPathComponent("Sources/AURA/AuraCommandPalette.swift"),
      encoding: .utf8)
    let content = try String(
      contentsOf: root.appendingPathComponent("Sources/AURA/AuraMenuView_Content.swift"),
      encoding: .utf8)
    #expect(palette.contains("onExitCommand(perform: onDismiss)"))
    #expect(palette.contains("keyboardShortcut(.cancelAction)"))
    #expect(!palette.contains("AuraConfirmationCard("))
    #expect(content.contains("onRequestDestructive"))
  }
}

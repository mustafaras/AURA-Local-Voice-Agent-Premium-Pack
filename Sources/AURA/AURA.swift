import SwiftUI

@main
struct AURAApp: App {
  @StateObject private var model = AuraAppModel()

  /// Identifies the one and only main window, so the menu bar item can raise
  /// the existing window instead of spawning another copy.
  static let mainWindowID = "aura.main"

  var body: some Scene {
    // `Window`, not `WindowGroup`. A group lets the user open unlimited
    // duplicate copies of the whole assistant (⌘N), which is half of what
    // produced "there are two AURA interfaces". An assistant has one
    // conversation and one runtime, so it gets exactly one window.
    Window("AURA", id: Self.mainWindowID) {
      AuraMenuView(model: model)
        .onDisappear {
          model.dismissPendingConfirmationForWindowClose()
        }
    }
    .defaultSize(width: 460, height: 760)
    .windowResizability(.contentMinSize)

    // The menu bar surface is deliberately *not* the same view. Rendering the
    // full interface in both places was the other half of the duplication:
    // two complete, independently scrolling copies of the same state. This is
    // a compact status readout plus the few actions worth reaching without
    // switching windows.
    MenuBarExtra {
      AuraMenuBarPanel(model: model, mainWindowID: Self.mainWindowID)
    } label: {
      Label("AURA — \(model.status.title)", systemImage: model.status.symbolName)
        .accessibilityLabel("AURA status: \(model.status.title)")
    }
    .menuBarExtraStyle(.window)

    Settings {
      AuraSettingsView(model: model)
    }
  }
}

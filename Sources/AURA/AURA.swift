import SwiftUI

@main
struct AURAApp: App {
  @StateObject private var model = AuraAppModel()

  var body: some Scene {
    WindowGroup("AURA") {
      AuraMenuView(model: model)
    }
    .defaultSize(width: 430, height: 720)

    MenuBarExtra {
      AuraMenuView(model: model)
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

import Foundation
import Testing

@testable import AURA

/// UI-3 G3-1 pins the navigation contract before any visual polish is
/// accepted: persisted tab raw values and AX identifiers are compatibility
/// anchors, while the visible navigation surface is now a sidebar.
struct UI3InformationArchitectureTests {
  @Test("sidebar preserves every product-tab raw value and AX identifier")
  func sidebarPreservesTabContract() {
    #expect(
      AuraProductTab.allCases.map(\.rawValue)
        == ["conversation", "tasks", "capabilities", "models", "privacy", "recovery"])
    let identifiers = AuraProductTab.allCases.map { AuraAccessibilityID.tab($0.rawValue) }
    #expect(Set(identifiers).count == AuraProductTab.allCases.count)
    #expect(identifiers == AuraProductTab.allCases.map { "aura.tab.\($0.rawValue)" })
  }

  @Test("sidebar is the only product navigation surface and keeps reducer selection")
  func sidebarSourceContract() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/AURA/AuraMenuView_Content.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source.contains("NavigationSplitView"))
    #expect(source.contains(".listStyle(.sidebar)"))
    #expect(source.contains("model.selectTab(tab)"))
    #expect(source.contains("AuraAccessibilityID.tab(tab.rawValue)"))
    #expect(!source.contains("tabPicker"))
  }

  @Test("sidebar and every selected tab content construct")
  @MainActor
  func sidebarViewConstruction() {
    let model = AuraAppModel(startRuntime: false)
    let menu = AuraMenuView(model: model)
    _ = menu.sidebar
    for tab in AuraProductTab.allCases {
      model.productUIState.selectedTab = tab
      _ = menu.body
      _ = menu.tabContent
    }
  }
}

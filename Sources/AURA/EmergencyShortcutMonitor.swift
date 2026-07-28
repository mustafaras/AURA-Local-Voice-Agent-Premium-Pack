import AppKit

@MainActor
final class EmergencyShortcutMonitor {
  private var globalMonitor: Any?
  private var localMonitor: Any?

  func start(handler: @escaping @MainActor () -> Void) {
    guard globalMonitor == nil, localMonitor == nil else { return }

    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
      guard Self.isEmergencyShortcut(event) else { return }
      Task { @MainActor in handler() }
    }
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      guard Self.isEmergencyShortcut(event) else { return event }
      handler()
      return nil
    }
  }

  func stop() {
    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
      self.globalMonitor = nil
    }
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
      self.localMonitor = nil
    }
  }

  nonisolated private static func isEmergencyShortcut(_ event: NSEvent) -> Bool {
    let required: NSEvent.ModifierFlags = [.command, .shift]
    return event.keyCode == 53
      && event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(required)
  }
}

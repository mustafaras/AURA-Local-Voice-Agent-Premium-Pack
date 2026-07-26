import AppKit
@preconcurrency import ApplicationServices
import AuraCore
import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Records whether an executed step actually resolved through Accessibility
/// or fell back to a raw coordinate — used for the "prefer accessibility
/// over coordinates" audit signal, independent of whether execution
/// succeeded.
public struct UIActionExecutionResult: Sendable, Equatable {
  public let usedAccessibilityAnchor: Bool

  public init(usedAccessibilityAnchor: Bool) {
    self.usedAccessibilityAnchor = usedAccessibilityAnchor
  }
}

/// Abstracts generated pointer/keyboard input so `ComputerUseControlLoop`'s
/// own bounds/policy/emergency-stop logic is testable with a deterministic
/// fake, independent of live Accessibility/CGEvent state — mirroring the
/// `ScreenWindowSource`/`TextRecognizing` precedent from `AuraScreen`.
public protocol UIActionExecuting: Sendable {
  /// Execute one action. `windowFrame*` are the approved window's frame in
  /// the display's logical point coordinate system (matching
  /// `ScreenWindowDescriptor`), used only to translate an anchor's
  /// normalized coordinate fallback into a real point — never to bypass the
  /// anchor's own bounds.
  func execute(
    _ kind: ComputerUseActionKind,
    anchor: UIAnchor,
    applicationBundleIdentifier: String,
    windowFrameX: Double,
    windowFrameY: Double,
    windowFrameWidth: Double,
    windowFrameHeight: Double
  ) async throws(AuraError) -> UIActionExecutionResult
}

/// Production executor: Accessibility actions (`AXUIElementPerformAction`,
/// `AXUIElementSetAttributeValue`) preferred whenever an anchor's
/// role/title/identifier resolves a real element; `CGEvent` pointer/keyboard
/// synthesis is the fallback for coordinate-only anchors, key presses (which
/// have no element-scoped equivalent), and timed waits.
///
/// Every API used here was verified against the real SDK headers with
/// `swiftc -typecheck` probe compiles before being written (matching the
/// Phase 17 `AuraScreen` precedent) — `AXUIElementPerformAction`,
/// `AXUIElementSetAttributeValue`, `CGEvent(mouseEventSource:...)`,
/// `CGEvent(keyboardEventSource:...)`, `keyboardSetUnicodeString`,
/// `CGEvent(scrollWheelEvent2Source:...)`, `CGWarpMouseCursorPosition`, and
/// the `Carbon.HIToolbox` named virtual-keycode constants (`kVK_Return` etc.)
/// all compiled clean against the installed macOS SDK.
public actor AXCGEventActionExecutor: UIActionExecuting {
  /// Bound on Accessibility tree traversal while resolving an anchor —
  /// matches this project's "bounded, never unbounded" posture for any
  /// search over live system state.
  private let maxTraversedElements: Int

  /// Checked unconditionally at the top of every `execute` call — defense in
  /// depth so "emergency stop disables all generated input" is a guarantee
  /// of the executor itself, not merely a discipline `ComputerUseControlLoop`
  /// happens to follow. A future caller that invokes this executor directly
  /// (bypassing the control loop's own checks) still cannot generate input
  /// while stopped. Required, not optional, so no production wiring can
  /// silently omit it.
  private let emergencyStop: EmergencyStopController

  public init(emergencyStop: EmergencyStopController, maxTraversedElements: Int = 500) {
    self.emergencyStop = emergencyStop
    self.maxTraversedElements = maxTraversedElements
  }

  public func execute(
    _ kind: ComputerUseActionKind,
    anchor: UIAnchor,
    applicationBundleIdentifier: String,
    windowFrameX: Double,
    windowFrameY: Double,
    windowFrameWidth: Double,
    windowFrameHeight: Double
  ) async throws(AuraError) -> UIActionExecutionResult {
    guard await !emergencyStop.isActive else {
      throw AuraError.computerUseError("Emergency stop is active; refusing to generate input")
    }

    // `.wait` needs no permission, element, or coordinate at all.
    if case .wait(let seconds) = kind {
      try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
      return UIActionExecutionResult(usedAccessibilityAnchor: false)
    }

    let trusted = await MainActor.run {
      AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
    }
    guard trusted else {
      throw AuraError.computerUseError("Accessibility is not trusted")
    }

    // `.keyPress` targets whatever currently holds keyboard focus — there is
    // no element-scoped equivalent, so it never consults the anchor.
    if case .keyPress(let key, let modifiers) = kind {
      try postKeyPress(key: key, modifiers: modifiers)
      return UIActionExecutionResult(usedAccessibilityAnchor: false)
    }

    let resolvedElement = try resolveAccessibilityElement(
      anchor: anchor, applicationBundleIdentifier: applicationBundleIdentifier)

    switch kind {
    case .click, .doubleClick, .rightClick:
      if let resolvedElement {
        try pressViaAccessibility(resolvedElement)
        return UIActionExecutionResult(usedAccessibilityAnchor: true)
      }
      let point = try globalPoint(
        anchor: anchor, windowFrameX: windowFrameX, windowFrameY: windowFrameY,
        windowFrameWidth: windowFrameWidth, windowFrameHeight: windowFrameHeight)
      try postMouseClick(kind: kind, at: point)
      return UIActionExecutionResult(usedAccessibilityAnchor: false)

    case .typeText(let text):
      if let resolvedElement {
        try setValueViaAccessibility(resolvedElement, text: text)
        return UIActionExecutionResult(usedAccessibilityAnchor: true)
      }
      let point = try globalPoint(
        anchor: anchor, windowFrameX: windowFrameX, windowFrameY: windowFrameY,
        windowFrameWidth: windowFrameWidth, windowFrameHeight: windowFrameHeight)
      try postMouseClick(kind: .click, at: point)
      try postUnicodeText(text)
      return UIActionExecutionResult(usedAccessibilityAnchor: false)

    case .scroll(let deltaX, let deltaY):
      // Scrolling is inherently positional; there is no Accessibility
      // "perform scroll" action, so this always requires a coordinate.
      let point = try globalPoint(
        anchor: anchor, windowFrameX: windowFrameX, windowFrameY: windowFrameY,
        windowFrameWidth: windowFrameWidth, windowFrameHeight: windowFrameHeight)
      try postScroll(deltaX: deltaX, deltaY: deltaY, at: point)
      return UIActionExecutionResult(usedAccessibilityAnchor: false)

    case .keyPress, .wait:
      throw AuraError.computerUseError("unreachable: handled above")
    }
  }

  // MARK: - Accessibility resolution

  private func resolveAccessibilityElement(
    anchor: UIAnchor, applicationBundleIdentifier: String
  ) throws(AuraError) -> AXUIElement? {
    guard anchor.hasAccessibilityHint else { return nil }

    let apps = NSWorkspace.shared.runningApplications
    guard let app = apps.first(where: { $0.bundleIdentifier == applicationBundleIdentifier })
    else {
      throw AuraError.computerUseError(
        "Application not running: \(applicationBundleIdentifier)")
    }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var queue: [AXUIElement] = [axApp]
    var visited = 0

    while !queue.isEmpty, visited < maxTraversedElements {
      let element = queue.removeFirst()
      visited += 1
      if matches(element, anchor: anchor) {
        return element
      }
      var childrenRef: CFTypeRef?
      let err = AXUIElementCopyAttributeValue(
        element, kAXChildrenAttribute as CFString, &childrenRef)
      if err == .success, let children = childrenRef as? [AXUIElement] {
        queue.append(contentsOf: children)
      }
    }
    return nil
  }

  private func matches(_ element: AXUIElement, anchor: UIAnchor) -> Bool {
    if let role = anchor.accessibilityRole {
      guard stringAttribute(element, kAXRoleAttribute as String) == role else { return false }
    }
    if let title = anchor.accessibilityTitle {
      guard stringAttribute(element, kAXTitleAttribute as String) == title else { return false }
    }
    if let identifier = anchor.accessibilityIdentifier {
      guard stringAttribute(element, kAXIdentifierAttribute as String) == identifier else {
        return false
      }
    }
    return true
  }

  private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard err == .success, let value else { return nil }
    return value as? String
  }

  private func pressViaAccessibility(_ element: AXUIElement) throws(AuraError) {
    let err = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard err == .success else {
      throw AuraError.computerUseError("AXUIElementPerformAction failed: \(err.rawValue)")
    }
  }

  private func setValueViaAccessibility(_ element: AXUIElement, text: String) throws(AuraError) {
    let err = AXUIElementSetAttributeValue(
      element, kAXValueAttribute as CFString, text as CFString)
    guard err == .success else {
      throw AuraError.computerUseError("AXUIElementSetAttributeValue failed: \(err.rawValue)")
    }
  }

  // MARK: - Coordinate fallback

  private func globalPoint(
    anchor: UIAnchor,
    windowFrameX: Double,
    windowFrameY: Double,
    windowFrameWidth: Double,
    windowFrameHeight: Double
  ) throws(AuraError) -> CGPoint {
    guard anchor.hasCoordinateFallback, anchor.coordinateFallbackInBounds,
      let nx = anchor.fallbackNormalizedX, let ny = anchor.fallbackNormalizedY
    else {
      throw AuraError.computerUseError(
        "No accessibility element resolved and no valid coordinate fallback available")
    }
    let x = windowFrameX + nx * windowFrameWidth
    let y = windowFrameY + ny * windowFrameHeight
    return CGPoint(x: x, y: y)
  }

  // MARK: - CGEvent synthesis

  private func postMouseClick(kind: ComputerUseActionKind, at point: CGPoint) throws(AuraError) {
    let source = CGEventSource(stateID: .hidSystemState)
    let isRight: Bool
    if case .rightClick = kind { isRight = true } else { isRight = false }
    let button: CGMouseButton = isRight ? .right : .left
    let downType: CGEventType = isRight ? .rightMouseDown : .leftMouseDown
    let upType: CGEventType = isRight ? .rightMouseUp : .leftMouseUp
    guard
      let down = CGEvent(
        mouseEventSource: source, mouseType: downType, mouseCursorPosition: point,
        mouseButton: button),
      let up = CGEvent(
        mouseEventSource: source, mouseType: upType, mouseCursorPosition: point,
        mouseButton: button)
    else {
      throw AuraError.computerUseError("Failed to create synthetic mouse event")
    }
    if case .doubleClick = kind {
      down.setIntegerValueField(.mouseEventClickState, value: 2)
      up.setIntegerValueField(.mouseEventClickState, value: 2)
    }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }

  /// Standard non-printable virtual keycodes this phase supports for
  /// `.keyPress`, sourced from the real `Carbon.HIToolbox` header constants
  /// (`kVK_*`) rather than hardcoded values. Arbitrary printable characters
  /// (including non-ASCII, e.g. Turkish letters) are typed via the Unicode
  /// string path instead of a virtual keycode — see `postKeyPress`.
  private static let namedVirtualKeyCodes: [String: Int] = [
    "return": kVK_Return,
    "enter": kVK_Return,
    "tab": kVK_Tab,
    "space": kVK_Space,
    "delete": kVK_Delete,
    "backspace": kVK_Delete,
    "escape": kVK_Escape,
    "up": kVK_UpArrow,
    "down": kVK_DownArrow,
    "left": kVK_LeftArrow,
    "right": kVK_RightArrow,
  ]

  private func postKeyPress(key: String, modifiers: [String]) throws(AuraError) {
    let source = CGEventSource(stateID: .hidSystemState)
    if let code = Self.namedVirtualKeyCodes[key.lowercased()] {
      guard
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: true),
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: false)
      else {
        throw AuraError.computerUseError("Failed to create synthetic key event")
      }
      let flags = Self.modifierFlags(for: modifiers)
      down.flags = flags
      up.flags = flags
      down.post(tap: .cghidEventTap)
      up.post(tap: .cghidEventTap)
      return
    }
    guard modifiers.isEmpty, key.count == 1 else {
      throw AuraError.computerUseError(
        "Unsupported key press '\(key)' with modifiers \(modifiers) — only the fixed named-key set supports modifiers"
      )
    }
    try postUnicodeText(key)
  }

  private static func modifierFlags(for modifiers: [String]) -> CGEventFlags {
    var flags: CGEventFlags = []
    for modifier in modifiers {
      switch modifier.lowercased() {
      case "command", "cmd": flags.insert(.maskCommand)
      case "shift": flags.insert(.maskShift)
      case "option", "alt": flags.insert(.maskAlternate)
      case "control", "ctrl": flags.insert(.maskControl)
      default: break
      }
    }
    return flags
  }

  private func postUnicodeText(_ text: String) throws(AuraError) {
    let source = CGEventSource(stateID: .hidSystemState)
    guard
      let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
      let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
    else {
      throw AuraError.computerUseError("Failed to create synthetic keyboard event")
    }
    let characters: [UniChar] = Array(text.utf16)
    down.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: characters)
    up.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: characters)
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }

  private func postScroll(deltaX: Double, deltaY: Double, at point: CGPoint) throws(AuraError) {
    CGWarpMouseCursorPosition(point)
    let source = CGEventSource(stateID: .hidSystemState)
    guard
      let scroll = CGEvent(
        scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
        wheel1: Int32(deltaY), wheel2: Int32(deltaX), wheel3: 0)
    else {
      throw AuraError.computerUseError("Failed to create synthetic scroll event")
    }
    scroll.post(tap: .cghidEventTap)
  }
}

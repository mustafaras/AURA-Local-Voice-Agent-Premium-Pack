import AuraCore
import Foundation

/// A shared, actor-isolated kill switch that immediately disables all
/// generated input once triggered from any channel, per the normative rule
/// "Maintain an emergency stop that disables generated input immediately."
///
/// All three trigger channels (UI, voice, keyboard) call the same
/// `trigger(source:reason:)` method and are equally authoritative — none is
/// privileged, none has extra latency. Once triggered, the stop stays active
/// until an explicit `reset(actor:)` call; it never clears itself
/// automatically, so a triggered stop cannot be silently bypassed by a loop
/// simply continuing on its next iteration.
public actor EmergencyStopController {
  private var active: Bool = false
  private var lastTriggerSource: EmergencyStopSource?
  private var lastTriggerReason: String?
  private let eventBus: AuraEventBus

  public init(eventBus: AuraEventBus = .shared) {
    self.eventBus = eventBus
  }

  /// Whether emergency stop is currently active. Checked by
  /// `ComputerUseControlLoop` before every phase transition.
  public var isActive: Bool {
    active
  }

  /// The channel and reason of the most recent trigger, if any — for
  /// diagnostics and UI status display.
  public var lastTrigger: (source: EmergencyStopSource, reason: String?)? {
    guard let lastTriggerSource else { return nil }
    return (lastTriggerSource, lastTriggerReason)
  }

  /// Trigger emergency stop from the given channel. Idempotent — triggering
  /// an already-active stop still records the new source/reason and emits an
  /// audit event, but does not toggle anything off.
  public func trigger(source: EmergencyStopSource, reason: String = "") async {
    active = true
    lastTriggerSource = source
    lastTriggerReason = reason
    let payload = EmergencyStopTriggeredEvent(source: source, reason: reason)
    let envelope = EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .computerUse,
      sensitivity: .internalLevel, payload: payload)
    await eventBus.emit(envelope)
  }

  /// Explicitly re-arm generated input. Never called automatically by the
  /// control loop itself — only an external caller (UI/voice/keyboard
  /// handler acting on user intent) may reset the stop.
  public func reset(actor: ActorID) async {
    active = false
    lastTriggerSource = nil
    lastTriggerReason = nil
    let payload = EmergencyStopResetEvent(actor: actor)
    let envelope = EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: actor,
      sensitivity: .internalLevel, payload: payload)
    await eventBus.emit(envelope)
  }
}

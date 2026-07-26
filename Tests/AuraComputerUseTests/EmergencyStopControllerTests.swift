import AuraComputerUse
import AuraCore
import Foundation
import Testing

private func makeBus() -> (AuraEventBus, Capture) {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraComputerUseTests", category: "stop"))
  return (bus, Capture())
}

actor Capture {
  var triggered: [EmergencyStopTriggeredEvent] = []
  var resets: [EmergencyStopResetEvent] = []

  func recordTriggered(_ event: EmergencyStopTriggeredEvent) { triggered.append(event) }
  func recordReset(_ event: EmergencyStopResetEvent) { resets.append(event) }
}

@Test
func emergencyStopStartsInactive() async {
  let controller = EmergencyStopController(eventBus: AuraEventBus.shared)
  #expect(await controller.isActive == false)
}

@Test("Emergency stop triggers from all three channels")
func emergencyStopTriggersFromEveryChannel() async {
  for source in EmergencyStopSource.allCases {
    let controller = EmergencyStopController(eventBus: AuraEventBus.shared)
    await controller.trigger(source: source, reason: "test")
    #expect(await controller.isActive == true)
    let last = await controller.lastTrigger
    #expect(last?.source == source)
  }
}

@Test
func emergencyStopStaysActiveUntilExplicitReset() async {
  let controller = EmergencyStopController(eventBus: AuraEventBus.shared)
  await controller.trigger(source: .voice, reason: "stop")
  #expect(await controller.isActive == true)
  // Triggering again or merely reading state never clears it.
  #expect(await controller.isActive == true)
  await controller.reset(actor: .user)
  #expect(await controller.isActive == false)
}

@Test
func emergencyStopEmitsTriggeredAndResetEvents() async {
  let (bus, capture) = makeBus()
  await bus.subscribe(EmergencyStopTriggeredEvent.self) {
    (envelope: EventEnvelope<EmergencyStopTriggeredEvent>) async in
    await capture.recordTriggered(envelope.payload)
  }
  await bus.subscribe(EmergencyStopResetEvent.self) {
    (envelope: EventEnvelope<EmergencyStopResetEvent>) async in
    await capture.recordReset(envelope.payload)
  }
  let controller = EmergencyStopController(eventBus: bus)

  await controller.trigger(source: .keyboard, reason: "panic")
  await controller.reset(actor: .user)

  let triggered = await capture.triggered
  let resets = await capture.resets
  #expect(triggered.count == 1)
  #expect(triggered.first?.source == .keyboard)
  #expect(resets.count == 1)
}

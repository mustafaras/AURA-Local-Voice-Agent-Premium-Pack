import AuraCore
import Foundation
import Testing

@testable import AURA

/// UI-3 G3-2 pins the event-to-ring projection at the existing published
/// TaskStatus boundary. No timer, mock percentage, or persistence is allowed.
struct UI3TaskProgressTests {
  @MainActor
  private func makeModel(with id: UUID) -> AuraAppModel {
    let model = AuraAppModel(startRuntime: false)
    model.taskStatuses = [
      TaskStatus(
        id: id,
        state: .running,
        objective: "Index workspace",
        priority: .normal,
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: Date(timeIntervalSince1970: 100),
        completedSteps: 1,
        totalSteps: 4,
        currentStepDescription: "Collecting files"),
    ]
    return model
  }

  @Test("TaskProgressEvent maps counts and step text into the published task row")
  @MainActor
  func progressPayloadUpdatesPublishedTaskStatus() {
    let id = UUID()
    let model = makeModel(with: id)
    let updatedAt = Date(timeIntervalSince1970: 200)
    model.applyTaskProgress(
      TaskProgressEvent(
        taskID: id,
        completedSteps: 3,
        totalSteps: 4,
        currentStepDescription: "Building index",
        updatedAt: updatedAt))
    let row = model.taskStatuses[0]
    #expect(row.completedSteps == 3)
    #expect(row.totalSteps == 4)
    #expect(row.percentComplete == 0.75)
    #expect(row.currentStepDescription == "Building index")
    #expect(row.updatedAt == updatedAt)
  }

  @Test("progress projection clamps malformed step boundaries and never invents progress")
  @MainActor
  func progressPayloadClampsBoundaries() {
    let id = UUID()
    let model = makeModel(with: id)
    model.applyTaskProgress(
      TaskProgressEvent(
        taskID: id,
        completedSteps: 99,
        totalSteps: -1,
        currentStepDescription: "Unknown"))
    #expect(model.taskStatuses[0].completedSteps == 0)
    #expect(model.taskStatuses[0].totalSteps == 0)
    #expect(model.taskStatuses[0].percentComplete == 0)
  }

  @Test("progress subscription consumes the payload instead of discarding it")
  @MainActor
  func progressEventSubscriptionUsesEnvelopePayload() async {
    let id = UUID()
    let model = makeModel(with: id)
    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "task-progress"))
    await model.subscribeToStatus(on: bus)
    await bus.emit(
      EventEnvelope(
        correlationID: UUID(),
        causationID: UUID(),
        actor: .system,
        sensitivity: .internalLevel,
        payload: TaskProgressEvent(
          taskID: id,
          completedSteps: 2,
          totalSteps: 4,
          currentStepDescription: "Halfway")))
    #expect(model.taskStatuses[0].percentComplete == 0.5)
    #expect(model.taskStatuses[0].currentStepDescription == "Halfway")
  }

  @Test("progress ring clamps and renders the honest percentage")
  @MainActor
  func progressRingIsPureAndConstructible() {
    #expect(AuraProgressRing.normalizedProgress(-1) == 0)
    #expect(AuraProgressRing.normalizedProgress(0.5) == 0.5)
    #expect(AuraProgressRing.normalizedProgress(2) == 1)
    #expect(AuraProgressRing.normalizedProgress(.infinity) == 0)
    _ = AuraProgressRing(progress: 0.75).body
  }
}

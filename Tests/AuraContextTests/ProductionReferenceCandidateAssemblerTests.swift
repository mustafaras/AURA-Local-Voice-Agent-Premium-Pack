import AuraContext
import AuraCore
import Foundation
import Testing

private func productionCandidate(
  sourceID: ContextSourceID,
  description: String,
  authority: ContextAuthority,
  observedAt: Date,
  scopeMatch: Bool = true,
  confidence: Double = 0.9,
  salience: Double = 0.5,
  entityKind: ReferenceEntityKind = .file
) -> ReferenceCandidate {
  ReferenceCandidate(
    sourceID: sourceID, description: description, authority: authority,
    confidence: confidence, observedAt: observedAt, hasDirectEvidence: true,
    scopeMatch: scopeMatch, entityKind: entityKind, conversationalSalience: salience)
}

@Test
func productionAssemblerIsolatesCandidatesOutsideTheActiveWorkspace() {
  let now = Date()
  let assembler = ProductionReferenceCandidateAssembler()
  let inside = productionCandidate(
    sourceID: .recentFile(path: "/repo/README.md"), description: "file: /repo/README.md",
    authority: .userStated, observedAt: now, salience: 1)
  let outside = productionCandidate(
    sourceID: .recentFile(path: "/other/secrets.txt"), description: "file: /other/secrets.txt",
    authority: .userStated, observedAt: now, salience: 1)
  let workspace = ActiveWorkspaceSnapshot(
    workspaceFolderPaths: ["/repo"], capturedAt: now)

  let result = assembler.assemble(
    candidates: [inside, outside], activeWorkspace: workspace, durableTasks: [],
    backendIDs: TurnBackendIDs(), referenceDate: now)

  #expect(result.contains { $0.description == inside.description })
  #expect(!result.contains { $0.description == outside.description })
}

@Test
func productionAssemblerRanksHigherAuthorityBeforeARecentLowerAuthorityTarget() {
  let now = Date()
  let assembler = ProductionReferenceCandidateAssembler()
  let stated = productionCandidate(
    sourceID: .recentFile(path: "/repo/stated.txt"), description: "file: /repo/stated.txt",
    authority: .userStated, observedAt: now.addingTimeInterval(-120), confidence: 0.9,
    salience: 0.5)
  let inferred = productionCandidate(
    sourceID: .recentFile(path: "/repo/inferred.txt"), description: "file: /repo/inferred.txt",
    authority: .inferred, observedAt: now, confidence: 0.9, salience: 1)

  let result = assembler.assemble(
    candidates: [inferred, stated], activeWorkspace: nil, durableTasks: [],
    backendIDs: TurnBackendIDs(), referenceDate: now)

  #expect(result.first?.description == stated.description)
}

@Test
func productionAssemblerOmitsExpiredAndFutureCandidates() {
  var configuration = ContextConfiguration()
  configuration.referenceCandidateMaxAgeSeconds = 30
  let assembler = ProductionReferenceCandidateAssembler(configuration: configuration)
  let now = Date()
  let fresh = productionCandidate(
    sourceID: .recentFile(path: "/repo/fresh.txt"), description: "file: /repo/fresh.txt",
    authority: .observed, observedAt: now)
  let stale = productionCandidate(
    sourceID: .recentFile(path: "/repo/stale.txt"), description: "file: /repo/stale.txt",
    authority: .userStated, observedAt: now.addingTimeInterval(-31))
  let future = productionCandidate(
    sourceID: .recentFile(path: "/repo/future.txt"), description: "file: /repo/future.txt",
    authority: .userStated, observedAt: now.addingTimeInterval(1))

  let result = assembler.assemble(
    candidates: [fresh, stale, future], activeWorkspace: nil, durableTasks: [],
    backendIDs: TurnBackendIDs(), referenceDate: now)

  #expect(result.map(\.description) == [fresh.description])
}

@Test
func productionAssemblerOmitsCompletedTasksAndEmptyBackendIdentities() {
  let now = Date()
  let task = TaskStatus(
    id: UUID(), state: .completed, objective: "old test", priority: .normal,
    createdAt: now.addingTimeInterval(-10), updatedAt: now.addingTimeInterval(-1))
  let activeTask = TaskStatus(
    id: UUID(), state: .running, objective: "run previous test", priority: .normal,
    createdAt: now.addingTimeInterval(-10), updatedAt: now)

  let result = ProductionReferenceCandidateAssembler().assemble(
    candidates: [], activeWorkspace: nil, durableTasks: [task, activeTask],
    backendIDs: TurnBackendIDs(model: ""), referenceDate: now)

  #expect(result.count == 1)
  #expect(result.first?.sourceID == .durableTask(taskID: activeTask.id))
  #expect(!result.contains { $0.description.contains(task.id.uuidString) })
}

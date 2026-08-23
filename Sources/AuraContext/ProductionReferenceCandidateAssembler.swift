import AuraCore
import Foundation

/// Assembles the bounded, ephemeral reference set used by the production
/// composition path. It accepts already-typed observations and never performs
/// I/O or grants authority. Scope, age, deduplication, ranking, and the hard
/// candidate bound are enforced here before `ReferenceResolver` sees data.
public struct ProductionReferenceCandidateAssembler: Sendable, Equatable {
  public let configuration: ContextConfiguration

  public init(configuration: ContextConfiguration = ContextConfiguration()) {
    self.configuration = configuration
  }

  public func assemble(
    candidates: [ReferenceCandidate],
    activeWorkspace: ActiveWorkspaceSnapshot?,
    durableTasks: [TaskStatus],
    backendIDs: TurnBackendIDs,
    referenceDate: Date
  ) -> [ReferenceCandidate] {
    var all = candidates
    appendWorkspaceCandidates(to: &all, workspace: activeWorkspace)
    appendTaskCandidates(to: &all, tasks: durableTasks)
    appendBackendCandidates(to: &all, backendIDs: backendIDs, observedAt: referenceDate)

    let freshInScope = all.filter { candidate in
      guard candidate.scopeMatch, isInLiveWorkspaceScope(candidate, workspace: activeWorkspace)
      else { return false }
      let age = referenceDate.timeIntervalSince(candidate.observedAt)
      return age >= 0 && age <= configuration.referenceCandidateMaxAgeSeconds
    }

    let ranked = freshInScope.sorted {
      let lhs =
        ContextRanking.score($0, referenceDate: referenceDate, configuration: configuration)
        + configuration.referenceSalienceWeight * $0.conversationalSalience
      let rhs =
        ContextRanking.score($1, referenceDate: referenceDate, configuration: configuration)
        + configuration.referenceSalienceWeight * $1.conversationalSalience
      if lhs != rhs { return lhs > rhs }
      if $0.observedAt != $1.observedAt { return $0.observedAt > $1.observedAt }
      return $0.id.uuidString < $1.id.uuidString
    }

    var result: [ReferenceCandidate] = []
    var seenTargets = Set<String>()
    for candidate in ranked {
      let key = targetKey(for: candidate)
      guard seenTargets.insert(key).inserted else { continue }
      result.append(candidate)
      if result.count == configuration.maxReferenceCandidates { break }
    }
    return result
  }

  private func isInLiveWorkspaceScope(
    _ candidate: ReferenceCandidate,
    workspace: ActiveWorkspaceSnapshot?
  ) -> Bool {
    guard let workspace else { return true }
    switch candidate.sourceID {
    case .recentFile(let path), .workspace(let path):
      guard !workspace.workspaceFolderPaths.isEmpty else { return true }
      return workspace.workspaceFolderPaths.contains { root in
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
      }
    case .recentApplication(let bundleIdentifier):
      guard let activeBundle = workspace.appBundleIdentifier else { return true }
      return bundleIdentifier == activeBundle
    default:
      return true
    }
  }

  private func appendWorkspaceCandidates(
    to candidates: inout [ReferenceCandidate],
    workspace: ActiveWorkspaceSnapshot?
  ) {
    guard let workspace else { return }
    let observedAt = workspace.capturedAt
    if let app = workspace.appBundleIdentifier ?? workspace.appDisplayName,
      let identifier = boundedIdentifier(app)
    {
      candidates.append(
        ReferenceCandidate(
          sourceID: .recentApplication(bundleIdentifier: identifier),
          description: "application: \(identifier)", authority: .observed, confidence: 1,
          observedAt: observedAt, hasDirectEvidence: true, scopeMatch: true,
          entityKind: .application, conversationalSalience: 0.75))
    }
    if let activeFilePath = boundedPath(workspace.activeFilePath) {
      candidates.append(
        ReferenceCandidate(
          sourceID: .workspace(path: activeFilePath), description: "file: \(activeFilePath)",
          authority: .observed, confidence: 1, observedAt: observedAt, hasDirectEvidence: true,
          scopeMatch: true, entityKind: .file, conversationalSalience: 1))
    }
    for path in workspace.workspaceFolderPaths.compactMap(boundedPath) {
      candidates.append(
        ReferenceCandidate(
          sourceID: .workspace(path: path), description: "repository: \(path)",
          authority: .observed, confidence: 1, observedAt: observedAt, hasDirectEvidence: true,
          scopeMatch: true, entityKind: .repository, conversationalSalience: 0.95))
    }
  }

  private func appendTaskCandidates(to candidates: inout [ReferenceCandidate], tasks: [TaskStatus])
  {
    for task in tasks where [.pending, .running, .paused].contains(task.state) {
      let objective = boundedText(task.objective, limit: 160)
      guard !objective.isEmpty else { continue }
      candidates.append(
        ReferenceCandidate(
          sourceID: .durableTask(taskID: task.id),
          description: "task \(task.id.uuidString.prefix(8)): \(objective)",
          authority: .systemDerived, confidence: 0.9, observedAt: task.updatedAt,
          hasDirectEvidence: true, scopeMatch: true, entityKind: .task,
          conversationalSalience: task.state == .running ? 0.9 : 0.65))
    }
  }

  private func appendBackendCandidates(
    to candidates: inout [ReferenceCandidate],
    backendIDs: TurnBackendIDs,
    observedAt: Date
  ) {
    let identifiers = [backendIDs.stt, backendIDs.tts, backendIDs.model, backendIDs.tool]
      .compactMap { $0 }
    for rawIdentifier in identifiers {
      guard let identifier = boundedIdentifier(rawIdentifier) else { continue }
      candidates.append(
        ReferenceCandidate(
          sourceID: .backendIdentity(identifier: identifier), description: "backend: \(identifier)",
          authority: .observed, confidence: 1, observedAt: observedAt, hasDirectEvidence: true,
          scopeMatch: true, entityKind: .backend, conversationalSalience: 0.55))
    }
  }

  private func targetKey(for candidate: ReferenceCandidate) -> String {
    candidate.entityKind.rawValue + "|"
      + candidate.description
      .lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
  }

  private func boundedPath(_ path: String?) -> String? {
    guard let path else { return nil }
    let bounded = boundedText(path, limit: 1_024)
    return bounded.isEmpty ? nil : bounded
  }

  private func boundedIdentifier(_ value: String) -> String? {
    let bounded = boundedText(value, limit: 80)
    guard !bounded.isEmpty,
      bounded.allSatisfy({ $0.isLetter || $0.isNumber || ".-_:/.".contains($0) })
    else { return nil }
    return bounded
  }

  private func boundedText(_ value: String, limit: Int) -> String {
    let scalars = value.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F }
    return String(String.UnicodeScalarView(scalars.prefix(limit)))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

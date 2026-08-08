import AuraCore
import Foundation

/// Source used to resolve the workspace for a coding action.
public enum VSCodeWorkspaceResolutionSource: String, Codable, Sendable, Equatable {
  case explicitUserTarget
  case activeVSCode
  case activeDurableTask
  case projectCandidate
}

public enum VSCodeWorkspaceResolutionStatus: String, Codable, Sendable, Equatable {
  case resolved
  case ambiguous
  case invalidTarget
  case unavailable
}

/// A fail-closed workspace decision. Ambiguous candidates are retained for UI
/// confirmation; no caller should silently pick one.
public struct VSCodeWorkspaceResolution: Codable, Sendable, Equatable {
  public let status: VSCodeWorkspaceResolutionStatus
  public let path: String?
  public let source: VSCodeWorkspaceResolutionSource?
  public let requiresConfirmation: Bool
  public let candidates: [String]
  public let detail: String

  public init(
    status: VSCodeWorkspaceResolutionStatus,
    path: String? = nil,
    source: VSCodeWorkspaceResolutionSource? = nil,
    requiresConfirmation: Bool = false,
    candidates: [String] = [],
    detail: String
  ) {
    self.status = status
    self.path = path
    self.source = source
    self.requiresConfirmation = requiresConfirmation
    self.candidates = candidates
    self.detail = detail
  }

  public var isResolved: Bool { status == .resolved && path != nil && !requiresConfirmation }
}

/// Resolves a coding workspace with the R6 precedence contract:
/// explicit target, active VS Code workspace, active durable task/worktree,
/// then project candidates. It performs no writes and never guesses on
/// ambiguity.
public struct VSCodeWorkspaceResolver: Sendable {
  public init() {}

  public func resolve(
    explicitTarget: String?,
    activeWorkspace: VSCodeWorkspaceInfo,
    activeDurableTaskPath: String?,
    projectCandidates: [String]
  ) -> VSCodeWorkspaceResolution {
    if let explicitTarget, !explicitTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      guard let path = canonicalExistingDirectory(explicitTarget) else {
        return VSCodeWorkspaceResolution(
          status: .invalidTarget,
          requiresConfirmation: false,
          detail: "explicit workspace target is not an existing directory: " + explicitTarget)
      }
      return VSCodeWorkspaceResolution(
        status: .resolved,
        path: path,
        source: .explicitUserTarget,
        detail: "workspace selected from explicit user target")
    }

    if let activePath = activeWorkspace.activeFolderPath ?? activeWorkspace.folderPaths.first,
      let path = canonicalExistingDirectory(activePath)
    {
      return VSCodeWorkspaceResolution(
        status: .resolved,
        path: path,
        source: .activeVSCode,
        detail: "workspace selected from active VS Code workspace")
    }

    if let activeDurableTaskPath,
      let path = canonicalExistingDirectory(activeDurableTaskPath)
    {
      return VSCodeWorkspaceResolution(
        status: .resolved,
        path: path,
        source: .activeDurableTask,
        detail: "workspace selected from active durable task or worktree")
    }

    let uniqueCandidates = Set(projectCandidates.compactMap(canonicalExistingDirectory)).sorted()
    switch uniqueCandidates.count {
    case 0:
      return VSCodeWorkspaceResolution(
        status: .unavailable,
        detail: "no existing workspace candidate is available")
    case 1:
      return VSCodeWorkspaceResolution(
        status: .resolved,
        path: uniqueCandidates[0],
        source: .projectCandidate,
        detail: "workspace selected from the sole project candidate")
    default:
      return VSCodeWorkspaceResolution(
        status: .ambiguous,
        requiresConfirmation: true,
        candidates: uniqueCandidates,
        detail: "multiple workspace candidates require explicit confirmation")
    }
  }

  private func canonicalExistingDirectory(_ rawPath: String) -> String? {
    let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !path.isEmpty, path.hasPrefix("/") else { return nil }
    guard FileManager.default.fileExists(atPath: path) else { return nil }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
      return nil
    }
    return URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
  }
}

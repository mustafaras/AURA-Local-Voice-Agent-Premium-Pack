import AuraCore
import Foundation

/// A semantic postcondition predicate for one computer-use step, evaluated
/// against the post-action observation. This is the "semantic postcondition"
/// the R4 Verification section requires — hash change alone is insufficient
/// for success.
public struct ComputerUsePostcondition: Sendable {
  /// A stable identifier for the predicate (e.g. "windowTitleContains") used
  /// in evidence records.
  public let id: String
  /// A human-readable description for confirmation/audit presentation.
  public let summary: String
  private let check: @Sendable (ComputerUseObservation) -> Bool

  public init(id: String, summary: String, check: @escaping @Sendable (ComputerUseObservation) -> Bool) {
    self.id = id
    self.summary = summary
    self.check = check
  }

  public func isSatisfied(by observation: ComputerUseObservation) -> Bool {
    check(observation)
  }
}

/// App-specific fixtures: the known objectives a `DeterministicComputerUsePlanner`
/// can turn into typed plans for a given approved app, plus the semantic
/// postcondition each step must satisfy. Kept deliberately small and curated
/// (R4 section C: "Enable an app only after app-specific fixtures and live
/// validation pass").
public enum ComputerUseAppFixtures: Sendable {
  /// A curated, app-scoped known objective → typed plan. A production
  /// planner is *never* a universal shortcut; unknown objectives are
  /// clarified rather than guessed.
  public struct KnownTask: Sendable {
    public let objectiveKey: String
    public let plan: ComputerUsePlan
    /// Semantic postconditions, one per plan step (same count as `plan.steps`).
    public let postconditions: [ComputerUsePostcondition]

    public init(objectiveKey: String, plan: ComputerUsePlan, postconditions: [ComputerUsePostcondition]) {
      self.objectiveKey = objectiveKey
      self.plan = plan
      self.postconditions = postconditions
    }
  }

  /// Return the curated known tasks for an approved app bundle identifier,
  /// or `nil` when the app has no fixtures (and therefore cannot be planned).
  public static func knownTasks(for appBundleIdentifier: String) -> [KnownTask]? {
    switch appBundleIdentifier {
    case "com.apple.finder":
      return [
        KnownTask(
          objectiveKey: "reveal_downloads",
          plan: ComputerUsePlan(steps: [
            ComputerUseActionStep(
              kind: .keyPress(key: "space", modifiers: []),
              anchor: UIAnchor(),
              semanticIntent: .observe,
              targetAppBundleIdentifier: "com.apple.finder",
              rationale: "reveal a selected file preview (observation only)"),
          ]),
          postconditions: [ComputerUsePostcondition(
            id: "windowTitleContains",
            summary: "finder window title is unchanged",
            check: { $0.screen.windowTitle != nil })]),
      ]
    case "com.apple.Terminal":
      return [
        KnownTask(
          objectiveKey: "print_working_directory",
          plan: ComputerUsePlan(steps: [
            ComputerUseActionStep(
              kind: .keyPress(key: "return", modifiers: []),
              anchor: UIAnchor(),
              semanticIntent: .observe,
              targetAppBundleIdentifier: "com.apple.Terminal",
              rationale: "read-only prompt refresh (observation only)"),
          ]),
          postconditions: [ComputerUsePostcondition(
            id: "terminalPromptPresent",
            summary: "terminal prompt is present",
            check: { $0.controlCandidates.contains { $0.role == "AXTextArea" } })]),
      ]
    default:
      // Apps without fixtures cannot be planned — structural, not a guess.
      return nil
    }
  }
}

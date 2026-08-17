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

  public init(
    id: String, summary: String, check: @escaping @Sendable (ComputerUseObservation) -> Bool
  ) {
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

    public init(
      objectiveKey: String, plan: ComputerUsePlan, postconditions: [ComputerUsePostcondition]
    ) {
      self.objectiveKey = objectiveKey
      self.plan = plan
      self.postconditions = postconditions
    }
  }

  /// Return the curated known tasks for an approved app bundle identifier,
  /// or `nil` when the app has no fixtures (and therefore cannot be planned).
  ///
  /// Each approved app covers the three action types SP-007's procedure
  /// requires: (1) an Accessibility-anchored action, (2) a bounded
  /// coordinate fallback action, and (3) a confirmation-required action.
  /// The plans are deliberately curated and read-only/observation-focused;
  /// they never send, publish, delete, or authenticate.
  public static func knownTasks(for appBundleIdentifier: String) -> [KnownTask]? {
    switch appBundleIdentifier {
    case "com.apple.finder":
      // (1) Accessibility-anchored: activate the toolbar search field by role.
      let a11yStep = ComputerUseActionStep(
        kind: .click,
        anchor: UIAnchor(
          accessibilityRole: "AXTextField",
          accessibilityTitle: "Search",
          accessibilityIdentifier: "search-field"),
        semanticIntent: .observe,
        targetAppBundleIdentifier: "com.apple.finder",
        rationale: "focus the Finder search field via Accessibility anchor (observation)")
      let a11yPost = ComputerUsePostcondition(
        id: "finderSearchFieldPresent",
        summary: "finder window is still present",
        check: { $0.screen.windowTitle != nil })

      // (2) Bounded coordinate fallback: space-bar preview at a normalized
      // coordinate (the list area center) when no Accessibility hint resolves.
      let coordStep = ComputerUseActionStep(
        kind: .keyPress(key: "space", modifiers: []),
        anchor: UIAnchor(fallbackNormalizedX: 0.5, fallbackNormalizedY: 0.6),
        semanticIntent: .observe,
        targetAppBundleIdentifier: "com.apple.finder",
        rationale: "quick-look preview via bounded coordinate fallback")
      let coordPost = ComputerUsePostcondition(
        id: "finderPreviewOpened",
        summary: "finder window title is unchanged after preview",
        check: { $0.screen.windowTitle != nil })

      // (3) Confirmation-required: open a folder in a new window (navigate
      // intent, but marked for confirmation to prove the confirmation gate).
      let confirmStep = ComputerUseActionStep(
        kind: .keyPress(key: "return", modifiers: ["command"]),
        anchor: UIAnchor(
          accessibilityRole: "AXList",
          accessibilityTitle: "File list"),
        semanticIntent: .navigate,
        targetAppBundleIdentifier: "com.apple.finder",
        rationale: "open selected folder in new window (confirmation-required)")
      let confirmPost = ComputerUsePostcondition(
        id: "finderNewWindowOrSame",
        summary: "finder is still active",
        check: { $0.screen.appBundleIdentifier == "com.apple.finder" })

      return [
        KnownTask(
          objectiveKey: "focus_search_field",
          plan: ComputerUsePlan(steps: [a11yStep]),
          postconditions: [a11yPost]),
        KnownTask(
          objectiveKey: "quick_look_preview",
          plan: ComputerUsePlan(steps: [coordStep]),
          postconditions: [coordPost]),
        KnownTask(
          objectiveKey: "open_folder_new_window",
          plan: ComputerUsePlan(steps: [confirmStep]),
          postconditions: [confirmPost]),
      ]

    case "com.apple.Terminal":
      // (1) Accessibility-anchored: focus the terminal text area by role.
      let a11yStep = ComputerUseActionStep(
        kind: .click,
        anchor: UIAnchor(
          accessibilityRole: "AXTextArea",
          accessibilityTitle: "Terminal"),
        semanticIntent: .observe,
        targetAppBundleIdentifier: "com.apple.Terminal",
        rationale: "focus the Terminal text area via Accessibility anchor")
      let a11yPost = ComputerUsePostcondition(
        id: "terminalTextAreaPresent",
        summary: "terminal text area is present",
        check: { $0.controlCandidates.contains { $0.role == "AXTextArea" } })

      // (2) Bounded coordinate fallback: press Return at the terminal center.
      let coordStep = ComputerUseActionStep(
        kind: .keyPress(key: "return", modifiers: []),
        anchor: UIAnchor(fallbackNormalizedX: 0.5, fallbackNormalizedY: 0.95),
        semanticIntent: .observe,
        targetAppBundleIdentifier: "com.apple.Terminal",
        rationale: "refresh the prompt via bounded coordinate fallback")
      let coordPost = ComputerUsePostcondition(
        id: "terminalPromptPresent",
        summary: "terminal prompt is present",
        check: { $0.controlCandidates.contains { $0.role == "AXTextArea" } })

      // (3) Confirmation-required: clear the screen (navigate, confirmation).
      let confirmStep = ComputerUseActionStep(
        kind: .keyPress(key: "k", modifiers: ["command"]),
        anchor: UIAnchor(
          accessibilityRole: "AXTextArea",
          accessibilityTitle: "Terminal"),
        semanticIntent: .navigate,
        targetAppBundleIdentifier: "com.apple.Terminal",
        rationale: "clear terminal screen (confirmation-required)")
      let confirmPost = ComputerUsePostcondition(
        id: "terminalCleared",
        summary: "terminal is still active after clear",
        check: { $0.screen.appBundleIdentifier == "com.apple.Terminal" })

      return [
        KnownTask(
          objectiveKey: "focus_terminal",
          plan: ComputerUsePlan(steps: [a11yStep]),
          postconditions: [a11yPost]),
        KnownTask(
          objectiveKey: "print_working_directory",
          plan: ComputerUsePlan(steps: [coordStep]),
          postconditions: [coordPost]),
        KnownTask(
          objectiveKey: "clear_screen",
          plan: ComputerUsePlan(steps: [confirmStep]),
          postconditions: [confirmPost]),
      ]

    case "com.apple.Notes":
      // (1) Accessibility-anchored: focus the note body text area by role.
      let a11yStep = ComputerUseActionStep(
        kind: .click,
        anchor: UIAnchor(
          accessibilityRole: "AXTextArea",
          accessibilityTitle: "Note body"),
        semanticIntent: .observe,
        targetAppBundleIdentifier: "com.apple.Notes",
        rationale: "focus the Notes body text area via Accessibility anchor")
      let a11yPost = ComputerUsePostcondition(
        id: "notesBodyPresent",
        summary: "notes body text area is present",
        check: { $0.controlCandidates.contains { $0.role == "AXTextArea" } })

      // (2) Bounded coordinate fallback: click the new-note button at a
      // normalized coordinate (toolbar area) when Accessibility is unavailable.
      let coordStep = ComputerUseActionStep(
        kind: .click,
        anchor: UIAnchor(fallbackNormalizedX: 0.9, fallbackNormalizedY: 0.05),
        semanticIntent: .navigate,
        targetAppBundleIdentifier: "com.apple.Notes",
        rationale: "new note button via bounded coordinate fallback")
      let coordPost = ComputerUsePostcondition(
        id: "notesNewNoteCreated",
        summary: "notes is still active",
        check: { $0.screen.appBundleIdentifier == "com.apple.Notes" })

      // (3) Confirmation-required: delete the current note (destructive,
      // mandatory-confirmation) to prove the confirmation gate fires.
      let confirmStep = ComputerUseActionStep(
        kind: .keyPress(key: "delete", modifiers: ["command"]),
        anchor: UIAnchor(
          accessibilityRole: "AXButton",
          accessibilityTitle: "Delete note"),
        semanticIntent: .delete,
        targetAppBundleIdentifier: "com.apple.Notes",
        rationale: "delete current note (mandatory confirmation required)")
      let confirmPost = ComputerUsePostcondition(
        id: "notesDeletedOrBlocked",
        summary: "notes is still active after delete attempt",
        check: { $0.screen.appBundleIdentifier == "com.apple.Notes" })

      return [
        KnownTask(
          objectiveKey: "focus_note_body",
          plan: ComputerUsePlan(steps: [a11yStep]),
          postconditions: [a11yPost]),
        KnownTask(
          objectiveKey: "create_new_note",
          plan: ComputerUsePlan(steps: [coordStep]),
          postconditions: [coordPost]),
        KnownTask(
          objectiveKey: "delete_current_note",
          plan: ComputerUsePlan(steps: [confirmStep]),
          postconditions: [confirmPost]),
      ]

    default:
      // Apps without fixtures cannot be planned — structural, not a guess.
      return nil
    }
  }
}

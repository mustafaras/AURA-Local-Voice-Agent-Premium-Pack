import AuraComputerUse
import AuraCore
import AuraPolicy
import AuraScreen
import CoreGraphics
import Foundation

// MARK: - Screen fakes (mirrors AuraScreenTests' fakes; not shared across
// test targets, so redefined here against AuraScreen's public protocols).

func makeTestImage(width: Int = 2, height: Int = 2) -> CGImage {
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1.0))
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  return context.makeImage()!
}

actor ScriptedWindowSource: ScreenWindowSource {
  private var windows: [ScreenWindowDescriptor]
  var imageToReturn: CGImage

  init(windows: [ScreenWindowDescriptor], imageToReturn: CGImage = makeTestImage()) {
    self.windows = windows
    self.imageToReturn = imageToReturn
  }

  func listCapturableWindows() async throws(AuraError) -> [ScreenWindowDescriptor] {
    windows
  }

  func captureImage(windowID: Int, region: CaptureRegion?, maxDimension: Int)
    async throws(AuraError)
    -> CGImage
  {
    guard windows.contains(where: { $0.windowID == windowID }) else {
      throw AuraError.screenCaptureError("window \(windowID) not found")
    }
    return imageToReturn
  }
}

actor ScriptedTextRecognizer: TextRecognizing {
  func recognizeText(in image: CGImage) async throws(AuraError) -> [RecognizedTextRegion] {
    []
  }
}

actor ScriptedSecureFieldDetector: SecureFieldDetecting {
  var focusedBundleIdentifiers: Set<String>

  init(focusedBundleIdentifiers: Set<String> = []) {
    self.focusedBundleIdentifiers = focusedBundleIdentifiers
  }

  func isSecureFieldFocused(applicationBundleIdentifier: String) async -> Bool {
    focusedBundleIdentifiers.contains(applicationBundleIdentifier)
  }
}

func makeWindow(
  id: Int, title: String? = "Window", bundleID: String? = "com.example.app",
  appName: String? = "Example", isOnScreen: Bool = true
) -> ScreenWindowDescriptor {
  ScreenWindowDescriptor(
    windowID: id, title: title, applicationBundleIdentifier: bundleID, applicationName: appName,
    frameX: 0, frameY: 0, frameWidth: 800, frameHeight: 600, isOnScreen: isOnScreen)
}

func makePolicyEngine(configuration: PolicyConfiguration = PolicyConfiguration()) async throws
  -> PolicyEngine
{
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraComputerUseTests", category: "policy"))
  return try await PolicyEngine(configuration: configuration, eventBus: bus, store: nil)
}

func makeScreenEngine(
  windows: [ScreenWindowDescriptor],
  policyEngine: PolicyEngine,
  imageToReturn: CGImage = makeTestImage(),
  assistantBundleIdentifier: String = "ai.aura.local"
) -> ScreenContextEngine {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windowSource = ScriptedWindowSource(windows: windows, imageToReturn: imageToReturn)
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraComputerUseTests", category: "screen"))
  return ScreenContextEngine(
    windowSource: windowSource, textRecognizer: ScriptedTextRecognizer(),
    secureFieldDetector: ScriptedSecureFieldDetector(), policyEngine: policyEngine, eventBus: bus,
    configuration: configuration, assistantBundleIdentifier: assistantBundleIdentifier)
}

// MARK: - Computer-use fakes

/// Records every execution attempt so tests can assert exactly which steps
/// actually reached the executor (as opposed to being blocked upstream).
actor ScriptedActionExecutor: UIActionExecuting {
  private(set) var executedSteps: [(kind: ComputerUseActionKind, usedAccessibility: Bool)] = []
  var shouldThrow: Bool = false
  var resultToReturn: UIActionExecutionResult = UIActionExecutionResult(
    usedAccessibilityAnchor: false)

  var executeCallCount: Int { executedSteps.count }

  func setResultToReturn(_ result: UIActionExecutionResult) {
    resultToReturn = result
  }

  func setShouldThrow(_ value: Bool) {
    shouldThrow = value
  }

  func execute(
    _ kind: ComputerUseActionKind,
    anchor: UIAnchor,
    applicationBundleIdentifier: String,
    windowFrame: UIWindowFrame
  ) async throws(AuraError) -> UIActionExecutionResult {
    if shouldThrow {
      throw AuraError.computerUseError("scripted failure")
    }
    executedSteps.append((kind, resultToReturn.usedAccessibilityAnchor))
    return resultToReturn
  }
}

/// Holds an unstructured `Task` handle so a `ComputerUsePlanning` fake's
/// `sideEffect` closure (itself running *inside* the task, from within
/// `loop.run`) can cancel the very task it is part of, to test
/// `Task.isCancelled` handling deterministically.
actor TaskHandleBox {
  private var task: Task<ComputerUseLoopOutcome, Never>?

  func set(_ task: Task<ComputerUseLoopOutcome, Never>) {
    self.task = task
  }

  func cancel() {
    task?.cancel()
  }
}

actor ScriptedModalDetector: ModalDialogDetecting {
  var bundleIdentifierToReturn: String?

  init(bundleIdentifierToReturn: String? = nil) {
    self.bundleIdentifierToReturn = bundleIdentifierToReturn
  }

  func detectUnexpectedModal(expectedBundleIdentifier: String) async -> String? {
    bundleIdentifierToReturn
  }
}

/// Returns a fixed sequence of plans, one per call; the last plan repeats
/// once the sequence is exhausted. A `sideEffect` closure lets tests trigger
/// external state (e.g. an emergency stop) from inside a `propose` call to
/// simulate an asynchronous trigger arriving mid-run.
actor ScriptedPlanner: ComputerUsePlanning {
  private var plans: [ComputerUsePlan]
  private var callIndex = 0
  private(set) var proposeCallCount = 0
  var sideEffect: (@Sendable () async -> Void)?

  init(plans: [ComputerUsePlan]) {
    self.plans = plans
  }

  init(repeating plan: ComputerUsePlan) {
    self.plans = [plan]
  }

  func setSideEffect(_ effect: @escaping @Sendable () async -> Void) {
    sideEffect = effect
  }

  func propose(
    observation: ScreenObservation, objective: String, previousSteps: [ComputerUseActionStep]
  ) async -> ComputerUsePlan {
    proposeCallCount += 1
    if let sideEffect {
      await sideEffect()
    }
    let plan = plans[min(callIndex, plans.count - 1)]
    callIndex += 1
    return plan
  }
}

func makeStep(
  kind: ComputerUseActionKind = .click,
  anchor: UIAnchor = UIAnchor(fallbackNormalizedX: 0.5, fallbackNormalizedY: 0.5),
  intent: ComputerUseSemanticIntent = .observe,
  targetAppBundleIdentifier: String = "com.example.app",
  rationale: String = ""
) -> ComputerUseActionStep {
  ComputerUseActionStep(
    kind: kind, anchor: anchor, semanticIntent: intent,
    targetAppBundleIdentifier: targetAppBundleIdentifier, rationale: rationale)
}

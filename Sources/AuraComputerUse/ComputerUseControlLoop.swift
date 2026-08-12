import AuraCore
import AuraPolicy
import AuraScreen
import Foundation

/// Drives one bounded Observe → Plan → Policy → Act → Verify computer-use
/// session against a single approved window/application, per
/// `docs/subsystems/10_COMPUTER_USE.md`.
///
/// Every iteration: capture the approved window (`ScreenContextEngine`,
/// already policy-gated and redacted per Phase 17), check for an identity
/// change or unexpected modal, check for no-progress, ask the injected
/// `ComputerUsePlanning` conformer for a bounded plan, re-check policy for
/// each step immediately before executing it, execute through
/// `UIActionExecuting`, and record whether progress was observed. The loop
/// never sees or evaluates anything but typed `ComputerUsePlan`/
/// `ComputerUseActionStep` values — the planner boundary is what makes "no
/// raw model output becomes an executable action" true by construction.
public actor ComputerUseControlLoop {
  let screenEngine: ScreenContextEngine
  let policyEngine: PolicyEngine
  let actionExecutor: any UIActionExecuting
  let modalDetector: any ModalDialogDetecting
  let secureFieldDetector: any SecureFieldDetecting
  let emergencyStop: EmergencyStopController
  let eventBus: AuraEventBus
  let configuration: ComputerUseConfiguration

  public init(
    screenEngine: ScreenContextEngine,
    policyEngine: PolicyEngine,
    actionExecutor: any UIActionExecuting,
    modalDetector: any ModalDialogDetecting,
    secureFieldDetector: any SecureFieldDetecting,
    emergencyStop: EmergencyStopController,
    eventBus: AuraEventBus = .shared,
    configuration: ComputerUseConfiguration = ComputerUseConfiguration()
  ) {
    self.screenEngine = screenEngine
    self.policyEngine = policyEngine
    self.actionExecutor = actionExecutor
    self.modalDetector = modalDetector
    self.secureFieldDetector = secureFieldDetector
    self.emergencyStop = emergencyStop
    self.eventBus = eventBus
    self.configuration = configuration
  }

}

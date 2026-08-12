import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

extension IntentExecutionOutcome {
  var isVerifiedExecution: Bool {
    if case .executed = self { return true }
    return false
  }

  var summaryForVerification: String {
    switch self {
    case .executed(let summary, _): return summary
    case .acknowledgedAsync(let summary): return summary
    case .blockedByPolicy(let reason): return reason
    case .blockedPendingConfirmationDenied: return "confirmation denied"
    case .ambiguous(let question): return question
    case .failed(let reason): return reason
    }
  }
}

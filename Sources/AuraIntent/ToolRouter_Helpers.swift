import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

extension ToolRouter {
  // MARK: - Helpers

  func clarifyingQuestion(for intent: TypedIntent) -> String {
    let language = intent.language
    if let unresolvedApp = intent.slotValue(IntentSlotName.unresolvedAppName) {
      if language == .turkish {
        return "\(unresolvedApp) uygulamasını tanımıyorum. Hangi uygulamayı kastettiniz?"
      }
      if language == .mixed {
        return "\(unresolvedApp) app’i tanımıyorum. Which application did you mean?"
      }
      return
        "I don't know an application called \"\(unresolvedApp)\". Which application did you mean?"
    }
    if let unresolvedExecutable = intent.slotValue(IntentSlotName.executable) {
      if language == .turkish {
        return "\(unresolvedExecutable) komutunu tanımıyorum. Tam yolu paylaşır mısınız?"
      }
      if language == .mixed {
        return "\(unresolvedExecutable) executable’ı tanımıyorum. Could you give me the full path?"
      }
      return
        "I don't recognize the command \"\(unresolvedExecutable)\". "
        + "Could you give me the full path?"
    }
    if language == .turkish {
      return "Ne yapmak istediğinizden emin değilim. Lütfen yeniden ifade eder misiniz?"
    }
    if language == .mixed {
      return "I'm not sure what you'd like me to do. Lütfen yeniden ifade eder misiniz?"
    }
    return "I'm not sure what you'd like me to do. Could you rephrase that?"
  }

  func emit<P: EventPayload>(_ payload: P, correlationID: UUID, causationID: UUID) async {
    let envelope = EventEnvelope(
      correlationID: correlationID, causationID: causationID, actor: .intent,
      sensitivity: .internalLevel, payload: payload)
    await eventBus.emit(envelope)
  }
}

import AuraAgent
import AuraCore
import AuraStore
import Foundation
import Testing

@testable import AURA

@Suite("SP-019 memory UI state")
struct SP019MemoryUIStateTests {
  @Test("memory search keeps scope and retention metadata inspectable")
  @MainActor
  func memorySearchProjection() {
    let model = AuraAppModel(startRuntime: false)
    let matching = AuraMemoryRow(
      id: UUID(), memoryClass: MemoryClass.projectFact.rawValue,
      subject: "project.toolchain", statement: "SwiftPM", purpose: "verified tool result",
      provenance: "observed", confidence: 1, sensitivity: SensitivityLevel.internalLevel.rawValue,
      createdAt: Date(timeIntervalSince1970: 1), canMutate: true,
      retention: .indefinite, scope: MemoryScope(projectID: "aura"))
    let other = AuraMemoryRow(
      id: UUID(), memoryClass: MemoryClass.userPreference.rawValue,
      subject: "reply.language", statement: "Türkçe", purpose: "preference",
      provenance: "userStated", confidence: 1, sensitivity: SensitivityLevel.internalLevel.rawValue,
      createdAt: Date(timeIntervalSince1970: 2), canMutate: true,
      retention: .sessionScoped, scope: MemoryScope(sessionID: UUID()))
    model.memoryRows = [matching, other]
    model.memorySearchText = "toolchain"

    #expect(model.visibleMemoryRows == [matching])
    #expect(model.visibleMemoryRows.first?.scope.projectID == "aura")
    #expect(model.visibleMemoryRows.first?.retention == .indefinite)
  }

  @Test("a deletion receipt proves the deletion without preserving its content")
  @MainActor
  func deletionReceiptProjection() {
    let model = AuraAppModel(startRuntime: false)
    let recordID = UUID()
    let deletedAt = Date(timeIntervalSince1970: 1_000)
    let receipt = MemoryDeletionReceipt(
      recordID: recordID, memoryClass: .workingConversation,
      reason: "user requested from R9 Memory Center", deletedAt: deletedAt)

    model.lastMemoryDeletionReceipt = AuraMemoryDeletionReceiptRow(receipt: receipt)

    let row = try? #require(model.lastMemoryDeletionReceipt)
    #expect(row?.id == recordID)
    #expect(row?.memoryClass == MemoryClass.workingConversation.rawValue)
    #expect(row?.reason == "user requested from R9 Memory Center")
    #expect(row?.deletedAt == deletedAt)
  }

  @Test("the receipt survives after the transient status line is replaced")
  @MainActor
  func deletionReceiptOutlivesStatusMessage() {
    let model = AuraAppModel(startRuntime: false)
    model.lastMemoryDeletionReceipt = AuraMemoryDeletionReceiptRow(
      receipt: MemoryDeletionReceipt(
        recordID: UUID(), memoryClass: .projectFact, reason: "user requested"))

    // A later, unrelated operation must not erase the user's proof.
    model.lastOperationMessage = "Memory preference saved."

    #expect(model.lastMemoryDeletionReceipt != nil)
  }
}

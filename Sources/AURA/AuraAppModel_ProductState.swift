import AppKit
import AuraAgent
import AuraConfig
import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation

extension AuraAppModel {
  private func capabilityRow(
    manifest: CapabilityManifest,
    availability: CapabilityAvailability?
  ) -> AuraCapabilityRow {
    let language: DialogueLanguage = productUIState.language == .turkish ? .turkish : .english
    let state: String
    let detail: String
    let isEnabled: Bool
    switch availability {
    case .ready:
      state = AuraCopy.text("capabilities.ready", language: productUIState.language)
      detail = "Ready"
      isEnabled = true
    case .degraded(let reason):
      state = AuraCopy.text("capabilities.degraded", language: productUIState.language)
      detail = reason
      isEnabled = false
    case .disabled(let reason):
      state = AuraCopy.text("capabilities.disabled", language: productUIState.language)
      detail = reason
      isEnabled = false
    case nil:
      state = AuraCopy.text("capabilities.disabled", language: productUIState.language)
      detail = "No availability evidence is registered"
      isEnabled = false
    }
    return AuraCapabilityRow(
      id: manifest.qualifiedID,
      title: manifest.presentation.title(for: language),
      description: manifest.presentation.descriptionByLocale[language] ?? "",
      locality: manifest.locality.rawValue,
      state: state,
      detail: detail,
      riskAndConfirmation: manifest.confirmationRule,
      qualifiedID: manifest.qualifiedID,
      isEnabled: isEnabled)
  }

  private func memoryRow(_ record: MemoryRecord) -> AuraMemoryRow {
    AuraMemoryRow(
      id: record.id,
      memoryClass: record.memoryClass.rawValue,
      subject: record.subject,
      statement: record.statement,
      purpose: record.purpose,
      provenance: String(describing: record.provenance),
      confidence: record.confidence,
      sensitivity: record.sensitivity.rawValue,
      createdAt: record.createdAt,
      canMutate: record.memoryClass != .auditSecurity)
  }

  func refreshProductSnapshots() {
    Task { [weak self] in
      guard let self else { return }
      await refreshRuntimeHealth()
      guard let kernel else { return }
      do {
        taskStatuses = try await kernel.taskStatuses()
        let capabilitySnapshot = try await kernel.capabilityHealthSnapshot()
        capabilityRows =
          capabilitySnapshot
          .map { capabilityRow(manifest: $0, availability: $1) }
          .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        backendHealth = await kernel.refreshAgentBackendHealth()
        let records = try await kernel.memoryRecordsSnapshot()
        memoryRows = records.map(memoryRow)
      } catch {
        setError("Product status refresh failed: \(error.localizedDescription)")
      }
    }
  }

  func cancelTask(_ id: UUID) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        try await kernel.taskCancel(id: id)
        lastOperationMessage = "Task cancellation requested."
        refreshProductSnapshots()
      } catch {
        setError("Task cancellation failed: \(error.localizedDescription)")
      }
    }
  }

  func deleteMemory(_ id: UUID) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        try await kernel.deleteMemoryRecord(
          id: id, reason: "user requested from R9 Memory Center")
        lastOperationMessage = "Memory record deleted; the deletion itself remains audited."
        refreshProductSnapshots()
      } catch {
        setError("Memory deletion failed: \(error.localizedDescription)")
      }
    }
  }

  func beginMemoryCorrection(_ record: AuraMemoryRow) {
    memoryCorrectionTarget = record
  }

  func correctMemory(_ id: UUID, statement: String) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        _ = try await kernel.correctMemoryRecord(
          id: id, newStatement: statement, reason: "user correction from R9 Memory Center")
        lastOperationMessage = "Correction appended and linked to the previous memory record."
        refreshProductSnapshots()
      } catch {
        setError("Memory correction failed: \(error.localizedDescription)")
      }
    }
  }

  func exportMemory() {
    Task {
      do {
        guard let data = try await kernel?.memoryExportData() else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue =
          "aura-memory-\(Self.exportDateFormatter.string(from: Date())).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try data.write(to: url, options: .atomic)
        lastOperationMessage = "Non-audit memory export saved."
      } catch {
        setError("Memory export failed: \(error.localizedDescription)")
      }
    }
  }
}

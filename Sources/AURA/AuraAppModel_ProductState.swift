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

  /// Project one integration snapshot into its row.
  ///
  /// The title comes from the capability manifest's localized presentation
  /// rather than a second hardcoded list, so the integrations panel and the
  /// capability panel cannot disagree about what a capability is called.
  private func integrationRow(_ snapshot: ProductivityIntegrationSnapshot) -> AuraIntegrationRow {
    let language: DialogueLanguage = productUIState.language == .turkish ? .turkish : .english
    let title =
      InitialCapabilitySet.manifests()
      .first { $0.0.id == snapshot.capabilityID }?
      .0.presentation.title(for: language) ?? snapshot.capabilityID
    let state: String
    let detail: String
    switch snapshot.availability {
    case .ready:
      state = AuraCopy.text("integrations.connected", language: productUIState.language)
      detail = AuraCopy.text("capabilities.ready", language: productUIState.language)
    case .degraded(let reason):
      state = AuraCopy.text("capabilities.degraded", language: productUIState.language)
      detail = reason
    case .disabled(let reason):
      state = AuraCopy.text("integrations.notConnected", language: productUIState.language)
      detail = reason
    }
    return AuraIntegrationRow(
      id: snapshot.capabilityID,
      title: title,
      state: state,
      detail: detail,
      remediation: snapshot.remediation,
      accountLabel: snapshot.accountLabel,
      isReady: snapshot.isReady,
      isRevocable: snapshot.isRevocable,
      canConnect: snapshot.canConnect,
      canGrantAccess: snapshot.canGrantAccess)
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
      canMutate: record.memoryClass != .auditSecurity,
      retention: record.retention,
      scope: record.scope,
      supersedes: record.supersedes)
  }

  private func memoryConflictRow(
    _ conflict: MemoryConflict, recordsByID: [UUID: MemoryRecord]
  ) -> AuraMemoryConflictRow? {
    guard
      let existing = recordsByID[conflict.existingRecordID],
      let new = recordsByID[conflict.newRecordID],
      existing.memoryClass != .auditSecurity,
      new.memoryClass != .auditSecurity
    else { return nil }
    return AuraMemoryConflictRow(
      id: conflict.id,
      subject: conflict.subject,
      existingRecordID: conflict.existingRecordID,
      newRecordID: conflict.newRecordID,
      existingStatement: existing.statement,
      newStatement: new.statement,
      detectedAt: conflict.detectedAt,
      resolution: conflict.resolution)
  }

  var visibleMemoryRows: [AuraMemoryRow] {
    let query = memorySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    guard !query.isEmpty else { return memoryRows }
    return memoryRows.filter { row in
      [row.memoryClass, row.subject, row.statement, row.purpose, row.provenance]
        .joined(separator: " ").lowercased().contains(query)
    }
  }

  func refreshProductSnapshots() {
    Task { [weak self] in
      guard let self else { return }
      await refreshRuntimeHealth()
      guard let kernel else { return }
      // Re-derive the productivity capabilities' availability before reading
      // any of it back. The Safari bridge's readiness expires with its last
      // observation, so a registry refreshed only by onboarding actions went
      // stale between them: a freshly clicked page left `browser.read`
      // unregistered, and the router refused the turn with "no tool
      // registered" while the health surface showed the bridge as usable.
      await kernel.refreshProductivityAvailability()
      do {
        taskStatuses = try await kernel.taskStatuses()
        let capabilitySnapshot = try await kernel.capabilityHealthSnapshot()
        capabilityRows =
          capabilitySnapshot
          .map { capabilityRow(manifest: $0, availability: $1) }
          .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        backendHealth = await kernel.refreshAgentBackendHealth()
        integrationRows = try await kernel.productivityIntegrationSnapshots().map(integrationRow)
        let allRecords = try await kernel.memoryRecordsSnapshot(includeSuperseded: true)
        let records = try await kernel.memoryRecordsSnapshot()
        memoryRows = records.map(memoryRow)
        let recordsByID = Dictionary(uniqueKeysWithValues: allRecords.map { ($0.id, $0) })
        memoryConflicts = try await kernel.memoryConflictsSnapshot().compactMap {
          memoryConflictRow($0, recordsByID: recordsByID)
        }
        if let profile = try await kernel.preferenceProfileSnapshot() {
          memoryPreferenceProfile = profile
          hasSavedMemoryPreference = true
        } else {
          hasSavedMemoryPreference = false
        }
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

  /// Disconnect one integration.
  ///
  /// The row's capability ID decides which credential is revoked, so the UI
  /// never passes an address around; the kernel resolves the approved account
  /// or profile itself. Availability is refreshed afterwards by the kernel,
  /// and the rows are re-read here, so a failed revocation keeps showing the
  /// integration as connected instead of a state it is not in.
  func disconnectIntegration(_ row: AuraIntegrationRow) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        let snapshots = try await kernel.productivityIntegrationSnapshots()
        guard let snapshot = snapshots.first(where: { $0.capabilityID == row.id }) else {
          throw AuraError.invalidConfiguration("that integration is no longer present")
        }
        switch snapshot.capabilityID {
        case InitialCapabilitySet.mailRead.id:
          let approved = try await kernel.approvedMailAccountIDs()
          guard let accountID = approved.first, approved.count == 1 else {
            throw AuraError.invalidConfiguration(
              "more than one approved account matches; disconnect it from Setup")
          }
          try await kernel.revokeMailAccount(accountID: accountID)
        case InitialCapabilitySet.browserRead.id:
          // The kernel resolves its own configured profile; the UI does not
          // get to name which profile's secret is deleted.
          try await kernel.revokeConnectedBrowserProfile()
        default:
          throw AuraError.invalidConfiguration(
            "that integration has no stored credential to disconnect")
        }
        lastOperationMessage = "Integration disconnected; its stored credential was deleted."
        refreshProductSnapshots()
      } catch {
        setError("Disconnect failed: \(error.localizedDescription)")
      }
    }
  }

  /// Connect whichever integration the row names.
  ///
  /// Mail runs the user-present OAuth flow; the Safari profile provisions the
  /// bridge secret its extension's native half signs with. The provisioned
  /// secret is deliberately dropped here rather than shown: the native half
  /// reads it from the Keychain itself, so putting it on screen would expose a
  /// credential nobody has to handle.
  func connectIntegration(_ row: AuraIntegrationRow) {
    switch row.id {
    case InitialCapabilitySet.browserRead.id:
      Task {
        do {
          guard let kernel else {
            throw AuraError.invalidConfiguration("AURA runtime is not started")
          }
          _ = try await kernel.connectConfiguredBrowserProfile()
          lastOperationMessage = "Safari profile connected; the read bridge is provisioned."
          refreshProductSnapshots()
        } catch {
          setError("Safari profile connection failed: \(error.localizedDescription)")
        }
      }
    default:
      connectMailIntegration()
    }
  }

  /// Start the only user-facing Gmail enrollment path. Token material stays
  /// inside the kernel/coordinator and never enters this observable model.
  func connectMailIntegration() {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        lastOperationMessage = "Opening the Gmail read-only authorization page."
        try await kernel.connectMailAccountViaOAuth()
        lastOperationMessage = "Gmail read-only integration connected."
        refreshProductSnapshots()
      } catch {
        setError("Gmail connection failed: \(error.localizedDescription)")
      }
    }
  }

  /// Ask macOS for a native integration's permission from the row's button.
  ///
  /// The row state is re-read from the real authorization status afterwards,
  /// so a dismissed or denied prompt reports the refusal rather than leaving
  /// the row claiming an access the user did not give.
  func grantIntegrationAccess(_ row: AuraIntegrationRow) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        let granted = try await kernel.grantNativeIntegrationAccess(capabilityID: row.id)
        lastOperationMessage =
          granted
          ? "\(row.title) access granted."
          : "\(row.title) access was not granted."
        refreshProductSnapshots()
      } catch {
        setError("Access request failed: \(error.localizedDescription)")
      }
    }
  }

  func deleteMemory(_ id: UUID) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        let receipt = try await kernel.deleteMemoryRecord(
          id: id, reason: "user requested from R9 Memory Center")
        lastMemoryDeletionReceipt = AuraMemoryDeletionReceiptRow(receipt: receipt)
        lastOperationMessage = "Memory record deleted; the deletion itself remains audited."
        refreshProductSnapshots()
      } catch {
        setError("Memory deletion failed: \(error.localizedDescription)")
      }
    }
  }

  func saveMemoryPreferences() {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        var profile = memoryPreferenceProfile
        profile.preferredLanguage = productUIState.language == .turkish ? "tr-TR" : "en-US"
        let saved = try await kernel.savePreferenceProfile(profile)
        memoryPreferenceProfile = saved
        hasSavedMemoryPreference = true
        lastOperationMessage =
          "Memory preference saved with user purpose and bounded local-only policy."
        refreshProductSnapshots()
      } catch {
        setError("Memory preference save failed: \(error.localizedDescription)")
      }
    }
  }

  func clearMemoryPreferences() {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        _ = try await kernel.clearPreferenceProfile()
        memoryPreferenceProfile = UserPreferenceProfile(
          preferredLanguage: productUIState.language == .turkish ? "tr-TR" : "en-US")
        hasSavedMemoryPreference = false
        lastOperationMessage = "Saved memory preference cleared."
        refreshProductSnapshots()
      } catch {
        setError("Memory preference clear failed: \(error.localizedDescription)")
      }
    }
  }

  func resolveMemoryConflict(_ id: UUID, resolution: MemoryConflictResolution) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        try await kernel.resolveMemoryConflict(id: id, resolution: resolution)
        lastOperationMessage = "Conflict resolution recorded; memory history remains inspectable."
        refreshProductSnapshots()
      } catch {
        setError("Memory conflict resolution failed: \(error.localizedDescription)")
      }
    }
  }

  func enforceMemoryRetention() {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        let purged = try await kernel.enforceMemoryRetention()
        lastOperationMessage = "Retention cleanup purged \(purged.count) expired record(s)."
        refreshProductSnapshots()
      } catch {
        setError("Retention cleanup failed: \(error.localizedDescription)")
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

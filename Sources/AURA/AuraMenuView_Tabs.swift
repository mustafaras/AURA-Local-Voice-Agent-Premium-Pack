import AuraAgent
import AuraCore
import AuraIntent
import SwiftUI

extension AuraMenuView {
  var tasksTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("tasks.title", symbol: "checklist")
      if model.taskStatuses.isEmpty {
        Text(copy("tasks.empty")).foregroundStyle(.secondary)
      }
      ForEach(model.taskStatuses) { task in
        GroupBox {
          VStack(alignment: .leading, spacing: 7) {
            HStack {
              Text(task.objective).bold().fixedSize(horizontal: false, vertical: true)
              Spacer()
              Text(taskState(task.state))
                .foregroundStyle(task.state == .failed ? .red : .secondary)
            }
            ProgressView(value: task.percentComplete)
              .accessibilityLabel(
                "\(copy("tasks.progress")): \(Int(task.percentComplete * 100)) percent")
            Text(
              task.currentStepDescription.isEmpty
                ? "\(task.completedSteps)/\(task.totalSteps)"
                : task.currentStepDescription
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            // Task scope: the backend/mode/workspace/health the task launched
            // under. The engine derives it from the launch context, so it is
            // real metadata, not a hardcoded label.
            if let scope = task.scope {
              Text(
                "\(copy("tasks.backend")): \(scope.backend) · "
                  + "\(copy("tasks.mode")): \(scope.mode) · "
                  + "\(copy("tasks.health")): \(scope.backendHealth)"
              )
              .font(.caption2)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
              if !scope.workspace.isEmpty {
                Text("\(copy("tasks.workspace")): \(scope.workspace)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            if let error = task.errorMessage {
              Text("\(copy("tasks.failed")): \(error)")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
              Text(task.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2).foregroundStyle(.secondary)
              Spacer()
              if task.state == .pending || task.state == .running {
                Button(copy("tasks.pause"), role: .destructive) {
                  model.pauseTask(task.id)
                }
                .accessibilityHint(
                  language == .turkish
                    ? "Bu kalıcı görevi duraklatır"
                    : "Pauses this durable task")
              }
              if task.state == .paused {
                Button(copy("tasks.resume")) {
                  model.resumeTask(task.id)
                }
                .accessibilityHint(
                  language == .turkish
                    ? "Bu duraklatılmış görevi sürdürür"
                    : "Resumes this paused durable task")
              }
              if task.state == .failed {
                Button(copy("tasks.retry")) {
                  model.retryTask(task.id)
                }
                .accessibilityHint(
                  language == .turkish
                    ? "Bu başarısız görevi tekrar dener"
                    : "Retries this failed durable task")
              }
              if task.state == .pending || task.state == .running || task.state == .paused {
                Button(copy("tasks.cancel"), role: .destructive) {
                  model.cancelTask(task.id)
                }
                .accessibilityHint(
                  language == .turkish
                    ? "Bu kalıcı görevin çalışmasını durdurmayı ister"
                    : "Requests cancellation of this durable task")
              }
            }
          }
        }
        .accessibilityElement(children: .contain)
      }
    }
  }

  var capabilitiesTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionTitle("capabilities.title", symbol: "switch.2")
        Spacer()
        Button {
          model.refreshProductSnapshots()
        } label: {
          Label(copy("capabilities.refresh"), systemImage: "arrow.clockwise")
        }
        .accessibilityLabel(copy("capabilities.refresh"))
      }
      ForEach(model.capabilityRows, id: \AuraCapabilityRow.id) { (capability: AuraCapabilityRow) in
        GroupBox {
          VStack(alignment: .leading, spacing: 5) {
            HStack {
              Text(capability.title).bold()
              Spacer()
              Text(capability.state)
                .foregroundStyle(capability.isEnabled ? .green : .orange)
            }
            Text(capability.description).fixedSize(horizontal: false, vertical: true)
            Text("\(locality(capability.locality)) · \(capability.qualifiedID)")
              .font(.caption).foregroundStyle(.secondary)
            Text(capability.detail)
              .font(.caption)
              .foregroundStyle(capability.isEnabled ? Color.secondary : Color.orange)
              .fixedSize(horizontal: false, vertical: true)
            Text("\(copy("capabilities.confirmationRisk")): \(capability.riskAndConfirmation)")
              .font(.caption2).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(capability.title), \(capability.state), \(capability.detail), "
            + "\(locality(capability.locality))"
        )
      }
      if model.capabilityRows.isEmpty {
        Text(copy("capabilities.none"))
          .foregroundStyle(.secondary)
      }
    }
  }

  var modelsTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionTitle("models.title", symbol: "waveform.and.mic")
        Spacer()
        Button {
          model.refreshProductSnapshots()
        } label: {
          Label(copy("models.refresh"), systemImage: "arrow.clockwise")
        }
      }
      GroupBox(copy("models.voice")) {
        VStack(alignment: .leading, spacing: 5) {
          Label(
            "\(copy("models.speechRecognition")): "
              + model.permissions.speechRecognition.title(for: language),
            systemImage: "waveform")
          Label(copy("models.systemTTS"), systemImage: "speaker.wave.2")
          Text(
            "Reference-voice cloning is not enabled by this surface and requires explicit consent."
          )
          .font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      ForEach(model.backendHealth, id: \.backend) { backend in
        GroupBox(backend.backend.rawValue.capitalized) {
          VStack(alignment: .leading, spacing: 4) {
            Text("\(copy("models.state")): \(backendState(backend.state))")
            Text("\(copy("models.authentication")): \(backend.authentication.rawValue)")
            Text("\(copy("models.availability")): \(backend.modelAvailability)")
            Text(backend.detail)
              .font(.caption).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
      }
      Text(copy("models.unverified"))
        .font(.caption).foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// The read-first integrations panel.
  ///
  /// Every row states three things: whether the integration works right now,
  /// which account or profile it is bound to (masked), and — when it does not
  /// work — the one next step the user can take. A row that only said
  /// "disabled" would tell the user their assistant is broken without telling
  /// them what to do, which is what "actionable UI state" rules out.
  var integrationsSection: some View {
    GroupBox(copy("integrations.title")) {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(model.integrationRows, id: \AuraIntegrationRow.id) {
          (integration: AuraIntegrationRow) in
          VStack(alignment: .leading, spacing: 3) {
            HStack {
              Text(integration.title).bold()
              Spacer()
              Text(integration.state)
                .foregroundStyle(integration.isReady ? .green : .orange)
                .accessibilityIdentifier(
                  AuraAccessibilityID.integrationState(integration.id))
            }
            if let accountLabel = integration.accountLabel {
              Text(accountLabel).font(.caption).foregroundStyle(.secondary)
            }
            Text(integration.detail)
              .font(.caption)
              .foregroundStyle(integration.isReady ? Color.secondary : Color.orange)
              .fixedSize(horizontal: false, vertical: true)
            if !integration.remediation.isEmpty {
              Label(
                "\(copy("integrations.action")): \(integration.remediation)",
                systemImage: "arrow.right.circle"
              )
              .font(.caption)
              .fixedSize(horizontal: false, vertical: true)
            }
            if integration.canConnect {
              let connectKey =
                integration.id == InitialCapabilitySet.browserRead.id
                ? "integrations.connectBrowser" : "integrations.connect"
              let connectSymbol =
                integration.id == InitialCapabilitySet.browserRead.id
                ? "globe" : "envelope.badge.plus"
              Button {
                model.connectIntegration(integration)
              } label: {
                Label(copy(connectKey), systemImage: connectSymbol)
              }
              .accessibilityLabel(copy(connectKey))
              .accessibilityIdentifier(
                AuraAccessibilityID.integrationConnect(integration.id))
            }
            if integration.canGrantAccess {
              Button {
                model.grantIntegrationAccess(integration)
              } label: {
                Label(copy("integrations.grantAccess"), systemImage: "lock.open")
              }
              .accessibilityLabel(
                "\(copy("integrations.grantAccess")): \(integration.title)"
              )
              .accessibilityIdentifier(
                AuraAccessibilityID.integrationGrant(integration.id))
            }
            if integration.canEnableInConfiguration {
              Button {
                model.enableIntegrationInConfiguration(integration)
              } label: {
                Label(copy("integrations.enableInConfiguration"), systemImage: "switch.2")
              }
              .accessibilityLabel(
                "\(copy("integrations.enableInConfiguration")): \(integration.title)"
              )
              .accessibilityIdentifier(
                AuraAccessibilityID.integrationEnable(integration.id))
            }
            if integration.canOpenSystemSettings, let anchor = integration.systemSettingsAnchor {
              Button {
                model.openNativeIntegrationSettings(anchor: anchor)
              } label: {
                Label(copy("integrations.systemSettings"), systemImage: "gearshape")
              }
              .accessibilityLabel(
                "\(copy("integrations.systemSettings")): \(integration.title)"
              )
              .accessibilityIdentifier(
                AuraAccessibilityID.integrationSettings(integration.id))
            }
            if integration.canReconnect {
              Button {
                model.connectIntegration(integration)
              } label: {
                Label(copy("integrations.reconnectGmail"), systemImage: "arrow.clockwise")
              }
              .accessibilityLabel(
                "\(copy("integrations.reconnectGmail")): \(integration.title)"
              )
              .accessibilityIdentifier(
                AuraAccessibilityID.integrationReconnect(integration.id))
            }
            if integration.needsMailApproval {
              // The old "approve a mail account in Setup" remediation named a
              // surface that did not exist. The approval lives here: the user
              // types the one address they are willing to let AURA consider,
              // and Connect runs the read-only OAuth flow immediately after.
              VStack(alignment: .leading, spacing: 4) {
                TextField(
                  copy("integrations.mailApprovalPlaceholder"),
                  text: $model.mailApprovalAddress
                )
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .accessibilityLabel(copy("integrations.mailApprovalPlaceholder"))
                .accessibilityIdentifier(
                  AuraAccessibilityID.mailApprovalField)
                Button {
                  model.approveAndConnectMail(address: model.mailApprovalAddress)
                } label: {
                  Label(
                    copy("integrations.approveAndConnect"),
                    systemImage: "envelope.badge.plus")
                }
                .disabled(!model.mailApprovalAddress.contains("@"))
                .accessibilityLabel(copy("integrations.approveAndConnect"))
                .accessibilityIdentifier(
                  AuraAccessibilityID.mailApproveButton)
              }
            }
            if integration.isRevocable {
              Button(role: .destructive) {
                model.disconnectIntegration(integration)
              } label: {
                Label(copy("integrations.revoke"), systemImage: "minus.circle")
              }
              .accessibilityLabel("\(copy("integrations.revoke")): \(integration.title)")
              .accessibilityIdentifier(
                AuraAccessibilityID.integrationRevoke(integration.id))
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        if model.integrationRows.isEmpty {
          Text(copy("integrations.none")).foregroundStyle(.secondary)
        }
        Text(copy("integrations.readOnly"))
          .font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  var privacyTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("privacy.title", symbol: "lock.shield")
      GroupBox(copy("perm.indicators")) {
        VStack(alignment: .leading, spacing: 5) {
          permissionIndicator(
            copy("perm.microphone"), model.permissions.microphone.title(for: language))
          permissionIndicator(
            copy("perm.activeSpeechRecognition"),
            model.permissions.speechRecognition.title(for: language))
          HStack {
            permissionIndicator(
              copy("perm.screenObservation"),
              model.permissions.screenRecording.title(for: language))
            // Both remediations stay reachable in every state: before a TCC
            // decision the button raises the real macOS prompt; after a
            // recorded decision the prompt can never reappear, so the row
            // hands the user the exact System Settings pane instead. A row
            // that only says "Denied" with no control is a dead end.
            Button {
              model.requestScreenRecordingPermission()
            } label: {
              Label(copy("integrations.grantAccess"), systemImage: "lock.open")
            }
            .accessibilityLabel(
              "\(copy("integrations.grantAccess")): \(copy("perm.screenObservation"))"
            )
            .accessibilityIdentifier(AuraAccessibilityID.screenObservationGrant)
            Button {
              model.openScreenRecordingSettings()
            } label: {
              Label(copy("integrations.systemSettings"), systemImage: "gearshape")
            }
            .accessibilityLabel(
              "\(copy("integrations.systemSettings")): \(copy("perm.screenObservation"))"
            )
            .accessibilityIdentifier(AuraAccessibilityID.screenObservationSettings)
          }
          Label(copy("conversation.cloudDisabled"), systemImage: "icloud.slash")
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      integrationsSection
      GroupBox(copy("memory.preferenceProfile")) {
        VStack(alignment: .leading, spacing: 8) {
          Text(copy("memory.preferenceNote"))
            .font(.caption).foregroundStyle(.secondary)
          Picker(
            "Response length",
            selection: $model.memoryPreferenceProfile.responseLength
          ) {
            ForEach(PreferenceResponseLength.allCases, id: \.self) { length in
              Text(length.rawValue.capitalized).tag(length)
            }
          }
          Toggle(
            "Allow remote context",
            isOn: Binding(
              get: { !model.memoryPreferenceProfile.localOnly },
              set: { model.memoryPreferenceProfile.localOnly = !$0 })
          )
          .help("The machine policy can reject this preference; it cannot widen policy authority.")
          HStack {
            Button(copy("memory.savePreference")) { model.saveMemoryPreferences() }
              .buttonStyle(.borderedProminent)
            Button(copy("memory.clearPreference"), role: .destructive) {
              model.clearMemoryPreferences()
            }
            .disabled(!model.hasSavedMemoryPreference)
          }
          Text(
            model.hasSavedMemoryPreference
              ? "Saved with purpose: user-controlled personalization profile; "
                + "scope: global; retention: indefinite."
              : "No saved profile."
          )
          .font(.caption2).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
      GroupBox(copy("memory.controls")) {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            TextField(copy("memory.searchPlaceholder"), text: $model.memorySearchText)
              .textFieldStyle(.roundedBorder)
              .accessibilityLabel(copy("a11y.memorySearch"))
            Button {
              model.exportMemory()
            } label: {
              Label(copy("privacy.export"), systemImage: "square.and.arrow.up")
            }
            .accessibilityHint(
              language == .turkish
                ? "Denetim ve güvenlik kayıtları dışarı aktarılmaz"
                : "Audit and security records are excluded")
          }
          HStack {
            Text(
              "\(model.visibleMemoryRows.count) \(copy("memory.visibleOf")) "
                + "\(model.memoryRows.count) \(copy("memory.records"))")
              .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(copy("memory.runRetention")) { model.enforceMemoryRetention() }
          }
          Text(
            "Audit/security memory is excluded from inspection and export "
              + "and cannot be corrected or deleted here."
          )
          .font(.caption2).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          if let receipt = model.lastMemoryDeletionReceipt {
            Divider()
            VStack(alignment: .leading, spacing: 3) {
              Label(copy("a11y.deletionReceipt"), systemImage: "trash.slash")
                .font(.caption).bold()
              Text("\(copy("a11y.receiptRecord")) \(receipt.id.uuidString) (\(receipt.memoryClass))")
              Text("\(copy("memory.reasonLabel")): \(receipt.reason)")
              Text("\(copy("memory.deletedAtLabel")) \(receipt.deletedAt.formatted(.iso8601))")
              Text(copy("memory.receiptGone"))
                .foregroundStyle(.secondary)
            }
            .font(.caption2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            // `.combine` merges the child labels, but an `.accessibilityLabel`
            // then *replaces* that merged text — a bare "Memory deletion
            // receipt" would leave the record, reason, and time unreachable to
            // VoiceOver, which is exactly the proof the receipt exists to give.
            .accessibilityLabel(
              "\(copy("a11y.deletionReceipt")). \(copy("a11y.receiptRecord")) \(receipt.id.uuidString), "
                + "\(copy("a11y.receiptClass")) \(receipt.memoryClass), \(copy("a11y.receiptReason")) \(receipt.reason), "
                + "\(copy("a11y.receiptDeletedAt")) \(receipt.deletedAt.formatted(.iso8601)). "
                + "The record content is gone; only this receipt and the audit event remain.")
          }
        }
      }
      if !model.memoryConflicts.isEmpty {
        GroupBox(copy("memory.conflicts")) {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(model.memoryConflicts) { conflict in
              VStack(alignment: .leading, spacing: 5) {
                Text(conflict.subject).bold()
                Text("\(copy("memory.previous")): \(conflict.existingStatement)")
                Text("\(copy("memory.new")): \(conflict.newStatement)")
                Text(
                  conflict.resolution == nil
                    ? "Unresolved contradiction; neither statement is silently discarded."
                    : "Resolution recorded: \(conflict.resolutionSummary)"
                )
                .font(.caption2).foregroundStyle(.secondary)
                HStack {
                  Button(copy("memory.keepPrevious")) {
                    model.resolveMemoryConflict(
                      conflict.id,
                      resolution: .keptExisting(reason: "user selected previous belief")
                    )
                  }
                  Button(copy("memory.keepNew")) {
                    model.resolveMemoryConflict(
                      conflict.id, resolution: .supersededExisting)
                  }
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 4)
            }
          }
        }
      }
      if model.visibleMemoryRows.isEmpty {
        Text(copy("privacy.noMemory")).foregroundStyle(.secondary)
      }
      ForEach(model.visibleMemoryRows) { record in
        MemoryRowView(model: model, record: record)
      }
    }
  }

  var recoveryTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionTitle("recovery.title", symbol: "stethoscope")
        Spacer()
        Button {
          model.refreshPermissions()
          model.refreshProductSnapshots()
        } label: {
          Label(copy("recovery.refresh"), systemImage: "arrow.clockwise")
        }
      }
      GroupBox(copy("perm.group")) {
        VStack(alignment: .leading, spacing: 7) {
          permissionIndicator(
            copy("perm.microphone"), model.permissions.microphone.title(for: language))
          permissionIndicator(
            copy("perm.speechRecognition"),
            model.permissions.speechRecognition.title(for: language))
          permissionIndicator(
            copy("perm.accessibility"), model.permissions.accessibility.title(for: language))
          permissionIndicator(
            copy("perm.screenRecording"),
            model.permissions.screenRecording.title(for: language))
          Button(copy("perm.openPrivacySettings")) { model.openMicrophoneSettings() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      GroupBox(copy("recovery.latency")) {
        VStack(alignment: .leading, spacing: 5) {
          if model.latencySummaries.isEmpty {
            // Deliberately says "no samples" rather than showing zeros. A zero
            // would read as "measured, and instant" — the opposite of the truth.
            Text(copy("recovery.latencyNone"))
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          } else {
            ForEach(model.latencySummaries, id: \LatencyPercentileSummary.kind) { summary in
              let line =
                "\(summary.kind.rawValue): p50 \(Int(summary.p50Milliseconds)) ms · "
                + "p95 \(Int(summary.p95Milliseconds)) ms · "
                + "p99 \(Int(summary.p99Milliseconds)) ms"
              VStack(alignment: .leading, spacing: 1) {
                Text(line)
                Text(
                  "\(summary.sampleCount) \(copy("recovery.samples"))"
                    + (summary.isMockDerived ? " · \(copy("recovery.mockDerived"))" : ""))
                  .font(.caption2).foregroundStyle(summary.isMockDerived ? .orange : .secondary)
              }
              .accessibilityElement(children: .combine)
            }
          }
          Button(copy("recovery.latencyRefresh")) { model.refreshLatencySummaries() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      GroupBox(copy("recovery.diagnostics")) {
        VStack(alignment: .leading, spacing: 5) {
          ForEach(model.runtimeHealth, id: \RuntimeHealth.componentID) { (health: RuntimeHealth) in
            let diagnosticLabel =
              "\(health.componentID): \(health.status.rawValue). \(health.detail)"
            Label(
              "\(health.componentID): \(health.status.rawValue)",
              systemImage: health.status == .ready ? "checkmark.circle" : "exclamationmark.triangle"
            )
            .foregroundStyle(health.status == .ready ? Color.secondary : Color.orange)
            .accessibilityLabel(diagnosticLabel)
          }
          ForEach(model.runtimeWarnings, id: \.self) { warning in
            Text(warning).font(.caption).foregroundStyle(.orange)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      emergencyControls
      Toggle(
        copy("recovery.localTuning"),
        isOn: Binding(
          get: { model.localRecommendationsEnabled },
          set: { model.setLocalRecommendationsEnabled($0) }))
      Text(copy("recovery.support"))
        .font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  var emergencyControls: some View {
    // Every string here goes through `copy(_:)`. This is the control that stops
    // generated mouse and keyboard input, so it must be readable — including to a
    // VoiceOver user — in the language the operator actually selected.
    GroupBox(copy("emergency.group")) {
      if model.emergencyStopActive {
        Button(copy("emergency.rearm")) {
          model.resetEmergencyStop()
        }
        .controlSize(.large)
        .accessibilityHint(copy("emergency.rearmHint"))
      } else {
        Button(role: .destructive) {
          model.triggerEmergencyStop()
        } label: {
          Label(copy("emergency.stop"), systemImage: "hand.raised.fill")
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .keyboardShortcut(.escape, modifiers: [.command, .shift])
        .accessibilityHint(copy("emergency.stopHint"))
      }
    }
  }

  func sectionTitle(_ key: String, symbol: String) -> some View {
    AuraSectionHeader(title: copy(key), symbol: symbol)
      .accessibilityAddTraits(.isHeader)
  }

  func permissionIndicator(_ name: String, _ state: String) -> some View {
    HStack {
      Text(name)
      Spacer()
      Text(state).foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(name): \(state)")
  }

  func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  func locality(_ value: String) -> String {
    value == "local"
      ? (language == .turkish ? "Yerel" : "Local")
      : (language == .turkish ? "Bulut" : "Cloud")
  }

  func taskState(_ state: TaskState) -> String {
    guard language == .turkish else { return state.rawValue.capitalized }
    switch state {
    case .pending: return "Bekliyor"
    case .running: return "Çalışıyor"
    case .paused: return "Duraklatıldı"
    case .cancelled: return "İptal edildi"
    case .completed: return "Tamamlandı"
    case .failed: return "Başarısız"
    }
  }

  func backendState(_ state: AgentBackendHealthState) -> String {
    guard language == .turkish else { return state.rawValue }
    switch state {
    case .ready: return "Hazır"
    case .degraded: return "Kısıtlı"
    case .unavailable: return "Kullanılamıyor"
    case .unauthorized: return "Yetkisiz"
    case .versionMismatch: return "Sürüm uyumsuz"
    }
  }
}

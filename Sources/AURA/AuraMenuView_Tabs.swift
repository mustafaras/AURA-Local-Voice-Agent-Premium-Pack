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
              Text("Failed: \(error)")
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
            Text("Confirmation / risk: \(capability.riskAndConfirmation)")
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
        Text("No registered capabilities are available to inspect.")
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
      GroupBox("Voice") {
        VStack(alignment: .leading, spacing: 5) {
          Label(
            "Speech recognition: \(model.permissions.speechRecognition.title)",
            systemImage: "waveform")
          Label("System speech synthesis: configured local pipeline", systemImage: "speaker.wave.2")
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
            Text("State: \(backendState(backend.state))")
            Text("Authentication: \(backend.authentication.rawValue)")
            Text("Model availability: \(backend.modelAvailability)")
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
                ? "safari" : "envelope.badge.plus"
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
      GroupBox("Permission indicators") {
        VStack(alignment: .leading, spacing: 5) {
          permissionIndicator("Microphone", model.permissions.microphone.title)
          permissionIndicator(
            "Active speech recognition", model.permissions.speechRecognition.title)
          permissionIndicator("Screen observation", model.permissions.screenRecording.title)
          Label(copy("conversation.cloudDisabled"), systemImage: "icloud.slash")
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      integrationsSection
      GroupBox("Memory preference profile") {
        VStack(alignment: .leading, spacing: 8) {
          Text("This is a bounded user preference, not an execution grant.")
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
            Button("Save preference") { model.saveMemoryPreferences() }
              .buttonStyle(.borderedProminent)
            Button("Clear saved preference", role: .destructive) {
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
      GroupBox("Memory controls") {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            TextField("Search memory", text: $model.memorySearchText)
              .textFieldStyle(.roundedBorder)
              .accessibilityLabel("Search inspectable memory")
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
            Text("\(model.visibleMemoryRows.count) visible of \(model.memoryRows.count) records")
              .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Run retention cleanup") { model.enforceMemoryRetention() }
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
              Label("Deletion receipt", systemImage: "trash.slash")
                .font(.caption).bold()
              Text("Record \(receipt.id.uuidString) (\(receipt.memoryClass))")
              Text("Reason: \(receipt.reason)")
              Text("Deleted at \(receipt.deletedAt.formatted(.iso8601))")
              Text("The record content is gone; only this receipt and the audit event remain.")
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
              "Memory deletion receipt. Record \(receipt.id.uuidString), "
                + "class \(receipt.memoryClass), reason \(receipt.reason), "
                + "deleted at \(receipt.deletedAt.formatted(.iso8601)). "
                + "The record content is gone; only this receipt and the audit event remain.")
          }
        }
      }
      if !model.memoryConflicts.isEmpty {
        GroupBox("Unresolved and resolved conflicts") {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(model.memoryConflicts) { conflict in
              VStack(alignment: .leading, spacing: 5) {
                Text(conflict.subject).bold()
                Text("Previous: \(conflict.existingStatement)")
                Text("New: \(conflict.newStatement)")
                Text(
                  conflict.resolution == nil
                    ? "Unresolved contradiction; neither statement is silently discarded."
                    : "Resolution recorded: \(conflict.resolutionSummary)"
                )
                .font(.caption2).foregroundStyle(.secondary)
                HStack {
                  Button("Keep previous") {
                    model.resolveMemoryConflict(
                      conflict.id,
                      resolution: .keptExisting(reason: "user selected previous belief")
                    )
                  }
                  Button("Keep new") {
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
      GroupBox("Permissions") {
        VStack(alignment: .leading, spacing: 7) {
          permissionIndicator("Microphone", model.permissions.microphone.title)
          permissionIndicator("Speech Recognition", model.permissions.speechRecognition.title)
          permissionIndicator("Accessibility", model.permissions.accessibility.title)
          permissionIndicator("Screen Recording", model.permissions.screenRecording.title)
          Button("Open macOS Privacy Settings") { model.openMicrophoneSettings() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      GroupBox("Runtime diagnostics") {
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
        "Local tuning recommendations",
        isOn: Binding(
          get: { model.localRecommendationsEnabled },
          set: { model.setLocalRecommendationsEnabled($0) }))
      Text(copy("recovery.support"))
        .font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  var emergencyControls: some View {
    GroupBox("Emergency control") {
      if model.emergencyStopActive {
        Button("Re-arm generated input") {
          model.resetEmergencyStop()
        }
        .controlSize(.large)
        .accessibilityHint("Allows generated mouse and keyboard input again")
      } else {
        Button(role: .destructive) {
          model.triggerEmergencyStop()
        } label: {
          Label("Emergency Stop", systemImage: "hand.raised.fill")
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .keyboardShortcut(.escape, modifiers: [.command, .shift])
        .accessibilityHint("Immediately disables generated input")
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

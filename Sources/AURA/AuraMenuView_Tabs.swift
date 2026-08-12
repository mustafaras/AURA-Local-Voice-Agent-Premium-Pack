import AuraAgent
import AuraCore
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
      HStack {
        Button {
          model.exportMemory()
        } label: {
          Label(copy("privacy.export"), systemImage: "square.and.arrow.up")
        }
        .accessibilityHint(
          language == .turkish
            ? "Denetim ve güvenlik kayıtları dışarı aktarılmaz"
            : "Audit and security records are excluded")
        Spacer()
        Text("\(model.memoryRows.count) records")
          .font(.caption).foregroundStyle(.secondary)
      }
      if model.memoryRows.isEmpty {
        Text(copy("privacy.noMemory")).foregroundStyle(.secondary)
      }
      ForEach(model.memoryRows) { record in
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
    Label(copy(key), systemImage: symbol)
      .font(.title3.bold())
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

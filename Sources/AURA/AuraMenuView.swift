import AuraCore
import SwiftUI

struct AuraMenuView: View {
  @ObservedObject var model: AuraAppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      statusHeader

      if let challenge = model.pendingConfirmation {
        confirmationCard(challenge)
      }

      HStack(spacing: 8) {
        TextField("Type a request", text: $model.textInput)
          .textFieldStyle(.roundedBorder)
          .onSubmit { model.submitText() }
        Button {
          model.submitText()
        } label: {
          Image(systemName: "arrow.up.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Submit typed request")
      }

      Button {
        model.pushToTalk()
      } label: {
        Label("Push to Talk", systemImage: "mic.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(model.emergencyStopActive)
      .keyboardShortcut(.space, modifiers: [.command, .shift])
      .accessibilityHint("Starts one local speech-recognition turn")

      permissionsSection
      runtimeSection
      taskSection

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
        .accessibilityHint("Immediately disables all generated input")
      }

      Divider()
      HStack {
        SettingsLink {
          Label("Settings", systemImage: "gear")
        }
        Spacer()
        Button("Quit AURA") {
          model.quit()
        }
        .keyboardShortcut("q")
      }
    }
    .padding(16)
    .frame(width: 390)
  }

  private var statusHeader: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: model.status.symbolName)
        .font(.title2)
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(model.status.title)
          .font(.headline)
        Text(model.statusDetail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("AURA status: \(model.status.title). \(model.statusDetail)")
  }

  private var permissionsSection: some View {
    GroupBox("Permissions") {
      VStack(spacing: 8) {
        permissionRow("Microphone", model.permissions.microphone.title)
        permissionRow("Speech Recognition", model.permissions.speechRecognition.title)
        permissionRow("Accessibility", model.permissions.accessibility.title)
        permissionRow("Screen Recording", model.permissions.screenRecording.title)
        if !model.permissions.speechReady {
          Button("Enable Voice Permissions") {
            model.requestVoicePermissions()
          }
          .controlSize(.large)
          .frame(maxWidth: .infinity)
          .accessibilityHint("Shows macOS microphone and Speech Recognition consent dialogs")
        }
      }
      .padding(.top, 4)
    }
  }

  private var taskSection: some View {
    GroupBox("Recent Tasks") {
      if model.tasks.isEmpty {
        Text("No active tasks")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        ForEach(model.tasks) { task in
          HStack {
            Text(task.title).lineLimit(1)
            Spacer()
            Text(task.state).foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
  }

  private var runtimeSection: some View {
    GroupBox("Runtime") {
      VStack(alignment: .leading, spacing: 6) {
        ForEach(model.runtimeWarnings, id: \.self) { warning in
          Label(warning, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(model.runtimeHealth, id: \RuntimeHealth.componentID) { (health: RuntimeHealth) in
          let healthTitle = "\(health.componentID): \(health.status.rawValue)"
          let healthSymbol = health.status == .ready ? "checkmark.circle" : "circle.dotted"
          Label(healthTitle, systemImage: healthSymbol)
            .font(.caption2)
            .foregroundStyle(health.status == .ready ? Color.secondary : Color.orange)
        }
        Text("Emergency shortcut: Command–Shift–Escape")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)
    }
    .accessibilityElement(children: .contain)
  }

  private func confirmationCard(_ challenge: PolicyConfirmationChallenge) -> some View {
    GroupBox("Confirmation Required") {
      VStack(alignment: .leading, spacing: 8) {
        Text("\(challenge.requestedAction.domain).\(challenge.requestedAction.action)")
          .font(.headline)
        Text(challenge.targetSummary)
          .fixedSize(horizontal: false, vertical: true)
        Text("Risk: \(challenge.riskTier.rawValue) · Expires \(challenge.expiresAt.formatted())")
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack {
          Button("Deny", role: .cancel) {
            model.resolveConfirmation(accepted: false)
          }
          .keyboardShortcut(.cancelAction)
          Spacer()
          Button("Allow Once") {
            model.resolveConfirmation(accepted: true)
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  private func permissionRow(_ name: String, _ state: String) -> some View {
    HStack {
      Text(name)
      Spacer()
      Text(state)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(name): \(state)")
  }
}

struct AuraSettingsView: View {
  @ObservedObject var model: AuraAppModel

  var body: some View {
    Form {
      Section("Voice") {
        LabeledContent("Activation", value: "Push to Talk")
        Text("A trained acoustic wake-word model is not installed.")
          .foregroundStyle(.secondary)
        Button("Request Microphone and Speech Access") {
          model.requestVoicePermissions()
        }
      }
      Section("System Permissions") {
        Button("Request Accessibility Access") {
          model.requestAccessibilityPermission()
        }
        Button("Request Screen Recording Access") {
          model.requestScreenRecordingPermission()
        }
        Button("Open Microphone Settings") { model.openMicrophoneSettings() }
        Button("Open Speech Recognition Settings") { model.openSpeechSettings() }
        Button("Open Accessibility Settings") { model.openAccessibilitySettings() }
        Button("Open Screen Recording Settings") { model.openScreenRecordingSettings() }
        Button("Refresh Permission Status") { model.refreshPermissions() }
      }
      Section("Privacy") {
        Text("Speech recognition and system speech synthesis remain on device.")
        Text("Plugin execution remains isolated in the verified helper process.")
      }
      Section("Configuration Governance") {
        Toggle(
          "Local tuning recommendations",
          isOn: Binding(
            get: { model.localRecommendationsEnabled },
            set: { model.setLocalRecommendationsEnabled($0) }))
        Text(
          "Uses bounded aggregate metrics only. Recommendations are never applied automatically."
        )
        .foregroundStyle(.secondary)
        LabeledContent(
          "Effective keys", value: "\(model.effectiveConfiguration.count)")
        LabeledContent(
          "Audit records", value: "\(model.configurationAuditCount)")
        ForEach(
          model.effectiveConfiguration.filter(\.differsFromDefault).prefix(8),
          id: \.key
        ) { entry in
          LabeledContent(entry.key, value: entry.value.displayValue)
            .accessibilityLabel(
              "\(entry.key), \(entry.value.displayValue), from \(entry.sourceLayer.rawValue)")
        }
        Button("Refresh Configuration Inspection") {
          model.refreshConfigurationInspection()
        }
      }
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 620, height: 600)
  }
}

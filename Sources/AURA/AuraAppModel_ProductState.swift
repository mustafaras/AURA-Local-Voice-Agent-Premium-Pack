import AppKit
import AuraAgent
import AuraConfig
import AuraCore
import AuraIntent
import AuraMemory
import AuraProductivity
import AuraStore
import Foundation

extension AuraAppModel {
  /// Localize a capability/integration disabled/degraded reason for the
  /// current UI language.
  ///
  /// The reason strings are produced by subsystem availability enums in
  /// English so they stay stable internal keys. This maps the known set to
  /// the selected language so the capability and integration panels are
  /// understandable in Turkish too, matching `displayStatusDetail`. Unknown
  /// reasons fall through unchanged rather than being guessed.
  func localizedReason(_ reason: String) -> String {
    guard productUIState.language == .turkish else { return reason }
    let map: [(String, String)] = [
      ("VS Code bridge degraded: ", "VS Code köprüsü kısıtlı: "),
      ("VS Code bridge disconnected: ", "VS Code köprüsü bağlantısı kesildi: "),
      ("VS Code bridge not authenticated: ", "VS Code köprüsü kimliği doğrulanmadı: "),
      ("VS Code bridge version mismatch: ", "VS Code köprüsü sürüm uyuşmazlığı: "),
      ("The Safari read bridge is not configured.", "Safari okuma köprüsü yapılandırılmadı."),
      ("Mail is not composed: ", "Posta oluşturulmadı: "),
      ("No mail account is approved yet.", "Henüz onaylanmış posta hesabı yok."),
      ("The mail adapter is not composed in this build.", "Bu sürümde posta bağdaştırıcısı yok."),
      (" is approved but not connected.", " onaylandı ancak bağlı değil."),
      ("The stored credential for ", "İçin saklanan kimlik bilgisi "),
      (" is no longer valid.", " artık geçerli değil."),
      ("Mail is unavailable: ", "Posta kullanılamıyor: "),
      (" reading is turned off in configuration.", " okuma yapılandırmada kapatıldı."),
      (" access has not been granted yet.", " erişimi henüz verilmedi."),
      (" access is denied for AURA.", " erişimi AURA için reddedildi."),
      (" reported an unrecognized authorization state.", " tanınmayan bir yetkilendirme durumu bildirdi."),
      ("Set productivity.calendarReadEnabled to enable calendar reads.",
       "calendarReadEnabled değerini etkinleştirin (Settings › Yapılandırma)."),
      ("Set productivity.contactsReadEnabled to enable contacts reads.",
       "contactsReadEnabled değerini etkinleştirin (Settings › Yapılandırma)."),
      ("Grant Calendar access, then macOS will ask you to confirm.",
       "Takvim erişimini verin; macOS onayınızı isteyecek."),
      ("Grant Contacts access, then macOS will ask you to confirm.",
       "Kişiler erişimini verin; macOS onayınızı isteyecek."),
      ("Allow AURA in System Settings › Privacy & Security › Calendars.",
       "Sistem Ayarları › Gizlilik ve Güvenlik › Takvimler'de AURA'ya izin verin."),
      ("Allow AURA in System Settings › Privacy & Security › Contacts.",
       "Sistem Ayarları › Gizlilik ve Güvenlik › Kişiler'de AURA'ya izin verin."),
      ("Re-check Calendar access in System Settings.",
       "Takvim erişimini Sistem Ayarları'ndan yeniden kontrol edin."),
      ("Re-check Contacts access in System Settings.",
       "Kişiler erişimini Sistem Ayarları'ndan yeniden kontrol edin."),
      ("Chrome bridge key store is unavailable", "Chrome köprüsü anahtar deposu kullanılamıyor"),
      ("Chrome bridge is not connected", "Chrome köprüsü bağlı değil"),
      ("Chrome extension or shared container is unavailable", "Chrome uzantısı veya paylaşılan kapsayıcı kullanılamıyor"),
      ("Chrome bridge observation is stale", "Chrome köprüsü gözlemi güncel değil"),
      ("Chrome bridge profile does not match the approved profile", "Chrome köprüsü profili onaylanan profille eşleşmiyor"),
      ("Chrome bridge authentication failed", "Chrome köprüsü kimlik doğrulaması başarısız"),
      ("Chrome extension sent a malformed observation", "Chrome uzantısı bozuk bir gözlem gönderdi"),
      ("Chrome bridge is unavailable", "Chrome köprüsü kullanılamıyor"),
      ("The Chrome read bridge is not configured.", "Chrome okuma köprüsü yapılandırılmadı."),
      ("Reinstall the bundled Chrome bridge.", "Paketli Chrome köprüsünü yeniden kurun."),
      ("Connect Chrome to pin the local extension key.", "Yerel uzantı anahtarını sabitlemek için Chrome'u bağlayın."),
      ("Enable AURA Chrome Read Bridge, then press Command-Shift-Y on a page.", "AURA Chrome Read Bridge'i etkinleştirin, sonra bir sayfada Komut-Shift-Y'ye basın."),
      ("the AURA Chrome extension has not published a key yet; "
       + "enable AURA Chrome Read Bridge, open a page, press Command-Shift-Y, then connect",
       "AURA Chrome uzantısı henüz anahtar yayınlamadı; uzantıyı etkinleştirin, "
       + "bir sayfa açıp Komut-Shift-Y'ye basın, sonra bağlayın"),
      ("the AURA Safari extension has not published a key yet; "
       + "open a page and click its toolbar button once, then connect",
       "AURA Safari uzantısı henüz anahtar yayınlamadı; Safari'de bir sayfa "
       + "açıp araç çubuğundaki AURA düğmesine bir kez basın, sonra tekrar bağlayın"),
      ("the AURA Safari extension has not published a key yet; "
       + "enable it in Safari Settings › Extensions, open a page, click its "
       + "toolbar button once, then connect",
       "AURA Safari uzantısı henüz anahtar yayınlamadı; Safari Ayarları › "
       + "Uzantılar'dan etkinleştirin, bir sayfa açıp AURA düğmesine bir kez "
       + "basın, sonra tekrar bağlayın"),
      ("Chrome connection failed: ", "Chrome bağlantısı başarısız: "),
      ("Gmail connection failed: ", "Gmail bağlantısı başarısız: "),
      ("Access request failed: ", "Erişim isteme başarısız: "),
      ("Enable failed: ", "Etkinleştirme başarısız: "),
      ("Disconnect failed: ", "Bağlantıyı kesme başarısız: "),
      ("Chrome connected; the read bridge is provisioned.",
       "Chrome bağlandı; okuma köprüsü sağlandı."),
      ("Opening the Gmail read-only authorization page.",
       "Gmail salt-okunur yetkilendirme sayfası açılıyor."),
      ("Gmail read-only integration connected.",
       "Gmail salt-okunur entegrasyonu bağlandı."),
      ("Calendar access granted.", "Takvim erişimi verildi."),
      ("Contacts access granted.", "Kişiler erişimi verildi."),
      ("Calendar access was not granted.", "Takvim erişimi verilmedi."),
      ("Contacts access was not granted.", "Kişiler erişimi verilmedi."),
      ("Calendar enabled; grant access when macOS asks.",
       "Takvim etkinleştirildi; macOS sorduğunda izin verin."),
      ("Contacts enabled; grant access when macOS asks.",
       "Kişiler etkinleştirildi; macOS sorduğunda izin verin."),
      ("If the toggle is on in System Settings, quit and reopen AURA once "
       + "to pick up screen observation.",
       "Sistem Ayarları'nda anahtar açıksa, ekran gözlemini almak için AURA'yı "
       + "bir kez kapatıp yeniden açın."),
      ("The Safari read bridge is not configured.", "Safari okuma köprüsü yapılandırılmadı."),
      ("Set a Safari profile and shared container path in configuration.",
       "Yapılandırmada Safari profili ve paylaşılan kapsayıcı yolu ayarlayın."),
      ("Connect the Safari profile in Setup to provision the bridge secret.",
       "Köprü gizli anahtarını sağlamak için Kurulum'da Safari profilini bağlayın."),
      ("Install and enable the AURA Safari extension, then open a page to read.",
       "AURA Safari uzantısını kurup etkinleştirin, sonra bir sayfa açın."),
      ("No mail account is approved yet.", "Henüz onaylanmış posta hesabı yok."),
      ("Approve a mail account in Setup, then connect it.",
       "Kurulum'da bir posta hesabını onaylayın, sonra bağlayın."),
      ("The mail adapter is not composed in this build.", "Bu sürümde posta bağdaştırıcısı yok."),
      ("Approve a mail account in configuration to compose the adapter.",
       "Bağdaştırıcıyı oluşturmak için yapılandırmada bir posta hesabı onaylayın."),
      ("Connect Gmail to store a read-only credential.",
       "Salt okunur kimlik bilgisi saklamak için Gmail'i bağlayın."),
      ("Reconnect Gmail to restore read-only access.",
       "Salt okunur erişimi geri yüklemek için Gmail'i yeniden bağlayın."),
      ("Choose which approved account AURA should read.",
       "AURA'nın okuyacağı onaylı hesabı seçin."),
      ("Correct the mail endpoint and allowed hosts in configuration.",
       "Yapılandırmada posta uç noktasını ve izinli ana makineleri düzeltin."),
      ("Retry once the credential store is reachable.",
       "Kimlik bilgisi deposuna erişilebilir olduğunda yeniden deneyin."),
    ]
    for (english, turkish) in map where reason.contains(english) {
      return reason.replacingOccurrences(of: english, with: turkish)
    }
    return reason
  }

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
      detail = AuraCopy.text("capabilities.ready", language: productUIState.language)
      isEnabled = true
    case .degraded(let reason):
      state = AuraCopy.text("capabilities.degraded", language: productUIState.language)
      detail = localizedReason(reason)
      isEnabled = false
    case .disabled(let reason):
      state = AuraCopy.text("capabilities.disabled", language: productUIState.language)
      detail = localizedReason(reason)
      isEnabled = false
    case nil:
      state = AuraCopy.text("capabilities.disabled", language: productUIState.language)
      detail = AuraCopy.text(
        "capabilities.noEvidence", language: productUIState.language)
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
      detail = localizedReason(reason)
    case .disabled(let reason):
      state = AuraCopy.text("integrations.notConnected", language: productUIState.language)
      detail = localizedReason(reason)
    }
    return AuraIntegrationRow(
      id: snapshot.capabilityID,
      title: title,
      state: state,
      detail: detail,
      remediation: localizedReason(snapshot.remediation),
      accountLabel: snapshot.accountLabel,
      isReady: snapshot.isReady,
      isRevocable: snapshot.isRevocable,
      canConnect: snapshot.canConnect,
      canGrantAccess: snapshot.canGrantAccess,
      canEnableInConfiguration: Self.canEnableInConfiguration(snapshot),
      canOpenSystemSettings: Self.settingsAnchor(for: snapshot) != nil,
      systemSettingsAnchor: Self.settingsAnchor(for: snapshot),
      canReconnect: Self.canReconnect(snapshot),
      needsMailApproval: Self.needsMailApproval(snapshot))
  }

  /// The mail row's "approve a mail account" remediation is only honest when
  /// the row offers the field that performs it. True exactly when the snapshot
  /// is the no-approved-account state.
  private static func needsMailApproval(
    _ snapshot: ProductivityIntegrationSnapshot
  ) -> Bool {
    snapshot.capabilityID == InitialCapabilitySet.mailRead.id
      && snapshot.remediation.contains("Approve a mail account")
  }

  /// A native leg whose adapters are simply not composed offers a Settings
  /// control; everything else keeps its snapshot-defined actions.
  private static func canEnableInConfiguration(
    _ snapshot: ProductivityIntegrationSnapshot
  ) -> Bool {
    guard snapshot.remediation.contains("productivity.") else { return false }
    return snapshot.capabilityID == InitialCapabilitySet.calendarRead.id
      || snapshot.capabilityID == InitialCapabilitySet.contactsLookup.id
  }

  /// The System Settings privacy pane that owns a denied TCC decision.
  private static func settingsAnchor(
    for snapshot: ProductivityIntegrationSnapshot
  ) -> String? {
    switch snapshot.capabilityID {
    case InitialCapabilitySet.calendarRead.id:
      return snapshot.remediation.contains("System Settings") ? "Calendars" : nil
    case InitialCapabilitySet.contactsLookup.id:
      return snapshot.remediation.contains("System Settings") ? "Contacts" : nil
    default:
      return nil
    }
  }

  /// An expired/revoked Gmail credential is one reconnection away, so the row
  /// offers the same OAuth flow the first connect uses. The check reads the
  /// *reason* (the snapshot's own English diagnostic key) rather than the
  /// remediation, so the flag cannot depend on which remediation sentence the
  /// surface happens to show.
  private static func canReconnect(_ snapshot: ProductivityIntegrationSnapshot) -> Bool {
    guard snapshot.capabilityID == InitialCapabilitySet.mailRead.id else { return false }
    if case .degraded(let reason) = snapshot.availability {
      return reason.contains("credential")
    }
    return false
  }

  /// Test-only passthrough of the private row projection. The projection
  /// rules are the product contract for "a blocked row is never a dead end",
  /// so the suite pins them exactly as the UI consumes them.
  func integrationRowForTesting(
    _ snapshot: ProductivityIntegrationSnapshot
  ) -> AuraIntegrationRow {
    integrationRow(snapshot)
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

  /// Pause a queued or running task. A failed pause leaves the task in its
  /// pre-pause state; the snapshot refresh reflects whatever the engine did.
  func pauseTask(_ id: UUID) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        try await kernel.taskPause(id: id)
        lastOperationMessage = "Task paused."
        refreshProductSnapshots()
      } catch {
        setError("Task pause failed: \(error.localizedDescription)")
      }
    }
  }

  func resumeTask(_ id: UUID) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        try await kernel.taskResume(id: id)
        lastOperationMessage = "Task resumed."
        refreshProductSnapshots()
      } catch {
        setError("Task resume failed: \(error.localizedDescription)")
      }
    }
  }

  /// Re-run a failed task once. The engine resets the failed task to pending
  /// without re-arming its retry budget, so repeated taps cannot silently turn
  /// an exhausted retry budget into a fresh one.
  func retryTask(_ id: UUID) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        try await kernel.taskRetry(id: id)
        lastOperationMessage = "Task retry requested."
        refreshProductSnapshots()
      } catch {
        setError("Task retry failed: \(error.localizedDescription)")
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
  /// Mail runs the user-present OAuth flow; Chrome provisions the
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
          // When the extension has never run, there is no key to pin and the
          // call would fail after its bounded retry window. Send the user to
          // the exact Safari settings pane FIRST so the enable step is one
          // click away, then connect (which waits up to ~9s for the toolbar
          // click to publish the key).
          if !(try await kernel.safariBridgeHasPublishedKey()) {
            lastOperationMessage =
              "Chrome açılıyor: AURA Chrome Read Bridge'i etkinleştirin, bir "
              + "sayfada Komut-Shift-Y'ye basın; bağlama kendiliğinden tamamlanacak."
            try await ChromeBridgeSetup.relaunchChromeForBridge()
          }
          _ = try await kernel.connectConfiguredBrowserProfile()
          lastOperationMessage = "Chrome connected; the read bridge is provisioned."
          refreshProductSnapshots()
        } catch {
          setError("Chrome connection failed: \(error.localizedDescription)")
        }
      }
    default:
      connectMailIntegration()
    }
  }

  /// Start the only user-facing Gmail enrollment path. Token material stays
  /// inside the kernel/coordinator and never enters this observable model.
  ///
  /// When no mailbox is approved yet, the row shows an inline approval field
  /// instead of this flow; `approveMailAccount` hands the address to the
  /// kernel first, and the OAuth connect runs immediately afterwards so the
  /// row goes from "not connected" to the provider consent page in one tap.
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

  /// Approve the address typed into the mail row's inline field, then start
  /// the OAuth connect. The address is held only long enough to validate and
  /// persist; it is never logged and the field clears either way.
  func approveAndConnectMail(address: String) {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    mailApprovalAddress = ""
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        try await kernel.approveMailAccount(address: trimmed)
        lastOperationMessage = "Mail account approved; opening the read-only authorization page."
        try await kernel.connectMailAccountViaOAuth()
        lastOperationMessage = "Gmail read-only integration connected."
        refreshProductSnapshots()
      } catch {
        setError("Gmail connection failed: \(error.localizedDescription)")
        refreshProductSnapshots()
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

  /// Compose a native leg whose configuration gate is off, from the row's
  /// button. The choice persists in the governed configuration store (user
  /// settings layer), so it survives restart, and the runtime recomposes so
  /// the row flips without a relaunch. A `notDetermined` authorization keeps
  /// the row actionable: the grant button appears next to it immediately.
  func enableIntegrationInConfiguration(_ row: AuraIntegrationRow) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        let key: String
        switch row.id {
        case InitialCapabilitySet.calendarRead.id:
          key = "calendarReadEnabled"
        case InitialCapabilitySet.contactsLookup.id:
          key = "contactsReadEnabled"
        default:
          throw AuraError.invalidConfiguration(
            "that integration has no configuration gate to enable")
        }
        try await kernel.setProductivityLegEnabled(key: key, enabled: true)
        lastOperationMessage = "\(row.title) enabled; grant access when macOS asks."
        refreshProductSnapshots()
      } catch {
        setError("Enable failed: \(error.localizedDescription)")
      }
    }
  }

  /// Open the System Settings pane that owns a denied native permission.
  func openNativeIntegrationSettings(anchor: String) {
    PermissionCoordinator.openPrivacySettings(anchor: anchor)
  }

  /// Turkish rendering of the operation/status messages this surface sets.
  /// The runtime strings stay English internal keys, exactly like
  /// `localizedReason` and `displayStatusDetail`; this maps the known set so
  /// the user's own language shows on the buttons' result line too.
  func localizedOperationMessage(_ message: String) -> String {
    guard productUIState.language == .turkish else { return message }
    for (english, turkish) in [
      ("Chrome connected; the read bridge is provisioned.",
       "Chrome bağlandı; okuma köprüsü sağlandı."),
      ("Gmail read-only integration connected.",
       "Gmail salt-okunur entegrasyonu bağlandı."),
      (" access granted.", " erişimi verildi."),
      (" access was not granted.", " erişimi verilmedi."),
      (" enabled; grant access when macOS asks.",
       " etkinleştirildi; macOS sorduğunda izin verin."),
    ] where message.contains(english) {
      return message.replacingOccurrences(of: english, with: turkish)
    }
    return message
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

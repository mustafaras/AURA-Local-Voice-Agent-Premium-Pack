import AuraCore
import Foundation

extension InitialCapabilitySet {
  private static let userSuppliedURLDomain =
    "any (user-supplied URL; browser-mediated, not a direct AURA network request)"

  static func vscodeObservationManifest(
    id: String,
    title: String,
    action: String,
    requiredCapability: Capability,
    output: String
  ) -> CapabilityManifest {
    CapabilityManifest(
      id: id,
      version: "1.0.0",
      presentation: CapabilityPresentation(
        titleByLocale: [.english: title, .turkish: title],
        descriptionByLocale: [
          .english: "Inspect " + action + " through the typed VS Code bridge.",
          .turkish: "Tipli VS Code köprüsü üzerinden " + action + " bilgisini inceler.",
        ]),
      inputSchemaDescription: "no arbitrary command text",
      outputSchemaDescription: output,
      owningAdapter: "VSCodeExtensionBridge",
      requiredCapability: requiredCapability,
      requiredExternalDependencies: ["authenticated VS Code extension bridge"],
      isIdempotent: true,
      executionBudget: CapabilityExecutionBudget(
        timeoutSeconds: 10, supportsCancellation: true, isRetryable: true),
      confirmationRule: "observation route; workspace and dirty-state checks still apply",
      verificationMethod: "typed bridge response freshness and protocol validation",
      rollbackStrategy: "not applicable — no side effects",
      sensitivity: .sensitive)
  }

  static func vscodeCommandManifest(
    id: String,
    title: String,
    action: String,
    requiredCapability: Capability,
    input: String
  ) -> CapabilityManifest {
    CapabilityManifest(
      id: id,
      version: "1.0.0",
      presentation: CapabilityPresentation(
        titleByLocale: [.english: title, .turkish: title],
        descriptionByLocale: [
          .english: "Run a named, bounded " + action + " through VS Code.",
          .turkish: "VS Code üzerinden adlandırılmış, sınırlandırılmış " + action + " çalıştırır.",
        ]),
      inputSchemaDescription: input + "; no arbitrary command text",
      outputSchemaDescription: "typed task/test outcome and normalized status",
      owningAdapter: "VSCodeExtensionBridge",
      requiredCapability: requiredCapability,
      requiredExternalDependencies: ["authenticated VS Code extension bridge"],
      isIdempotent: false,
      executionBudget: CapabilityExecutionBudget(
        timeoutSeconds: 120, supportsCancellation: true, isRetryable: false),
      confirmationRule: "reversible tier policy decision required",
      verificationMethod: "typed bridge outcome plus task/test diagnostics and exit status",
      rollbackStrategy:
        "cancellation is explicit; task/test side effects are not automatically rolled back",
      sensitivity: .sensitive)
  }

  public static let computerUseRun = CapabilityManifest(
    id: "computerUse.run", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Run Computer-Use Task", .turkish: "Bilgisayar Görevi Çalıştır"],
      descriptionByLocale: [
        .english: "Run a bounded computer-use objective against an approved, live-validated app.",
        .turkish:
          "Onaylanmış, canlı doğrulanmış bir uygulamaya karşı sınırlı bir "
          + "bilgisayar-kullanımı görevi çalıştırır.",
      ]),
    inputSchemaDescription: "appBundleIdentifier: String, objective: String",
    outputSchemaDescription:
      "bounded control-loop outcome (completed/no-progress/emergency-stopped/etc.)",
    owningAdapter: "ComputerUseControlLoop.run + DeterministicComputerUsePlanner",
    requiredCapability: .computerUseRun,
    sideEffects: [
      "drives a live UI within the approved app; blocked for unapproved apps by the beta allowlist"
    ],
    isIdempotent: false,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 120, supportsCancellation: true, isRetryable: false),
    confirmationRule: "mutation tier default (confirmation required unless granted); "
      + "mandatory-confirmation intents always require confirmation",
    verificationMethod:
      "ComputerUseVerifier semantic postconditions; a content-hash change alone is insufficient",
    rollbackStrategy:
      "none — computer-use actions are not automatically rolled back; emergency stop halts")

  public static let filesystemOpenFile = CapabilityManifest(
    id: "filesystem.open_file", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Open File", .turkish: "Dosya Aç"],
      descriptionByLocale: [
        .english: "Open a file with its default application.",
        .turkish: "Bir dosyayı varsayılan uygulamasıyla açar.",
      ]),
    inputSchemaDescription: "path: String",
    outputSchemaDescription: "opened path",
    owningAdapter: "not yet implemented",
    requiredCapability: .fileOpen,
    sideEffects: ["launches the file's default application"],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 10, supportsCancellation: false, isRetryable: true),
    confirmationRule: "reversible tier default (no mandatory confirmation)",
    verificationMethod: "not yet implemented",
    rollbackStrategy: "not applicable")

  public static let filesystemOpenFolder = CapabilityManifest(
    id: "filesystem.open_folder", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Open Folder", .turkish: "Klasör Aç"],
      descriptionByLocale: [
        .english: "Open a folder in Finder.", .turkish: "Bir klasörü Finder'da açar.",
      ]),
    inputSchemaDescription: "path: String",
    outputSchemaDescription: "opened path",
    owningAdapter: "not yet implemented",
    requiredCapability: .fileOpen,
    sideEffects: ["opens a Finder window"],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 10, supportsCancellation: false, isRetryable: true),
    confirmationRule: "reversible tier default (no mandatory confirmation)",
    verificationMethod: "not yet implemented",
    rollbackStrategy: "not applicable")

  public static let filesystemReveal = CapabilityManifest(
    id: "filesystem.reveal", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Reveal in Finder", .turkish: "Finder'da Göster"],
      descriptionByLocale: [
        .english: "Reveal a file or folder in Finder, selected.",
        .turkish: "Bir dosyayı veya klasörü Finder'da seçili olarak gösterir.",
      ]),
    inputSchemaDescription: "path: String",
    outputSchemaDescription: "revealed path",
    owningAdapter: "not yet implemented",
    requiredCapability: .fileReveal,
    sideEffects: ["opens a Finder window with the item selected"],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 10, supportsCancellation: false, isRetryable: true),
    confirmationRule: "reversible tier default (no mandatory confirmation)",
    verificationMethod: "not yet implemented",
    rollbackStrategy: "not applicable")

  public static let urlOpen = CapabilityManifest(
    id: "url.open", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Open URL", .turkish: "Bağlantı Aç"],
      descriptionByLocale: [
        .english: "Open a URL in the default browser.",
        .turkish: "Bir bağlantıyı varsayılan tarayıcıda açar.",
      ]),
    inputSchemaDescription: "url: String",
    outputSchemaDescription: "opened URL",
    owningAdapter: "not yet implemented",
    requiredCapability: .urlOpen,
    sideEffects: ["launches the default web browser"],
    requiredNetworkDomains: [userSuppliedURLDomain],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 10, supportsCancellation: false, isRetryable: true),
    confirmationRule: "reversible tier default (no mandatory confirmation)",
    verificationMethod: "not yet implemented",
    rollbackStrategy: "not applicable")

  public static let browserRead = CapabilityManifest(
    id: "browser.read", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Read Browser Page", .turkish: "Tarayıcı Sayfasını Oku"],
      descriptionByLocale: [
        .english:
          "Read the approved Safari profile's active visible page through a structured bridge.",
        .turkish: "Onaylı Safari profilindeki görünür sayfayı yapılandırılmış köprüyle okur.",
      ]),
    inputSchemaDescription: "approvedProfileID: String",
    outputSchemaDescription: "tab metadata and bounded untrusted visible page text",
    owningAdapter: "SafariBrowserReadAdapter",
    requiredCapability: .browserRead,
    requiredExternalDependencies: ["Safari Web Extension native-messaging bridge"],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 15, supportsCancellation: true, isRetryable: true),
    confirmationRule:
      "never required for read-only observation; profile/domain scope still applies",
    verificationMethod: "bridge response profile ID and HTTPS host match the approved scope",
    rollbackStrategy: "not applicable — no side effects",
    sensitivity: .sensitive)

  public static let mailRead = CapabilityManifest(
    id: "mail.read", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Read Mail", .turkish: "Postaları Oku"],
      descriptionByLocale: [
        .english: "Read approved mail metadata and message bodies with read-only provider scope.",
        .turkish: "Onaylı postaların üstbilgi ve gövdelerini yalnızca okuma kapsamıyla okur.",
      ]),
    inputSchemaDescription: "approvedAccountID: String, query: String?",
    outputSchemaDescription: "bounded mail headers/thread content with provenance",
    owningAdapter: "GmailReadAdapter",
    requiredCapability: .mailRead,
    requiredGrantCapabilities: [.mailRead],
    requiredNetworkDomains: ["gmail.googleapis.com"],
    requiredExternalDependencies: ["OAuth read-only token in Keychain"],
    locality: .cloud,
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 20, supportsCancellation: true, isRetryable: true),
    confirmationRule:
      "never required for read-only observation; account scope and privacy policy apply",
    verificationMethod: "provider response is bound to the approved account and read-only scope",
    rollbackStrategy: "not applicable — no side effects",
    sensitivity: .sensitive)

  public static let calendarRead = CapabilityManifest(
    id: "calendar.read", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Read Calendar", .turkish: "Takvimi Oku"],
      descriptionByLocale: [
        .english: "Read events and conflicts from explicitly authorized calendars.",
        .turkish: "Açıkça yetkilendirilmiş takvimlerdeki etkinlikleri ve çakışmaları okur.",
      ]),
    inputSchemaDescription: "start: Date, end: Date, calendarIDs: Set<String> optional",
    outputSchemaDescription: "bounded calendar events with time-zone and provenance metadata",
    owningAdapter: "EventKitCalendarReadAdapter",
    requiredCapability: .calendarRead,
    requiredGrantCapabilities: [.calendarRead],
    requiredExternalDependencies: ["EventKit full event read authorization"],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 15, supportsCancellation: true, isRetryable: true),
    confirmationRule:
      "never required for read-only observation; authorization remains user-controlled",
    verificationMethod: "EventKit event identifiers and requested range are returned",
    rollbackStrategy: "not applicable — no side effects",
    sensitivity: .sensitive)

  public static let contactsLookup = CapabilityManifest(
    id: "contacts.lookup", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Find Contact", .turkish: "Kişi Bul"],
      descriptionByLocale: [
        .english: "Resolve only the contact candidates needed for the current request.",
        .turkish: "Yalnızca mevcut istek için gereken kişi adaylarını çözer.",
      ]),
    inputSchemaDescription: "query: String, limit: Int optional",
    outputSchemaDescription: "bounded candidate list; ties require clarification",
    owningAdapter: "ContactsFrameworkLookupAdapter",
    requiredCapability: .contactsLookup,
    requiredGrantCapabilities: [.contactsLookup],
    requiredExternalDependencies: ["Contacts limited/full read authorization"],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 10, supportsCancellation: true, isRetryable: true),
    confirmationRule: "never required for candidate lookup; full address book is never exposed",
    verificationMethod: "candidate identifiers and bounded result count are returned",
    rollbackStrategy: "not applicable — no side effects",
    sensitivity: .sensitive)
}

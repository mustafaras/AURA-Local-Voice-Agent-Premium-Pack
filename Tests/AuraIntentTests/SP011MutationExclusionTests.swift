import AuraCore
import AuraIntent
import Foundation
import Testing

/// SP-011's completion gate allows mutation and send to be "explicitly
/// excluded" rather than evidenced. Every prior record states that AURA has no
/// compose, send, event-creation, or contact-write path — but an absence
/// recorded in prose decays silently. These cases turn that absence into an
/// assertion, so the exclusion cannot quietly stop being true.
///
/// This is deliberately structural rather than a source-text scan: it pins the
/// properties a mutation path would necessarily have to change.
@Suite("SP-011 mutation and send are excluded by construction")
struct SP011MutationExclusionTests {
  /// Domains covered by the R5 read-first matrix.
  private static let productivityDomains = ["browser", "mail", "calendar", "contacts"]

  /// Vocabulary a compose, send, or write path would have to introduce.
  private static let mutationMarkers = [
    "send", "compose", "draft", "create", "write", "update", "delete",
    "reply", "forward", "archive", "move", "trash",
  ]

  private static func isProductivity(_ category: IntentSemanticCategory) -> Bool {
    let name = category.rawValue.lowercased()
    return productivityDomains.contains { name.hasPrefix($0) }
  }

  /// The classifier can only produce what the category enum names. If a
  /// `mailSend` or `calendarCreate` case appears, this fails before any live
  /// record can claim mutation is excluded.
  @Test("no productivity semantic category names a mutation")
  func noProductivityCategoryNamesAMutation() {
    let offenders = IntentSemanticCategory.allCases
      .filter(Self.isProductivity)
      .filter { category in
        let name = category.rawValue.lowercased()
        return Self.mutationMarkers.contains { name.contains($0) }
      }
    #expect(offenders.isEmpty, "productivity categories must stay read-only: \(offenders)")
  }

  /// Every productivity category is observation tier. A path that changed a
  /// provider's state could not honestly stay here, so the tier is the
  /// invariant that a send path would be forced to break.
  @Test("every productivity category stays at observation risk")
  func productivityCategoriesAreObservationTier() {
    for category in IntentSemanticCategory.allCases where Self.isProductivity(category) {
      #expect(category.riskTier == .observation)
      #expect(!category.requiresMandatoryConfirmation)
    }
  }

  /// The four registered manifests are the whole R5 surface. Each declares no
  /// side effects and is idempotent — the two claims a send capability cannot
  /// make.
  @Test(
    "every registered productivity capability declares no side effects",
    arguments: [
      InitialCapabilitySet.browserRead,
      InitialCapabilitySet.mailRead,
      InitialCapabilitySet.calendarRead,
      InitialCapabilitySet.contactsLookup,
    ])
  func productivityCapabilitiesAreSideEffectFree(manifest: CapabilityManifest) {
    #expect(manifest.isIdempotent)
    let rollback = manifest.rollbackStrategy.lowercased()
    #expect(rollback.contains("no side effects") || rollback.contains("not applicable"))
    let id = manifest.id.lowercased()
    #expect(!Self.mutationMarkers.contains { id.contains($0) })
  }

  /// The free-window addition must not have widened anything: it is a second
  /// shape of answer over the same capability, so `calendar.read` still owns
  /// it and still declares no side effects.
  @Test("free windows did not add a capability or a grant")
  func freeWindowsReuseTheCalendarReadCapability() {
    let calendar = InitialCapabilitySet.calendarRead
    #expect(calendar.id == "calendar.read")
    #expect(calendar.requiredGrantCapabilities == [.calendarRead])
    #expect(calendar.rollbackStrategy.lowercased().contains("not applicable"))
  }
}

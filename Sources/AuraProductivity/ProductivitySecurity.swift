import AuraCore
import AuraSecurity
import Foundation

/// External content is typed as data with non-authoritative provenance. The
/// classifier result is retained for UI/audit decisions, but no verdict can
/// turn external content into an instruction or policy grant.
public struct ExternalContent: Sendable, Equatable {
  public let sourceID: String
  public let text: String
  public let provenance: ContentProvenance
  public let injectionVerdict: InjectionVerdict

  public init(
    sourceID: String,
    text: String,
    provenance: ContentProvenance,
    classifier: PromptInjectionClassifier = PromptInjectionClassifier()
  ) {
    self.sourceID = sourceID
    self.text = text
    self.provenance = provenance
    self.injectionVerdict = classifier.classify(text, provenance: provenance)
  }

  public var carriesAuthority: Bool { false }

  /// External content may be summarized only as bounded data. It can never
  /// authorize a capability, change a target, approve a confirmation, request
  /// a secret, or choose recipients.
  public var mayInfluenceAction: Bool { false }

  public var isBlocked: Bool { injectionVerdict.isBlocked }
}
/// Deny-by-default URL policy for provider calls and structured browser
/// bridges. Redirects are validated with the same allowlist before following.
public struct ProductivityNetworkPolicy: Sendable, Equatable {
  public let allowlist: NetworkAllowlist
  public let requireHTTPS: Bool

  public init(allowlist: NetworkAllowlist, requireHTTPS: Bool = true) {
    self.allowlist = allowlist
    self.requireHTTPS = requireHTTPS
  }

  public func validate(_ url: URL, isRedirect: Bool = false) throws(ProductivityError) {
    guard let scheme = url.scheme?.lowercased(),
      (!requireHTTPS || scheme == "https")
    else {
      throw .invalidInput("provider URL must use HTTPS")
    }
    guard let host = url.host?.lowercased(), !host.isEmpty else {
      throw .invalidInput("provider URL must contain a host")
    }
    guard allowlist.isAllowed(host: host) else {
      throw isRedirect ? .invalidRedirect(host: host) : .hostNotAllowed(host: host)
    }
  }
}

public struct CalendarTimeRange: Sendable, Equatable {
  public let start: Date
  public let end: Date

  public init(start: Date, end: Date) throws(ProductivityError) {
    guard end > start else {
      throw .invalidInput("calendar event end must be after start")
    }
    self.start = start
    self.end = end
  }

  public func overlaps(_ other: CalendarTimeRange) -> Bool {
    start < other.end && other.start < end
  }
}

public enum CalendarConflictDetector {
  public static func conflicts(
    candidate: CalendarTimeRange,
    existing: [CalendarTimeRange]
  ) -> Bool {
    existing.contains { candidate.overlaps($0) }
  }
}

/// Contact and attendee resolution is deliberately candidate-based. The
/// complete address book never becomes a model input.
public struct ContactCandidate: Sendable, Equatable, Identifiable {
  public let id: String
  public let displayName: ExternalContent
  public let emailAddresses: [String]
  public let phoneNumbers: [String]

  public init(
    id: String,
    displayName: ExternalContent,
    emailAddresses: [String] = [],
    phoneNumbers: [String] = []
  ) {
    self.id = id
    self.displayName = displayName
    self.emailAddresses = emailAddresses
    self.phoneNumbers = phoneNumbers
  }
}

public struct ScopedContactResolution: Sendable, Equatable {
  public let query: String
  public let candidates: [ContactCandidate]

  public init(query: String, candidates: [ContactCandidate]) {
    self.query = query
    self.candidates = candidates
  }

  public var requiresClarification: Bool { candidates.count > 1 }

  public func uniqueCandidate() throws(ProductivityError) -> ContactCandidate {
    guard candidates.count == 1, let candidate = candidates.first else {
      throw .accountAmbiguous(candidates: candidates.map(\.id))
    }
    return candidate
  }
}

public struct AttachmentMetadata: Sendable, Equatable, Identifiable {
  public let id: String
  public let filename: String
  public let byteCount: Int
  public let contentType: String?

  public init(id: String, filename: String, byteCount: Int, contentType: String?) {
    self.id = id
    self.filename = filename
    self.byteCount = byteCount
    self.contentType = contentType
  }
}

/// Read-first attachment guard. It validates metadata only; downloading or
/// attaching bytes remains a separate, user-approved mutation flow.
public struct AttachmentPolicy: Sendable, Equatable {
  public let maximumBytes: Int
  public let allowedContentTypes: Set<String>

  public init(
    maximumBytes: Int = 10 * 1024 * 1024,
    allowedContentTypes: Set<String> = ["application/pdf", "text/plain", "image/png", "image/jpeg"]
  ) {
    self.maximumBytes = maximumBytes
    self.allowedContentTypes = allowedContentTypes
  }

  public func validate(_ metadata: AttachmentMetadata) throws(ProductivityError) {
    guard metadata.byteCount >= 0, metadata.byteCount <= maximumBytes else {
      throw .privacyBlocked(reason: "attachment exceeds the approved size")
    }
    if let contentType = metadata.contentType, !allowedContentTypes.contains(contentType) {
      throw .privacyBlocked(reason: "attachment type is not approved")
    }
  }
}

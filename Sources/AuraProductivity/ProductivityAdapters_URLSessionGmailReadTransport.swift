import AuraCore
import AuraSecurity
import Foundation

/// Gmail REST v1 read-only wire types. Only the fields the read-first slice
/// actually consumes are decoded; anything else the provider sends is
/// discarded rather than carried into the app.
private struct GmailProfileResponse: Decodable {
  let emailAddress: String
  let messagesTotal: Int?
}

private struct GmailListResponse: Decodable {
  struct Reference: Decodable {
    let id: String
    let threadId: String?
  }
  let messages: [Reference]?
  let resultSizeEstimate: Int?
}

private struct GmailMessageResponse: Decodable {
  struct Header: Decodable {
    let name: String
    let value: String
  }
  struct Body: Decodable {
    let size: Int?
    let data: String?
    let attachmentId: String?
  }
  struct Part: Decodable {
    let filename: String?
    let mimeType: String?
    let headers: [Header]?
    let body: Body?
    let parts: [Part]?
  }
  let id: String
  let threadId: String
  let labelIds: [String]?
  let snippet: String?
  let internalDate: String?
  let payload: Part?
}

private struct GmailThreadResponse: Decodable {
  let messages: [GmailMessageResponse]?
}

/// The production Gmail read transport.
///
/// Everything about it is read-only by construction: only `GET` requests
/// exist, the paths are fixed constants rather than caller-supplied strings,
/// and there is no method that could send, modify, label, or delete. A
/// compose or send scope could not be exercised through this type even if a
/// token somehow carried one.
///
/// The transport does not decide *whether* it may run. `GmailReadAdapter`
/// owns account resolution, scope validation, and injection screening, and
/// this type is reached only after those pass.
///
/// Limitation, stated rather than implied: no live provider call has been
/// made against this code. SP-010's authority excludes contacting providers,
/// so its behavior is proven against recorded payloads through the
/// `HTTPProviderFetching` seam; the live leg belongs to SP-011.
public struct URLSessionGmailReadTransport: GmailReadTransport {
  public let endpoint: URL
  private let client: ProviderHTTPClient
  private let maximumBodyCharacters: Int

  public init(
    endpoint: URL = URL(string: "https://gmail.googleapis.com/gmail/v1")!,
    fetcher: any HTTPProviderFetching,
    networkPolicy: ProductivityNetworkPolicy,
    maximumBodyCharacters: Int = 4_000
  ) throws(ProductivityError) {
    // The host check is duplicated here on purpose: `GmailReadAdapter` also
    // checks it, and a transport constructible against another host would be
    // one composition-root mistake away from shipping.
    guard endpoint.host?.lowercased() == "gmail.googleapis.com" else {
      throw .hostNotAllowed(host: endpoint.host ?? "missing")
    }
    try networkPolicy.validate(endpoint)
    self.endpoint = endpoint
    self.client = ProviderHTTPClient(fetcher: fetcher, networkPolicy: networkPolicy)
    self.maximumBodyCharacters = maximumBodyCharacters
  }

  public func accounts(accessToken: String) async throws -> [MailAccountSnapshot] {
    let data = try await client.get(
      url: endpoint.appendingPathComponent("users/me/profile"), accessToken: accessToken)
    let profile = try Self.decode(GmailProfileResponse.self, from: data)
    return [
      MailAccountSnapshot(
        id: profile.emailAddress,
        displayName: ProductivityRedaction.displayLabel(profile.emailAddress),
        provider: .gmail)
    ]
  }

  public func unreadCount(accountID: String, accessToken: String) async throws -> Int {
    let data = try await client.get(
      url: endpoint.appendingPathComponent("users/me/messages"),
      accessToken: accessToken,
      queryItems: [
        URLQueryItem(name: "q", value: "is:unread"),
        URLQueryItem(name: "maxResults", value: "1"),
      ])
    let list = try Self.decode(GmailListResponse.self, from: data)
    return list.resultSizeEstimate ?? (list.messages?.count ?? 0)
  }

  public func search(
    accountID: String,
    query: String,
    limit: Int,
    accessToken: String
  ) async throws -> [GmailRawMessage] {
    let data = try await client.get(
      url: endpoint.appendingPathComponent("users/me/messages"),
      accessToken: accessToken,
      queryItems: [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "maxResults", value: String(limit)),
      ])
    let list = try Self.decode(GmailListResponse.self, from: data)
    var messages: [GmailRawMessage] = []
    for reference in list.messages ?? [] {
      messages.append(try await message(id: reference.id, accessToken: accessToken))
    }
    return messages
  }

  public func thread(
    accountID: String,
    threadID: String,
    accessToken: String
  ) async throws -> [GmailRawMessage] {
    let data = try await client.get(
      url: endpoint.appendingPathComponent("users/me/threads/\(threadID)"),
      accessToken: accessToken,
      queryItems: [URLQueryItem(name: "format", value: "full")])
    let thread = try Self.decode(GmailThreadResponse.self, from: data)
    return (thread.messages ?? []).map(convert)
  }

  private func message(id: String, accessToken: String) async throws -> GmailRawMessage {
    let data = try await client.get(
      url: endpoint.appendingPathComponent("users/me/messages/\(id)"),
      accessToken: accessToken,
      queryItems: [URLQueryItem(name: "format", value: "full")])
    return convert(try Self.decode(GmailMessageResponse.self, from: data))
  }

  // MARK: - Wire → domain

  private func convert(_ response: GmailMessageResponse) -> GmailRawMessage {
    let headers = Self.headers(in: response.payload)
    let body =
      Self.plainTextBody(of: response.payload, limit: maximumBodyCharacters)
      ?? response.snippet ?? ""
    return GmailRawMessage(
      id: response.id,
      threadID: response.threadId,
      sender: headers["from"] ?? "",
      recipients: Self.split(headers["to"]),
      subject: headers["subject"] ?? "",
      body: String(body.prefix(maximumBodyCharacters)),
      receivedAt: Self.date(fromEpochMilliseconds: response.internalDate),
      isUnread: response.labelIds?.contains("UNREAD") ?? false,
      attachments: Self.attachments(in: response.payload))
  }

  private static func headers(in part: GmailMessageResponse.Part?) -> [String: String] {
    var result: [String: String] = [:]
    for header in part?.headers ?? [] {
      result[header.name.lowercased()] = header.value
    }
    return result
  }

  /// Gmail nests bodies in a MIME part tree. Only `text/plain` is read: HTML
  /// would have to be sanitized before it could be shown or summarized, and
  /// this slice reads rather than renders.
  private static func plainTextBody(of part: GmailMessageResponse.Part?, limit: Int) -> String? {
    guard let part else { return nil }
    if part.mimeType == "text/plain", let encoded = part.body?.data,
      let decoded = decodeBase64URL(encoded)
    {
      return String(decoded.prefix(limit))
    }
    for child in part.parts ?? [] {
      if let found = plainTextBody(of: child, limit: limit) { return found }
    }
    return nil
  }

  private static func attachments(
    in part: GmailMessageResponse.Part?
  ) -> [AttachmentMetadata] {
    guard let part else { return [] }
    var result: [AttachmentMetadata] = []
    if let filename = part.filename, !filename.isEmpty, let id = part.body?.attachmentId {
      result.append(
        AttachmentMetadata(
          id: id, filename: filename, byteCount: part.body?.size ?? 0,
          contentType: part.mimeType))
    }
    for child in part.parts ?? [] {
      result.append(contentsOf: attachments(in: child))
    }
    return result
  }

  /// Gmail encodes bodies with the URL-safe base64 alphabet and strips
  /// padding; `Data(base64Encoded:)` accepts neither, so both are restored
  /// before decoding. An undecodable body yields `nil` and the caller falls
  /// back to the snippet rather than surfacing raw bytes.
  private static func decodeBase64URL(_ value: String) -> String? {
    var normalized =
      value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = normalized.count % 4
    if remainder > 0 {
      normalized += String(repeating: "=", count: 4 - remainder)
    }
    guard let data = Data(base64Encoded: normalized) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func split(_ value: String?) -> [String] {
    guard let value else { return [] }
    return
      value
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func date(fromEpochMilliseconds value: String?) -> Date {
    guard let value, let milliseconds = Double(value) else { return Date(timeIntervalSince1970: 0) }
    return Date(timeIntervalSince1970: milliseconds / 1000)
  }

  /// A malformed provider payload is `providerUnavailable`, not a crash and
  /// not a half-built message: decoding failures never produce a partially
  /// populated snapshot the dialogue layer could quote as fact.
  private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      throw ProductivityError.providerUnavailable
    }
  }
}

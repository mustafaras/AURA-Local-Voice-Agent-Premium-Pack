import AuraCore
import CryptoKit
import Darwin
import Foundation

private final class PluginProcessWaiter: @unchecked Sendable {
  private let lock = NSLock()
  private var completed = false
  private var continuation: CheckedContinuation<Void, Never>?

  func signal() {
    lock.lock()
    completed = true
    let pending = continuation
    continuation = nil
    lock.unlock()
    pending?.resume()
  }

  func wait() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if completed {
        lock.unlock()
        continuation.resume()
      } else {
        self.continuation = continuation
        lock.unlock()
      }
    }
  }
}

private final class PluginOutputCollector: @unchecked Sendable {
  private let lock = NSLock()
  private let limit: Int
  private var data = Data()
  private var exceeded = false

  init(limit: Int) {
    self.limit = limit
  }

  func append(_ chunk: Data) {
    guard !chunk.isEmpty else { return }
    lock.lock()
    if data.count + chunk.count > limit {
      exceeded = true
    } else if !exceeded {
      data.append(chunk)
    }
    lock.unlock()
  }

  func result() -> (data: Data, exceeded: Bool) {
    lock.lock()
    let result = (data, exceeded)
    lock.unlock()
    return result
  }
}

public struct PluginRuntimeRequest: Codable, Sendable, Equatable {
  public static let protocolVersion = 1
  public let protocolVersion: Int
  public let pluginID: String
  public let pluginVersion: String
  public let capability: Capability
  public let target: PolicyTarget
  public let payload: Data
  public let nonce: UUID

  public init(
    pluginID: String,
    pluginVersion: String,
    capability: Capability,
    target: PolicyTarget,
    payload: Data,
    nonce: UUID = UUID()
  ) {
    self.protocolVersion = Self.protocolVersion
    self.pluginID = pluginID
    self.pluginVersion = pluginVersion
    self.capability = capability
    self.target = target
    self.payload = payload
    self.nonce = nonce
  }
}

public struct PluginRuntimeResponse: Codable, Sendable, Equatable {
  public let protocolVersion: Int
  public let nonce: UUID
  public let sandboxAttested: Bool
  public let output: Data

  public init(
    protocolVersion: Int = PluginRuntimeRequest.protocolVersion,
    nonce: UUID,
    sandboxAttested: Bool,
    output: Data
  ) {
    self.protocolVersion = protocolVersion
    self.nonce = nonce
    self.sandboxAttested = sandboxAttested
    self.output = output
  }
}

/// Injected boundary for an AURA-owned, separately sandboxed helper.
public protocol PluginRuntimeHosting: Sendable {
  func execute(
    manifest: PluginManifest,
    artifactURL: URL,
    request: PluginRuntimeRequest
  ) async throws(AuraError) -> PluginRuntimeResponse
}

/// Production helper-process transport. The helper itself is fixed and
/// digest-pinned; plugin bytes are passed as an argument and never loaded in
/// AURA's process. A response without protocol/nonce/sandbox attestation is
/// rejected.
public struct PluginHelperProcessHost: PluginRuntimeHosting {
  private let helperURL: URL
  private let expectedHelperSHA256Hex: String
  private let maximumResponseBytes: Int
  private let executionTimeoutSeconds: TimeInterval

  public init(
    helperURL: URL,
    expectedHelperSHA256Hex: String,
    maximumResponseBytes: Int = 1_048_576,
    executionTimeoutSeconds: TimeInterval = 30
  ) throws(AuraError) {
    guard expectedHelperSHA256Hex.count == 64,
      expectedHelperSHA256Hex == expectedHelperSHA256Hex.lowercased(),
      expectedHelperSHA256Hex.allSatisfy(\.isHexDigit),
      maximumResponseBytes > 0,
      executionTimeoutSeconds > 0
    else {
      throw AuraError.invalidConfiguration("invalid plugin helper integrity configuration")
    }
    self.helperURL = helperURL
    self.expectedHelperSHA256Hex = expectedHelperSHA256Hex.lowercased()
    self.maximumResponseBytes = maximumResponseBytes
    self.executionTimeoutSeconds = executionTimeoutSeconds
  }

  public func execute(
    manifest: PluginManifest,
    artifactURL: URL,
    request: PluginRuntimeRequest
  ) async throws(AuraError) -> PluginRuntimeResponse {
    guard let helperData = try? Data(contentsOf: helperURL),
      PluginArtifactStore.sha256Hex(helperData) == expectedHelperSHA256Hex
    else {
      throw AuraError.pluginError("plugin helper is missing or failed integrity verification")
    }
    let envelope = PluginHelperEnvelope(
      manifest: manifest, artifactPath: artifactURL.path, request: request)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let input: Data
    do {
      input = try encoder.encode(envelope)
    } catch {
      throw AuraError.serializationError("unable to encode plugin helper request")
    }

    let process = Process()
    let standardInput = Pipe()
    let standardOutput = Pipe()
    let collector = PluginOutputCollector(limit: maximumResponseBytes)
    standardOutput.fileHandleForReading.readabilityHandler = { handle in
      collector.append(handle.availableData)
    }
    defer { standardOutput.fileHandleForReading.readabilityHandler = nil }
    process.executableURL = helperURL
    process.arguments = []
    process.environment = ["PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"]
    process.standardInput = standardInput
    process.standardOutput = standardOutput
    process.standardError = FileHandle.nullDevice
    let waiter = PluginProcessWaiter()
    process.terminationHandler = { _ in waiter.signal() }
    do {
      try process.run()
      standardInput.fileHandleForWriting.write(input)
      try standardInput.fileHandleForWriting.close()
    } catch {
      throw AuraError.pluginError("plugin helper launch failed: \(error.localizedDescription)")
    }
    let completed = await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        await waiter.wait()
        return true
      }
      group.addTask {
        let nanoseconds = UInt64(executionTimeoutSeconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
        return false
      }
      let first = await group.next() ?? false
      group.cancelAll()
      return first
    }
    if !completed {
      process.terminate()
      kill(process.processIdentifier, SIGKILL)
      throw AuraError.pluginError("plugin helper exceeded execution timeout")
    }
    standardOutput.fileHandleForReading.readabilityHandler = nil
    collector.append(standardOutput.fileHandleForReading.readDataToEndOfFile())
    let collected = collector.result()
    guard process.terminationStatus == 0, !collected.exceeded else {
      throw AuraError.pluginError("plugin helper failed or exceeded response limit")
    }
    let response: PluginRuntimeResponse
    do {
      response = try JSONDecoder().decode(PluginRuntimeResponse.self, from: collected.data)
    } catch {
      throw AuraError.pluginError("plugin helper returned an invalid response")
    }
    guard response.protocolVersion == PluginRuntimeRequest.protocolVersion,
      response.nonce == request.nonce,
      response.sandboxAttested
    else {
      throw AuraError.pluginError("plugin helper protocol or sandbox attestation failed")
    }
    return response
  }
}

public struct PluginHelperEnvelope: Codable, Sendable, Equatable {
  public let manifest: PluginManifest
  public let artifactPath: String
  public let request: PluginRuntimeRequest

  public init(manifest: PluginManifest, artifactPath: String, request: PluginRuntimeRequest) {
    self.manifest = manifest
    self.artifactPath = artifactPath
    self.request = request
  }
}

/// Shared client/helper allowlist evaluator. Every constrained manifest
/// pattern must be satisfied, matching `PolicyEngine`'s grant semantics.
public enum PluginRuntimeAllowlist {
  public static func allows(_ target: PolicyTarget, manifest: PluginManifest) -> Bool {
    if let appID = target.appID, !manifest.supportedApplicationBundleIDs.contains(appID) {
      return false
    }
    if let host = target.networkHost,
      !manifest.networkDomains.contains(where: { host == $0 || host.hasSuffix("." + $0) })
    {
      return false
    }
    return manifest.requiredPermissions.allSatisfy { pattern in
      switch pattern {
      case .any:
        return false
      case .appID(let value):
        return target.appID == value
      case .filePath(let glob):
        guard let path = target.filePath else { return false }
        return matchesGlob(path, pattern: glob)
      case .directory(let directory, let recursive):
        guard let path = target.filePath ?? target.directoryPath else { return false }
        guard path == directory || path.hasPrefix(directory + "/") else { return false }
        return recursive || !String(path.dropFirst(directory.count + 1)).contains("/")
      case .command(let regex):
        guard let command = target.command else { return false }
        return command.range(of: regex, options: .regularExpression) != nil
      case .argument(let allowed):
        return Set(target.arguments).isSubset(of: allowed)
      case .environment(let keys):
        return Set(target.environmentKeys).isSubset(of: keys)
      case .network(let host, let ports):
        guard let targetHost = target.networkHost, matchesGlob(targetHost, pattern: host) else {
          return false
        }
        return target.networkPort.map(ports.contains) ?? true
      }
    }
  }

  private static func matchesGlob(_ value: String, pattern: String) -> Bool {
    let escaped = NSRegularExpression.escapedPattern(for: pattern)
      .replacingOccurrences(of: "\\*", with: ".*")
      .replacingOccurrences(of: "\\?", with: ".")
    return value.range(of: "^\(escaped)$", options: .regularExpression) != nil
  }
}

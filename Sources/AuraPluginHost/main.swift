import AuraCore
import AuraPlugins
import Darwin
import Foundation
import Security

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(EXIT_FAILURE)
}

private func sandboxIsEnabled() -> Bool {
  guard let task = SecTaskCreateFromSelf(nil) else { return false }
  let value = SecTaskCopyValueForEntitlement(
    task, "com.apple.security.app-sandbox" as CFString, nil)
  return (value as? Bool) == true
}

private final class BoundedOutputCollector: @unchecked Sendable {
  private let lock = NSLock()
  private var data = Data()
  private var exceeded = false

  func append(_ chunk: Data) {
    guard !chunk.isEmpty else { return }
    lock.lock()
    if data.count + chunk.count > 1_048_576 {
      exceeded = true
    } else if !exceeded {
      data.append(chunk)
    }
    lock.unlock()
  }

  func result() -> (Data, Bool) {
    lock.lock()
    let result = (data, exceeded)
    lock.unlock()
    return result
  }
}

guard sandboxIsEnabled() else {
  fail("AuraPluginHost refuses to run without the App Sandbox entitlement")
}

if CommandLine.arguments.dropFirst() == ["--attest-only"] {
  FileHandle.standardOutput.write(Data("sandbox-ok\n".utf8))
  exit(EXIT_SUCCESS)
}

let input = FileHandle.standardInput.readDataToEndOfFile()
guard input.count <= 1_048_576,
  let envelope = try? JSONDecoder().decode(PluginHelperEnvelope.self, from: input)
else {
  fail("invalid or oversized helper request")
}

guard envelope.request.protocolVersion == PluginRuntimeRequest.protocolVersion,
  envelope.request.pluginID == envelope.manifest.id,
  envelope.request.pluginVersion == envelope.manifest.version,
  envelope.manifest.capabilities.contains(envelope.request.capability),
  PluginRuntimeAllowlist.allows(envelope.request.target, manifest: envelope.manifest),
  (try? envelope.manifest.validate()) != nil,
  let payload = try? Data(contentsOf: URL(fileURLWithPath: envelope.artifactPath)),
  PluginArtifactStore.sha256Hex(payload) == envelope.manifest.contentHashSHA256Hex
else {
  fail("helper request failed manifest or artifact validation")
}

let pluginProcess = Process()
let pluginInput = Pipe()
let pluginOutput = Pipe()
private let outputCollector = BoundedOutputCollector()
pluginOutput.fileHandleForReading.readabilityHandler = { handle in
  outputCollector.append(handle.availableData)
}
defer { pluginOutput.fileHandleForReading.readabilityHandler = nil }
pluginProcess.executableURL = URL(fileURLWithPath: envelope.artifactPath)
pluginProcess.environment = ["PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"]
pluginProcess.standardInput = pluginInput
pluginProcess.standardOutput = pluginOutput
pluginProcess.standardError = FileHandle.nullDevice
let completion = DispatchSemaphore(value: 0)
pluginProcess.terminationHandler = { _ in completion.signal() }

do {
  try pluginProcess.run()
  pluginInput.fileHandleForWriting.write(envelope.request.payload)
  try pluginInput.fileHandleForWriting.close()
} catch {
  fail("plugin launch failed")
}

if completion.wait(timeout: .now() + 30) == .timedOut {
  pluginProcess.terminate()
  if completion.wait(timeout: .now() + 2) == .timedOut {
    kill(pluginProcess.processIdentifier, SIGKILL)
  }
  fail("plugin exceeded execution timeout")
}
pluginOutput.fileHandleForReading.readabilityHandler = nil
outputCollector.append(pluginOutput.fileHandleForReading.readDataToEndOfFile())
let collectedOutput = outputCollector.result()
guard pluginProcess.terminationStatus == 0, !collectedOutput.1 else {
  fail("plugin failed or exceeded output limit")
}

let response = PluginRuntimeResponse(
  nonce: envelope.request.nonce, sandboxAttested: true, output: collectedOutput.0)
guard let encoded = try? JSONEncoder().encode(response) else {
  fail("unable to encode helper response")
}
FileHandle.standardOutput.write(encoded)

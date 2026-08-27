import AuraCore
import AuraSecurity
import AuraShell
import Darwin
import Foundation
import Security

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(EXIT_FAILURE)
}

guard sandboxIsEnabled() else {
  fail("AuraShellHost refuses to run without the App Sandbox entitlement")
}

if CommandLine.arguments.dropFirst() == ["--attest-only"] {
  FileHandle.standardOutput.write(Data("sandbox-ok\n".utf8))
  exit(EXIT_SUCCESS)
}

// The shell helper executes a typed, authenticated `Command` and returns a
// typed `ProcessResult`. It holds no model, network, secret, or UI authority —
// only the ability to run a validated command within its sandbox. The request
// must carry a valid HMAC tag over the exact transmitted bytes, so a peer that
// does not hold the shared secret cannot forge a request.
let input = FileHandle.standardInput.readDataToEndOfFile()
guard input.count <= 1_048_576 else {
  fail("shell helper request exceeded size limit")
}

let authenticated: HelperIPCAuthenticatedRequest
do {
  authenticated = try JSONDecoder().decode(
    HelperIPCAuthenticatedRequest.self, from: input)
} catch {
  fail("invalid shell helper request")
}

// The helper holds the shared secret (provisioned through the same
// `SecretStoring` seam as the main process) so it can verify the request's
// HMAC tag and sign its response. A request without a valid tag is rejected
// before any execution.
let secretServiceName = ProcessInfo.processInfo.environment["AURA_HELPER_SECRET_SERVICE"]
  ?? "ai.aura.helper-ipc"
let secretStore = KeychainSecretStore(serviceName: secretServiceName)
let secretKey = ProcessInfo.processInfo.environment["AURA_HELPER_SECRET_KEY"]
  ?? "ai.aura.helper-ipc.shared-secret"
guard let secretData = try? await secretStore.retrieve(forKey: secretKey),
  let authenticator = try? HelperIPCAuthenticator(sharedSecret: secretData)
else {
  fail("shell helper shared secret is not provisioned")
}

guard authenticator.constantTimeEquals(
  authenticated.authenticationTag,
  authenticator.tag(forText: authenticated.requestText))
else {
  fail("shell helper request authentication failed")
}

// Re-validate the typed envelope so a tampered or replayed request is rejected
// here as well, independent of the main process's client.
guard (try? HelperIPCValidator.validate(
  authenticated.request, expectedHelper: .shell)) != nil
else {
  fail("shell helper protocol mismatch")
}

// Decode the typed command payload.
let command: Command
do {
  command = try JSONDecoder().decode(Command.self, from: authenticated.request.payload)
} catch {
  fail("shell helper command payload is invalid")
}

// Execute the command with a bounded output collector and a timeout so a
// runaway command cannot hang the helper.
let configuration = ShellConfiguration()
let runner = ProcessRunner(configuration: configuration)
let result: ProcessResult
switch await runner.run(command, executionID: authenticated.request.header.requestID) {
case .success(let value):
  result = value
case .failure(let error):
  fail("shell helper execution failed: \(error.localizedDescription)")
}

// Build the authenticated response bound to the request's ID and nonce.
let response = HelperIPCResponseEnvelope(
  request: authenticated.request, sandboxAttested: true,
  payload: (try? JSONEncoder().encode(result)) ?? Data())
let authenticatedResponse = HelperIPCAuthenticatedResponse(
  response: response,
  authenticationTag: authenticator.tag(
    forText: (try? HelperIPCCoder.text(for: response)) ?? ""))
guard let encoded = try? JSONEncoder().encode(authenticatedResponse) else {
  fail("unable to encode shell helper response")
}
FileHandle.standardOutput.write(encoded)

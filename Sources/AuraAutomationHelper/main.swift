import AuraAutomation
import AuraCore
import AuraSecurity
import Darwin
import Foundation
import Security

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(EXIT_FAILURE)
}

guard sandboxIsEnabled() else {
  fail("AuraAutomationHost refuses to run without the App Sandbox entitlement")
}

if CommandLine.arguments.dropFirst() == ["--attest-only"] {
  FileHandle.standardOutput.write(Data("sandbox-ok\n".utf8))
  exit(EXIT_SUCCESS)
}

// The automation helper executes typed, authenticated app-lifecycle operations
// (launch/activate/hide/quit) and returns a typed descriptor. It holds no
// model, network, secret, or UI authority beyond the app-lifecycle operation
// named in the request. Accessibility/generated-input execution requires a
// per-executable TCC grant that is outside this prompt's authority and is
// therefore not claimed here.
let input = FileHandle.standardInput.readDataToEndOfFile()
guard input.count <= 1_048_576 else {
  fail("automation helper request exceeded size limit")
}

let authenticated: HelperIPCAuthenticatedRequest
do {
  authenticated = try JSONDecoder().decode(
    HelperIPCAuthenticatedRequest.self, from: input)
} catch {
  fail("invalid automation helper request")
}

// The helper holds the shared secret so it can verify the request's HMAC tag
// and sign its response.
let secretServiceName = ProcessInfo.processInfo.environment["AURA_HELPER_SECRET_SERVICE"]
  ?? "ai.aura.helper-ipc"
let secretStore = KeychainSecretStore(serviceName: secretServiceName)
let secretKey = ProcessInfo.processInfo.environment["AURA_HELPER_SECRET_KEY"]
  ?? "ai.aura.helper-ipc.shared-secret"
guard let secretData = try? await secretStore.retrieve(forKey: secretKey),
  let authenticator = try? HelperIPCAuthenticator(sharedSecret: secretData)
else {
  fail("automation helper shared secret is not provisioned")
}

guard authenticator.constantTimeEquals(
  authenticated.authenticationTag,
  authenticator.tag(forText: authenticated.requestText))
else {
  fail("automation helper request authentication failed")
}

guard (try? HelperIPCValidator.validate(
  authenticated.request, expectedHelper: .automation)) != nil
else {
  fail("automation helper protocol mismatch")
}

// Decode the typed app-lifecycle operation.
let operation: AutomationHelperOperation
do {
  operation = try JSONDecoder().decode(
    AutomationHelperOperation.self, from: authenticated.request.payload)
} catch {
  fail("automation helper operation payload is invalid")
}

// Execute the app-lifecycle operation.
let automation = AuraAutomation()
let result: AutomationHelperResult
switch operation {
case .launch(let bundleIdentifier):
  do {
    try await automation.launchApplication(bundleIdentifier: bundleIdentifier)
    result = .success(NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier, name: "", processID: 0,
      isActive: false, isHidden: false))
  } catch {
    result = .failure(error.localizedDescription)
  }
case .activate(let bundleIdentifier):
  do {
    try await automation.activateApplication(bundleIdentifier: bundleIdentifier)
    result = .success(NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier, name: "", processID: 0,
      isActive: true, isHidden: false))
  } catch {
    result = .failure(error.localizedDescription)
  }
case .hide(let bundleIdentifier):
  do {
    try await automation.hideApplication(bundleIdentifier: bundleIdentifier)
    result = .success(NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier, name: "", processID: 0,
      isActive: false, isHidden: true))
  } catch {
    result = .failure(error.localizedDescription)
  }
case .quit(let bundleIdentifier):
  do {
    try await automation.quitApplication(bundleIdentifier: bundleIdentifier)
    result = .success(NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier, name: "", processID: 0,
      isActive: false, isHidden: false))
  } catch {
    result = .failure(error.localizedDescription)
  }
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
  fail("unable to encode automation helper response")
}
FileHandle.standardOutput.write(encoded)

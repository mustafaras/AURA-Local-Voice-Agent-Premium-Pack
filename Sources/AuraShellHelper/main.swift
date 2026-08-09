import AuraCore
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

// v1: respond to an echo request so integration tests can exercise IPC without
// executing real CLI commands. Real command execution follows in a later
// milestone.
let input = FileHandle.standardInput.readDataToEndOfFile()
guard input.count <= 1_048_576 else {
  fail("shell helper request exceeded size limit")
}

let request: HelperIPCRequestEnvelope
do {
  request = try JSONDecoder().decode(HelperIPCRequestEnvelope.self, from: input)
} catch {
  fail("invalid shell helper request")
}

guard (try? HelperIPCValidator.validate(request, expectedHelper: .shell)) != nil
else {
  fail("shell helper protocol mismatch")
}

let response = HelperIPCResponseEnvelope(
  request: request, sandboxAttested: true, payload: request.payload)

guard let encoded = try? JSONEncoder().encode(response) else {
  fail("unable to encode shell helper response")
}
FileHandle.standardOutput.write(encoded)

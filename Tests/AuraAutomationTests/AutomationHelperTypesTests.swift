import Foundation
import Testing

@testable import AuraAutomation
@testable import AuraCore

// MARK: - Automation helper typed operations

@Test
func automationHelperOperationRoundTrips() throws {
  let operations: [AutomationHelperOperation] = [
    .launch(bundleIdentifier: "com.apple.Calculator"),
    .activate(bundleIdentifier: "com.apple.Calculator"),
    .hide(bundleIdentifier: "com.apple.Calculator"),
    .quit(bundleIdentifier: "com.apple.Calculator"),
  ]
  for operation in operations {
    let data = try JSONEncoder().encode(operation)
    let decoded = try JSONDecoder().decode(AutomationHelperOperation.self, from: data)
    #expect(decoded == operation)
  }
}

@Test
func automationHelperResultRoundTrips() throws {
  let success = AutomationHelperResult.success(NativeApplicationDescriptor(
    bundleIdentifier: "com.apple.Calculator", name: "Calculator", processID: 42,
    isActive: true, isHidden: false))
  let failure = AutomationHelperResult.failure("boom")
  for result in [success, failure] {
    let data = try JSONEncoder().encode(result)
    let decoded = try JSONDecoder().decode(AutomationHelperResult.self, from: data)
    #expect(decoded == result)
  }
}

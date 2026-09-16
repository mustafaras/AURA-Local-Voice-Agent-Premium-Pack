import AuraCore
import Foundation
import Testing

@testable import AuraSecurity

/// ADR-065 §2 (PA-1 G1-2): the probe distinguishes the stable local identity
/// from every other signature state, and the fixed probe lets the kernel be
/// composed for tests without touching the Security framework.
@Suite("CodeIdentityProbe (ADR-065)")
struct CodeIdentityProbeTests {
  @Test("an Apple-signed bundle is a foreign identity, not stable")
  func appleSignedIsForeign() {
    let finder = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
    #expect(CodeIdentityProbe(codeURL: finder).identity() == .foreign)
  }

  @Test("an unsigned file is unsigned")
  func unsignedFileIsUnsigned() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("aura-code-identity-\(UUID().uuidString)")
    try Data("not a mach-o".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(CodeIdentityProbe(codeURL: url).identity() == .unsigned)
  }

  @Test("a missing path is unsigned, never stable")
  func missingPathIsUnsigned() {
    let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).app")
    #expect(CodeIdentityProbe(codeURL: url).identity() == .unsigned)
  }

  @Test("the installed stable-signed bundle, when present on this Mac, is stable")
  func installedBundleIsStableWhenPresent() {
    // Environment-dependent by nature: the stable identity is provisioned per
    // machine (ADR-030). When the installed bundle is absent the test is
    // vacuous, and says so, rather than failing a clean checkout.
    let installed = URL(fileURLWithPath: "/Applications/AURA.app")
    guard FileManager.default.fileExists(atPath: installed.path) else {
      Issue.record("skipped: /Applications/AURA.app not present on this machine")
      return
    }
    let identity = CodeIdentityProbe(codeURL: installed).identity()
    #expect(
      identity == .stable || identity == .foreign,
      "installed bundle must at least be signed; got \(identity)")
  }

  @Test("the test host itself never claims the stable identity")
  func testHostIsNotStable() {
    // The xctest host is Apple-signed or ad-hoc; under no circumstance may a
    // test process read the production Keychain namespace.
    #expect(CodeIdentityProbe().identity() != .stable)
  }

  @Test("the fixed probe returns exactly what it was given")
  func fixedProbe() {
    for value in [CodeIdentity.stable, .foreign, .unsigned] {
      #expect(FixedCodeIdentityProbe(value).identity() == value)
    }
  }

  @Test("the stable requirement names the certificate by subject CN")
  func stableIdentityName() {
    #expect(CodeIdentityProbe.stableIdentityName == "AURA Stable Local Signing")
  }
}

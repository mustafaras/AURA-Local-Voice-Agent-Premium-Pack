import AuraCore
import AuraPlugins
import Foundation
import Testing

@Test
func manifestValidatesWellFormedFixture() throws {
  let fixture = PluginFixtures.makeSignedManifest()
  try fixture.manifest.validate()
}

@Test
func manifestRejectsNonReverseDNSID() {
  let manifest = PluginManifest(
    id: "notreversedns", version: "1.0.0", vendorName: "Vendor",
    contentHashSHA256Hex: String(repeating: "a", count: 64),
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  #expect(throws: AuraError.self) { try manifest.validate() }
}

@Test
func manifestRejectsShortContentHash() {
  let manifest = PluginManifest(
    id: "com.example.plugin", version: "1.0.0", vendorName: "Vendor",
    contentHashSHA256Hex: "abc",
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  #expect(throws: AuraError.self) { try manifest.validate() }
}

@Test
func manifestRejectsNonHexContentHash() {
  let manifest = PluginManifest(
    id: "com.example.plugin", version: "1.0.0", vendorName: "Vendor",
    contentHashSHA256Hex: String(repeating: "z", count: 64),
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  #expect(throws: AuraError.self) { try manifest.validate() }
}

@Test
func manifestRejectsInvalidBase64Signature() {
  let manifest = PluginManifest(
    id: "com.example.plugin", version: "1.0.0", vendorName: "Vendor",
    contentHashSHA256Hex: String(repeating: "a", count: 64),
    signatureBase64: "not valid base64!!")
  #expect(throws: AuraError.self) { try manifest.validate() }
}

@Test
func manifestRejectsEmptyVendorName() {
  let manifest = PluginManifest(
    id: "com.example.plugin", version: "1.0.0", vendorName: "",
    contentHashSHA256Hex: String(repeating: "a", count: 64),
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  #expect(throws: AuraError.self) { try manifest.validate() }
}

@Test
func signedPayloadIsDeterministicRegardlessOfArrayOrder() {
  let firstManifest = PluginManifest(
    id: "com.example.plugin", version: "1.0.0", vendorName: "Vendor",
    capabilities: [.fileRead, .fileWrite],
    supportedApplicationBundleIDs: ["com.a", "com.b"],
    contentHashSHA256Hex: String(repeating: "a", count: 64),
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  let secondManifest = PluginManifest(
    id: "com.example.plugin", version: "1.0.0", vendorName: "Vendor",
    capabilities: [.fileWrite, .fileRead],
    supportedApplicationBundleIDs: ["com.b", "com.a"],
    contentHashSHA256Hex: String(repeating: "a", count: 64),
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  #expect(firstManifest.signedPayload == secondManifest.signedPayload)
}

@Test
func signedPayloadChangesWhenContentHashChanges() {
  let firstManifest = PluginManifest(
    id: "com.example.plugin", version: "1.0.0", vendorName: "Vendor",
    contentHashSHA256Hex: String(repeating: "a", count: 64),
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  let secondManifest = PluginManifest(
    id: "com.example.plugin", version: "1.0.0", vendorName: "Vendor",
    contentHashSHA256Hex: String(repeating: "b", count: 64),
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  #expect(firstManifest.signedPayload != secondManifest.signedPayload)
}

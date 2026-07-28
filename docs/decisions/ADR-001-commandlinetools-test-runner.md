# ADR-001: CommandLineTools Swift Testing Test Runner

- Status: Accepted
- Date: 2026-07-23
- Owners: GitHub Copilot (bootstrap engineer)
- Supersedes: N/A
- Superseded by: N/A

## Context

The AURA repository targets macOS 27+ and is built with Swift 6.4. During bootstrap the active toolchain was the Apple CommandLineTools (no full Xcode app):

- `swift-driver version: 1.168.5 Apple Swift version 6.4`
- Target: `arm64-apple-macosx27.0.0`
- `xcode-select -p` → `/Library/Developer/CommandLineTools`
- `XCTest.framework` is not present.
- Swift Testing is available as `/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework`.

A standard `swift test` invocation in the workspace `.build` directory fails at the codesign step because the `.xctest` bundle directory accumulates iCloud fileprovider extended attributes (`com.apple.fileprovider.fpfs#P`, `com.apple.FinderInfo`). These attributes cause ad-hoc codesign to reject the bundle with:

```
resource fork, Finder information, or similar detritus not allowed
```

Clearing the attributes with `xattr -c` is transient: they reappear before `codesign` runs. Even after bypassing codesign by building in `/tmp`, the SwiftPM test runner (`swiftpm-testing-helper`) refuses to load the unsigned test bundle with:

```
Failed to open test bundle ... Trying to load an unsigned library
```

Converting to `XCTest` is not an option because the framework is absent from this toolchain.

## Decision

1. Keep Swift Testing for all test targets.
2. Force explicit loading of `TestingMacros` in `Package.swift` for every test target via `.unsafeFlags(["-Xfrontend", "-load-resolved-plugin", "-Xfrontend", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib##TestingMacros"])`.
3. Provide a repository-local wrapper script `scripts/aura-test.sh` that:
   - builds the package in `/tmp` (outside iCloud-synced workspace paths);
 - builds each of the six test targets explicitly with `swift build --target <TestTarget>`;
   - invokes `/Library/Developer/CommandLineTools/usr/libexec/swift/pm/swiftpm-testing-helper --test-bundle-path <Mach-O path>`;
   - sets `DYLD_FRAMEWORK_PATH` and `DYLD_LIBRARY_PATH` so the helper can resolve `Testing.framework` and `lib_TestingInterop.dylib`.
4. Use this wrapper in CI rather than `swift test`, until the toolchain or SwiftPM behavior changes.

## Alternatives considered

- **Convert to XCTest**: impossible; XCTest is not installed.
- **Clear extended attributes repeatedly**: attributes reappear on iCloud-synced directories before codesign runs; not reliable.
- **Manually ad-hoc sign bundles**: codesign still fails because of the reappearing Finder/fileprovider xattrs on the bundle directory.
- **Custom executable runner using `Testing.__swiftPMEntryPoint`**: would require a dedicated target, but the helper-based approach reuses SwiftPM's own test entry point and avoids maintaining an extra runner executable.

## Security and privacy impact

- No change to runtime security model; tests run only during development/CI.
- Building in `/tmp` places intermediate artifacts outside the encrypted workspace, but no secrets or user data are processed during test runs.
- The wrapper does not bypass code signing of production targets; only the ad-hoc-signed debug test bundles are affected.

## Operational impact

- CI must use `./scripts/aura-test.sh` instead of `swift test` on macOS runners that mirror this CommandLineTools environment.
- Developers with full Xcode installed may still run `swift test` normally; the script is a compatibility shim.
- Future SwiftPM or toolchain updates may remove the need for the wrapper; this ADR documents the trigger condition for removing it.

## Migration

Remove the wrapper and revert the `.unsafeFlags` test-target settings when:

- A full Xcode toolchain is available in CI, or
- `swift test` on CommandLineTools handles ad-hoc signing of `.xctest` bundles correctly, or
- SwiftPM exposes a supported way to supply the Testing macro plugin path without `.unsafeFlags`.

## Validation evidence

Executed in the bootstrap environment:

```
swift build --build-path /tmp/aurabuild
for t in AuraCoreTests AuraStoreTests AURAIntegrationTests AuraAudioTests AuraAutomationTests AuraAgentTests; do
  swift build --build-path /tmp/aurabuild --target "$t"
done
DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/Library/Developer/Frameworks \
DYLD_LIBRARY_PATH=/Library/Developer/CommandLineTools/Library/Developer/usr/lib \
/Library/Developer/CommandLineTools/usr/libexec/swift/pm/swiftpm-testing-helper \
  --test-bundle-path /tmp/aurabuild/out/Products/Debug/<Target>.xctest/Contents/MacOS/<Target>
```

All six test bundles reported `exit:0`.

## Consequences

- Test execution is no longer blocked by the CommandLineTools signing limitation.
- `Package.swift` contains toolchain-specific absolute paths in `.unsafeFlags`. This is a known portability limitation tied to this ADR.
- CI is more fragile because it depends on the wrapper and environment variables; failures will be obvious if the helper path or framework layout changes.

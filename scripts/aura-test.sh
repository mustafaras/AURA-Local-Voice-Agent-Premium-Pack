#!/bin/zsh
# AURA test runner for the Apple CommandLineTools Swift 6.4 toolchain.
#
# SwiftPM's bundled `swift test` fails in this environment because iCloud
# extended attributes on the .build directory break ad-hoc codesign, and the
# Swift Testing helper cannot load unsigned bundles. This wrapper builds test
# targets in /tmp and invokes swiftpm-testing-helper with the system Testing
# framework and interop library on DYLD search paths.
#
# Usage: ./scripts/aura-test.sh [--build-path <path>]

set -euo pipefail

BUILD_PATH="${1:-/tmp/aurabuild}"
FILTER="${2:-}"
ENABLE_COVERAGE="${AURA_ENABLE_COVERAGE:-0}"
COVERAGE_MIN="${AURA_COVERAGE_MIN:-70}"
HELPER="/Library/Developer/CommandLineTools/usr/libexec/swift/pm/swiftpm-testing-helper"
TESTING_FRAMEWORK="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
TESTING_LIB="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_ARGS=(--build-path "$BUILD_PATH")
if [[ "$ENABLE_COVERAGE" == "1" ]]; then
    BUILD_ARGS+=(--enable-code-coverage)
fi

strip_build_xattrs() {
    # iCloud / Finder extended attributes break ad-hoc codesign. Strip them
    # from every file and directory under the build path so SwiftPM can sign
    # freshly produced test bundles.
    find "$BUILD_PATH" -exec xattr -c {} + 2>/dev/null || true
}

echo "==> Cleaning build path: $BUILD_PATH"
rm -rf "$BUILD_PATH"
if [[ "$ENABLE_COVERAGE" == "1" ]]; then
    mkdir -p "$BUILD_PATH/coverage"
fi

echo "==> Building production targets"
swift build "${BUILD_ARGS[@]}"
strip_build_xattrs

echo "==> Building test targets"
if [[ -n "$FILTER" ]]; then
    swift build "${BUILD_ARGS[@]}" --target "${FILTER}"
    strip_build_xattrs
else
    for target in \
        AuraCoreTests AuraStoreTests AURAIntegrationTests AuraAudioTests \
        AuraAutomationTests AuraAgentTests AuraSTTTests AuraPolicyTests \
        AuraShellTests AuraComputerUseTests AuraSecurityTests AuraPluginsTests \
        AuraIntentTests AuraVSCodeTests AuraTasksTests AuraMemoryTests \
        AuraContextTests AuraScreenTests; do
        swift build "${BUILD_ARGS[@]}" --target "$target"
        strip_build_xattrs
    done
fi

echo "==> Preparing Testing.framework symlinks"
PF="$BUILD_PATH/out/Products/Debug/PackageFrameworks"
mkdir -p "$PF"
ln -sfn "$TESTING_FRAMEWORK/Testing.framework" "$PF/Testing.framework"
ln -sfn "$TESTING_LIB/lib_TestingInterop.dylib" "$BUILD_PATH/out/Products/Debug/lib_TestingInterop.dylib"

run_bundle() {
    local bundle="$1"
    local name=$(basename "$bundle" .xctest)
    local log="$BUILD_PATH/out/Products/Debug/$name.log"
    local binary="$bundle/Contents/MacOS/$name"

    echo "=== $name ==="
    set +e
    perl -e 'alarm shift; exec @ARGV' 60 \
    env DYLD_FRAMEWORK_PATH="$TESTING_FRAMEWORK" \
        DYLD_LIBRARY_PATH="$TESTING_LIB" \
        DYLD_INSERT_LIBRARIES="$TESTING_LIB/lib_TestingInterop.dylib" \
        LLVM_PROFILE_FILE="$BUILD_PATH/coverage/$name-%p.profraw" \
    "$HELPER" \
        --test-bundle-path "$bundle/Contents/MacOS/$name" \
        --build-path "$BUILD_PATH" \
        "$bundle/Contents/MacOS/$name" \
        --testing-library swift-testing \
        > "$log" 2>&1
    local runner_status=$?
    set -e

    if [[ "$runner_status" != "0" ]]; then
        tail -40 "$log"
        echo "FAILED: $name (test helper exit $runner_status)"
        return 1
    fi
    if grep -q "✘ Test" "$log" 2>/dev/null || grep -q "Fatal error" "$log" 2>/dev/null; then
        tail -40 "$log"
        echo "FAILED: $name"
        return 1
    fi
    if grep -q "✔ Test run with" "$log" 2>/dev/null; then
        grep "✔ Test" "$log" | tail -20
        echo "PASSED: $name"
        return 0
    fi
    tail -40 "$log"
    echo "FAILED (no Swift Testing results): $name"
    return 1
}

echo "==> Running tests"
failed=0
if [[ -n "$FILTER" ]]; then
    bundle="$BUILD_PATH/out/Products/Debug/${FILTER}.xctest"
    if [[ -d "$bundle" ]]; then
        run_bundle "$bundle" || failed=$((failed + 1))
    else
        echo "Bundle not found: $bundle"
        failed=$((failed + 1))
    fi
else
    for bundle in "$BUILD_PATH"/out/Products/Debug/*.xctest; do
        run_bundle "$bundle" || failed=$((failed + 1))
    done
fi

echo "==> Done. Failed bundles: $failed"
if [[ "$failed" == "0" && "$ENABLE_COVERAGE" == "1" ]]; then
    echo "==> Calculating source coverage"
    profile_data="$BUILD_PATH/coverage/default.profdata"
    xcrun llvm-profdata merge -sparse "$BUILD_PATH"/coverage/*.profraw -o "$profile_data"
    binaries=("$BUILD_PATH"/out/Products/Debug/*.xctest/Contents/MacOS/*Tests)
    coverage_args=()
    for ((index = 2; index <= ${#binaries[@]}; index++)); do
        coverage_args+=(-object "${binaries[$index]}")
    done
    coverage_report="$BUILD_PATH/coverage/report.txt"
    xcrun llvm-cov report \
        "${binaries[1]}" \
        "${coverage_args[@]}" \
        -instr-profile "$profile_data" \
        -ignore-filename-regex='(/Tests/|/test/|/DerivedSources/)' \
        > "$coverage_report"
    cat "$coverage_report"
    line_coverage="$(awk '/^TOTAL/ {gsub("%", "", $10); print $10}' "$coverage_report")"
    if [[ -z "$line_coverage" ]]; then
        echo "FAILED: unable to parse line coverage"
        exit 1
    fi
    if ! awk -v actual="$line_coverage" -v minimum="$COVERAGE_MIN" \
        'BEGIN { exit !(actual + 0 >= minimum + 0) }'; then
        echo "FAILED: line coverage ${line_coverage}% is below ${COVERAGE_MIN}%"
        exit 1
    fi
    echo "PASSED: line coverage ${line_coverage}% meets ${COVERAGE_MIN}%"
fi
exit "$failed"

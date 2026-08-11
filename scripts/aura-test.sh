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
AURA_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
AURA_SWIFT_PATH="$(xcrun --find swift 2>/dev/null || true)"
if [[ -z "$AURA_DEVELOPER_DIR" || ! -d "$AURA_DEVELOPER_DIR" ]]; then
    echo "FAILED: xcode-select did not return a valid developer directory" >&2
    exit 2
fi
if [[ -z "$AURA_SWIFT_PATH" || ! -x "$AURA_SWIFT_PATH" ]]; then
    echo "FAILED: xcrun could not discover an executable Swift tool" >&2
    exit 2
fi

# Derive the SwiftPM helper and macro plugin from the discovered Swift toolchain.
# Testing.framework and its interop library may be supplied explicitly for a
# non-CommandLineTools Xcode layout; missing paths fail closed below.
AURA_SWIFT_USR="$(cd "$(dirname "$AURA_SWIFT_PATH")/.." && pwd)"
HELPER="$AURA_SWIFT_USR/libexec/swift/pm/swiftpm-testing-helper"
TESTING_MACROS_PATH="$AURA_SWIFT_USR/lib/swift/host/plugins/testing/libTestingMacros.dylib"
TESTING_FRAMEWORK="${AURA_TESTING_FRAMEWORK_PATH:-$AURA_DEVELOPER_DIR/Library/Developer/Frameworks}"
TESTING_LIB="${AURA_TESTING_LIB_PATH:-$AURA_DEVELOPER_DIR/Library/Developer/usr/lib}"

if [[ ! -x "$HELPER" || ! -f "$TESTING_MACROS_PATH" ||
    ! -d "$TESTING_FRAMEWORK/Testing.framework" ||
    ! -f "$TESTING_LIB/lib_TestingInterop.dylib" ]]; then
    echo "FAILED: Swift Testing support is incomplete for the discovered toolchain" >&2
    echo "  developer directory: $AURA_DEVELOPER_DIR" >&2
    echo "  swift tool: $AURA_SWIFT_PATH" >&2
    echo "  helper: $HELPER" >&2
    echo "  testing macros: $TESTING_MACROS_PATH" >&2
    echo "  Testing.framework root: $TESTING_FRAMEWORK" >&2
    echo "  Testing interop root: $TESTING_LIB" >&2
    exit 2
fi
export AURA_TESTING_MACROS_PATH="$TESTING_MACROS_PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
COVERAGE_SCOPE_FILE="$ROOT/scripts/aura-coverage-scope.regex"

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

TEST_TARGETS=(
    AuraCoreTests AuraStoreTests AURAIntegrationTests AuraAudioTests
    AuraAutomationTests AuraAgentTests AuraSTTTests AuraPolicyTests
    AuraShellTests AuraComputerUseTests AuraSecurityTests AuraPluginsTests
    AuraIntentTests AuraConfigTests AuraVSCodeTests AuraTasksTests AuraMemoryTests
    AuraContextTests AuraScreenTests AuraAdversarialTests AuraProductivityTests
)

echo "==> Building test targets"
failed=0
built_targets=()
if [[ -n "$FILTER" ]]; then
    if swift build "${BUILD_ARGS[@]}" --target "${FILTER}"; then
        strip_build_xattrs
        built_targets+=("$FILTER")
    else
        echo "FAILED TO BUILD: $FILTER"
        failed=$((failed + 1))
    fi
else
    for target in "${TEST_TARGETS[@]}"; do
        echo "--- $target"
        if swift build "${BUILD_ARGS[@]}" --target "$target"; then
            strip_build_xattrs
            built_targets+=("$target")
        else
            echo "FAILED TO BUILD: $target"
            failed=$((failed + 1))
        fi
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
    local timeout_seconds="${AURA_TEST_TIMEOUT_SECONDS:-60}"
    if [[ "$name" == "AuraAudioTests" ]]; then
        # AVAudioEngine teardown can block briefly on a headless CI host after
        # the Swift Testing suite has finished. Keep the hard timeout, but
        # give this hardware-bound bundle a bounded, explicit allowance.
        timeout_seconds="${AURA_AUDIO_TEST_TIMEOUT_SECONDS:-180}"
    fi

    echo "=== $name ==="
    if [[ ! -x "$binary" ]]; then
        echo "FAILED: $name (missing test executable)"
        return 1
    fi
    set +e
    perl -e 'alarm shift; exec @ARGV' "$timeout_seconds" \
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
if [[ -n "$FILTER" ]]; then
    if [[ ${#built_targets[@]} -eq 1 ]]; then
        bundle="$BUILD_PATH/out/Products/Debug/${FILTER}.xctest"
        if [[ -d "$bundle" ]]; then
            run_bundle "$bundle" || failed=$((failed + 1))
        else
            echo "Bundle not found: $bundle"
            failed=$((failed + 1))
        fi
    fi
else
    for target in "${built_targets[@]}"; do
        bundle="$BUILD_PATH/out/Products/Debug/${target}.xctest"
        if [[ -d "$bundle" ]]; then
            run_bundle "$bundle" || failed=$((failed + 1))
        else
            echo "Bundle not found: $bundle"
            failed=$((failed + 1))
        fi
    done
fi

echo "==> Done. Failed bundles: $failed"
if [[ "$failed" == "0" && "$ENABLE_COVERAGE" == "1" ]]; then
    echo "==> Calculating source coverage"
    profile_data="$BUILD_PATH/coverage/default.profdata"
    coverage_profiles=("$BUILD_PATH"/coverage/*.profraw(N))
    if [[ ${#coverage_profiles[@]} -eq 0 ]]; then
        echo "FAILED: no LLVM profile files were produced"
        exit 1
    fi
    if [[ ! -f "$COVERAGE_SCOPE_FILE" ]]; then
        echo "FAILED: coverage scope file is missing: $COVERAGE_SCOPE_FILE"
        exit 1
    fi
    coverage_ignore_regex="$(awk 'BEGIN { first = 1 } /^[[:space:]]*#/ || /^[[:space:]]*$/ { next } { if (!first) printf "|"; printf "(%s)", $0; first = 0 }' "$COVERAGE_SCOPE_FILE")"
    if [[ -z "$coverage_ignore_regex" ]]; then
        echo "FAILED: coverage scope file is empty: $COVERAGE_SCOPE_FILE"
        exit 1
    fi
    echo "==> Coverage scope: $COVERAGE_SCOPE_FILE"
    xcrun llvm-profdata merge -sparse "${coverage_profiles[@]}" -o "$profile_data"
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
        -ignore-filename-regex="$coverage_ignore_regex" \
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

#!/bin/zsh
set -euo pipefail

# Build, sign, and run the SP-016 bilingual STT quality probe.
#
# The probe measures on-device Turkish/English/mixed recognition quality by
# synthesizing speech with system voices and driving it through the real
# `SystemSTTEngine`. It never opens the microphone.
#
# It must run from a signed .app bundle: Speech Recognition authorization is
# granted per executable, and a bare SwiftPM binary aborts (SIGABRT/exit 134)
# instead of prompting. It is launched via LaunchServices (`open`) so TCC
# attributes the request to this bundle instead of the calling terminal.

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/.build/sp016-probe}"
APP_NAME="AuraSpeechQualityProbe"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
OUTPUT_PATH="${1:-$BUILD_DIR/sp016-speech-probe.json}"
LOCAL_IDENTITY="AURA Stable Local Signing"
TIMEOUT_SECONDS="${SP016_PROBE_TIMEOUT:-900}"

echo "==> Building $APP_NAME (release)"
swift build -c release --product "$APP_NAME" --build-path "$BUILD_DIR/swiftpm"

echo "==> Assembling bundle at $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
cp "$BUILD_DIR/swiftpm/release/$APP_NAME" "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$REPO_ROOT/Resources/$APP_NAME-Info.plist" "$APP_PATH/Contents/Info.plist"

# Prefer the stable local identity so the Speech grant survives rebuilds;
# ad-hoc otherwise (which re-prompts on every rebuild).
SIGNING_IDENTITY="${AURA_CODESIGN_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  if security find-identity -v -p codesigning | grep -Fq "\"$LOCAL_IDENTITY\""; then
    SIGNING_IDENTITY="$LOCAL_IDENTITY"
  else
    SIGNING_IDENTITY="-"
  fi
fi
echo "==> Signing with identity: $SIGNING_IDENTITY"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$APP_PATH"
codesign --verify --verbose "$APP_PATH"

rm -f "$OUTPUT_PATH"
mkdir -p "$(dirname "$OUTPUT_PATH")"

echo "==> Launching probe via LaunchServices"
echo "    If macOS prompts for Speech Recognition access, approve it."
open -a "$APP_PATH" --args "$OUTPUT_PATH"

echo "==> Waiting for report (timeout ${TIMEOUT_SECONDS}s): $OUTPUT_PATH"
elapsed=0
while [[ ! -f "$OUTPUT_PATH" && $elapsed -lt $TIMEOUT_SECONDS ]]; do
  sleep 2
  elapsed=$((elapsed + 2))
done

if [[ ! -f "$OUTPUT_PATH" ]]; then
  echo "FAILED: no report produced within ${TIMEOUT_SECONDS}s" >&2
  exit 1
fi

echo "==> Report written: $OUTPUT_PATH"

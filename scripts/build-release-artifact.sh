#!/bin/zsh
set -euo pipefail

# Build a reproducible, explicitly untrusted development artifact and manifest.
# This script does not sign, notarize, install, publish, or deploy anything.
# A release_candidate/released status requires a separately authorized process
# and independent Apple signature/notarization evidence.

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-/tmp/aura-r11-release-artifact}"
OUTPUT_DIR="${OUTPUT_DIR:-$BUILD_ROOT/output}"
APP_BUILD_DIR="$BUILD_ROOT/app-build"
APP_PATH="$APP_BUILD_DIR/AURA.app"
ARCHIVE_PATH="$OUTPUT_DIR/AURA-development-unverified.zip"
MANIFEST_PATH="$OUTPUT_DIR/AURA-development-unverified.manifest.json"

case "$BUILD_ROOT" in
  /|"$REPO_ROOT"|"$HOME"|"$HOME"/*)
    echo "refusing unsafe BUILD_ROOT: $BUILD_ROOT" >&2
    exit 2
    ;;
esac

mkdir -p "$OUTPUT_DIR"
BUILD_DIR="$APP_BUILD_DIR" "$SCRIPT_DIR/build-app-bundle.sh"
python3 "$SCRIPT_DIR/generate_release_manifest.py" \
  --bundle "$APP_PATH" \
  --archive "$ARCHIVE_PATH" \
  --output "$MANIFEST_PATH" \
  --source-root "$REPO_ROOT" \
  --status development_unverified \
  --minimum-os 27.0 \
  --helper-ipc-protocol 2
python3 "$SCRIPT_DIR/validate_release_manifest.py" \
  --manifest "$MANIFEST_PATH" \
  --bundle-root "$APP_PATH" \
  --artifact "$ARCHIVE_PATH"

echo "Development artifact (not signed/notarized): $ARCHIVE_PATH"
echo "Manifest: $MANIFEST_PATH"

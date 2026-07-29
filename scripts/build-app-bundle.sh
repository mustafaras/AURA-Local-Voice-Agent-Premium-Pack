#!/bin/zsh
set -euo pipefail

# Build AURA.app from the SwiftPM executable target.
# This script is a Phase 20 release-readiness placeholder.
# It builds the executable and assembles a .app bundle structure;
# signing is performed separately by scripts/codesign-adhoc.sh.

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/.build/release-app}"
APP_NAME="AURA"
BUNDLE_ID="ai.aura.local.agent"

# Clean previous bundle
rm -rf "$BUILD_DIR/$APP_NAME.app"

# Build the SwiftPM executable in release mode.
# We use swift build directly because swiftpm-testing-helper is only needed for tests.
swift build \
  -c release \
  --product "$APP_NAME" \
  --build-path "$BUILD_DIR/swiftpm"
swift build \
  -c release \
  --product "AuraPluginHost" \
  --build-path "$BUILD_DIR/swiftpm"

# Assemble .app bundle
CONTENTS="$BUILD_DIR/$APP_NAME.app/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
HELPER_APP="$CONTENTS/Helpers/AuraPluginHost.app"
HELPER_CONTENTS="$HELPER_APP/Contents"
HELPER_MACOS="$HELPER_CONTENTS/MacOS"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$HELPER_MACOS"
mkdir -p "$RESOURCES_DIR/Chatterbox"

# Copy executable
cp "$BUILD_DIR/swiftpm/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$BUILD_DIR/swiftpm/release/AuraPluginHost" "$HELPER_MACOS/AuraPluginHost"
cp "$REPO_ROOT/Resources/AuraPluginHost-Info.plist" "$HELPER_CONTENTS/Info.plist"

# Copy entitlements and Info.plist for the bundle build.
cp "$REPO_ROOT/Resources/$APP_NAME-Info.plist" "$CONTENTS/Info.plist"
cp "$REPO_ROOT/Resources/$APP_NAME.entitlements" "$RESOURCES_DIR/$APP_NAME.entitlements"
cp "$REPO_ROOT/Resources/AuraPluginHost.entitlements" "$RESOURCES_DIR/AuraPluginHost.entitlements"
cp "$REPO_ROOT/Runtime/chatterbox/chatterbox_helper.py" \
  "$RESOURCES_DIR/Chatterbox/chatterbox_helper.py"

echo "Built $BUILD_DIR/$APP_NAME.app"
echo "Next step: ./scripts/codesign-adhoc.sh $BUILD_DIR/$APP_NAME.app"

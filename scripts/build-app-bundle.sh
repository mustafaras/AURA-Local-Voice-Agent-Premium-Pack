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
swift build \
  -c release \
  --product "AuraAutomationHelper" \
  --build-path "$BUILD_DIR/swiftpm"
swift build \
  -c release \
  --product "AuraShellHelper" \
  --build-path "$BUILD_DIR/swiftpm"
swift build \
  -c release \
  --product "AuraSafariExtensionHandler" \
  --build-path "$BUILD_DIR/swiftpm"
swift build \
  -c release \
  --product "AuraChromeNativeHost" \
  --build-path "$BUILD_DIR/swiftpm"

# Assemble .app bundle
CONTENTS="$BUILD_DIR/$APP_NAME.app/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
HELPER_APP="$CONTENTS/Helpers/AuraPluginHost.app"
HELPER_CONTENTS="$HELPER_APP/Contents"
HELPER_MACOS="$HELPER_CONTENTS/MacOS"
AUTOMATION_HELPER_APP="$CONTENTS/Helpers/AuraAutomationHelper.app"
AUTOMATION_HELPER_CONTENTS="$AUTOMATION_HELPER_APP/Contents"
AUTOMATION_HELPER_MACOS="$AUTOMATION_HELPER_CONTENTS/MacOS"
SHELL_HELPER_APP="$CONTENTS/Helpers/AuraShellHelper.app"
SHELL_HELPER_CONTENTS="$SHELL_HELPER_APP/Contents"
SHELL_HELPER_MACOS="$SHELL_HELPER_CONTENTS/MacOS"
CHROME_HOST="$CONTENTS/Helpers/AuraChromeNativeHost"
# The Safari Web Extension. It must live in Contents/PlugIns for Safari to
# discover it when the containing app is registered with Launch Services;
# anywhere else and the extension simply never appears in Safari's list.
SAFARI_EXTENSION_APPEX="$CONTENTS/PlugIns/AuraSafariExtension.appex"
SAFARI_EXTENSION_CONTENTS="$SAFARI_EXTENSION_APPEX/Contents"
SAFARI_EXTENSION_MACOS="$SAFARI_EXTENSION_CONTENTS/MacOS"
SAFARI_EXTENSION_RESOURCES="$SAFARI_EXTENSION_CONTENTS/Resources"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$HELPER_MACOS" "$AUTOMATION_HELPER_MACOS" "$SHELL_HELPER_MACOS"
mkdir -p "$SAFARI_EXTENSION_MACOS" "$SAFARI_EXTENSION_RESOURCES"
mkdir -p "$RESOURCES_DIR/Chatterbox"

# Copy executable
cp "$BUILD_DIR/swiftpm/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$BUILD_DIR/swiftpm/release/AuraPluginHost" "$HELPER_MACOS/AuraPluginHost"
cp "$BUILD_DIR/swiftpm/release/AuraAutomationHelper" "$AUTOMATION_HELPER_MACOS/AuraAutomationHelper"
cp "$BUILD_DIR/swiftpm/release/AuraShellHelper" "$SHELL_HELPER_MACOS/AuraShellHelper"
cp "$BUILD_DIR/swiftpm/release/AuraChromeNativeHost" "$CHROME_HOST"
chmod +x "$CHROME_HOST"
cp "$REPO_ROOT/Resources/AuraPluginHost-Info.plist" "$HELPER_CONTENTS/Info.plist"
cp "$REPO_ROOT/Resources/AuraAutomationHelper-Info.plist" "$AUTOMATION_HELPER_CONTENTS/Info.plist"
cp "$REPO_ROOT/Resources/AuraShellHelper-Info.plist" "$SHELL_HELPER_CONTENTS/Info.plist"

# Copy entitlements and Info.plist for the bundle build.
cp "$REPO_ROOT/Resources/$APP_NAME-Info.plist" "$CONTENTS/Info.plist"
cp "$REPO_ROOT/Resources/$APP_NAME.entitlements" "$RESOURCES_DIR/$APP_NAME.entitlements"
cp "$REPO_ROOT/Resources/AuraPluginHost.entitlements" "$RESOURCES_DIR/AuraPluginHost.entitlements"
cp "$REPO_ROOT/Resources/AuraAutomationHelper.entitlements" "$RESOURCES_DIR/AuraAutomationHelper.entitlements"
cp "$REPO_ROOT/Resources/AuraShellHelper.entitlements" "$RESOURCES_DIR/AuraShellHelper.entitlements"
cp "$REPO_ROOT/Runtime/chatterbox/chatterbox_helper.py" \
  "$RESOURCES_DIR/Chatterbox/chatterbox_helper.py"

# Assemble the Safari Web Extension. The web half (manifest + service worker)
# ships verbatim from Resources/SafariExtension so the reviewed source is the
# thing that runs; the native half is the SwiftPM executable built above.
cp "$BUILD_DIR/swiftpm/release/AuraSafariExtensionHandler" \
  "$SAFARI_EXTENSION_MACOS/AuraSafariExtensionHandler"
cp "$REPO_ROOT/Resources/AuraSafariExtension-Info.plist" \
  "$SAFARI_EXTENSION_CONTENTS/Info.plist"
cp "$REPO_ROOT/Resources/SafariExtension/manifest.json" \
  "$SAFARI_EXTENSION_RESOURCES/manifest.json"
cp "$REPO_ROOT/Resources/SafariExtension/background.js" \
  "$SAFARI_EXTENSION_RESOURCES/background.js"

# Bundle the Chrome extension source verbatim. Chrome loads this directory as
# an unpacked MV3 extension; the app refreshes the native host manifest on
# every launch through ChromeBridgeInstaller.
cp -R "$REPO_ROOT/Resources/ChromeExtension" "$RESOURCES_DIR/ChromeExtension"

echo "Built $BUILD_DIR/$APP_NAME.app"
echo "Next step: ./scripts/codesign-adhoc.sh $BUILD_DIR/$APP_NAME.app"

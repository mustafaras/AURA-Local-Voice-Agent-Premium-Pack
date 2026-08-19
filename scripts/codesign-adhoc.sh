#!/bin/zsh
set -euo pipefail

# Code-sign AURA.app for local development.
# Prefer the stable, locally trusted Keychain identity so TCC grants survive
# rebuilds. Fall back to ad-hoc signing on machines where that identity has not
# been provisioned. A real Developer ID certificate is still required for
# notarized distribution.

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
APP_PATH="${1:-$SCRIPT_DIR/../.build/release-app/AURA.app}"
ENTITLEMENTS="$(cd "$SCRIPT_DIR/.." && pwd)/Resources/AURA.entitlements"
HELPER_ENTITLEMENTS="$(cd "$SCRIPT_DIR/.." && pwd)/Resources/AuraPluginHost.entitlements"
AUTOMATION_HELPER_ENTITLEMENTS="$(cd "$SCRIPT_DIR/.." && pwd)/Resources/AuraAutomationHelper.entitlements"
SHELL_HELPER_ENTITLEMENTS="$(cd "$SCRIPT_DIR/.." && pwd)/Resources/AuraShellHelper.entitlements"
HELPER_PATH="$APP_PATH/Contents/Helpers/AuraPluginHost.app"
AUTOMATION_HELPER_PATH="$APP_PATH/Contents/Helpers/AuraAutomationHelper.app"
SHELL_HELPER_PATH="$APP_PATH/Contents/Helpers/AuraShellHelper.app"
SAFARI_EXTENSION_ENTITLEMENTS="$(cd "$SCRIPT_DIR/.." && pwd)/Resources/AuraSafariExtension.entitlements"
SAFARI_EXTENSION_PATH="$APP_PATH/Contents/PlugIns/AuraSafariExtension.appex"
LOCAL_IDENTITY="AURA Stable Local Signing"
SIGNING_IDENTITY="${AURA_CODESIGN_IDENTITY:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  if security find-identity -v -p codesigning | grep -Fq "\"$LOCAL_IDENTITY\""; then
    SIGNING_IDENTITY="$LOCAL_IDENTITY"
  else
    SIGNING_IDENTITY="-"
  fi
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  echo "Run ./scripts/build-app-bundle.sh first."
  exit 1
fi

if [[ ! -d "$HELPER_PATH" ]]; then
  echo "Plugin helper not found: $HELPER_PATH"
  exit 1
fi

if [[ ! -d "$AUTOMATION_HELPER_PATH" ]]; then
  echo "Automation helper not found: $AUTOMATION_HELPER_PATH"
  exit 1
fi

if [[ ! -d "$SHELL_HELPER_PATH" ]]; then
  echo "Shell helper not found: $SHELL_HELPER_PATH"
  exit 1
fi

if [[ ! -d "$SAFARI_EXTENSION_PATH" ]]; then
  echo "Safari extension not found: $SAFARI_EXTENSION_PATH"
  exit 1
fi

echo "Signing isolated plugin helper with identity '$SIGNING_IDENTITY' and $HELPER_ENTITLEMENTS"
codesign \
  --force \
  --sign "$SIGNING_IDENTITY" \
  --options runtime \
  --entitlements "$HELPER_ENTITLEMENTS" \
  "$HELPER_PATH"

echo "Signing automation helper with identity '$SIGNING_IDENTITY' and $AUTOMATION_HELPER_ENTITLEMENTS"
codesign \
  --force \
  --sign "$SIGNING_IDENTITY" \
  --options runtime \
  --entitlements "$AUTOMATION_HELPER_ENTITLEMENTS" \
  "$AUTOMATION_HELPER_PATH"

echo "Signing shell helper with identity '$SIGNING_IDENTITY' and $SHELL_HELPER_ENTITLEMENTS"
codesign \
  --force \
  --sign "$SIGNING_IDENTITY" \
  --options runtime \
  --entitlements "$SHELL_HELPER_ENTITLEMENTS" \
  "$SHELL_HELPER_PATH"

# The extension must be signed before the app: the app's signature seals its
# nested code, so signing the appex afterwards invalidates the containing
# bundle and Safari refuses to load the extension.
echo "Signing Safari extension with identity '$SIGNING_IDENTITY' and $SAFARI_EXTENSION_ENTITLEMENTS"
codesign \
  --force \
  --sign "$SIGNING_IDENTITY" \
  --options runtime \
  --entitlements "$SAFARI_EXTENSION_ENTITLEMENTS" \
  "$SAFARI_EXTENSION_PATH"

echo "Signing $APP_PATH with identity '$SIGNING_IDENTITY' and entitlements $ENTITLEMENTS"
codesign \
  --force \
  --sign "$SIGNING_IDENTITY" \
  --options runtime \
  --entitlements "$ENTITLEMENTS" \
  "$APP_PATH"

echo "Local signing complete."

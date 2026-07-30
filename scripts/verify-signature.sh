#!/bin/zsh
set -euo pipefail

# Verify code signature and entitlements for AURA.app.
# This script is a Phase 20 release-readiness placeholder.
# It returns non-zero if the signature is invalid or entitlements are missing.

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
APP_PATH="${1:-$SCRIPT_DIR/../.build/release-app/AURA.app}"

function verify_helper() {
  local helper_name="$1"
  local helper_path="$APP_PATH/Contents/Helpers/${helper_name}.app"
  local helper_executable="$helper_path/Contents/MacOS/$helper_name"

  if [[ ! -d "$helper_path" ]]; then
    echo "$helper_name not found: $helper_path"
    exit 1
  fi

  echo ""
  echo "=== $helper_name sandbox ==="
  codesign --verify --strict "$helper_path"
  local helper_plist
  helper_plist="$(mktemp -t aura-${helper_name:l}-entitlements)"
  codesign -d --entitlements :- "$helper_path" 2>/dev/null > "$helper_plist"
  if [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$helper_plist")" != "true" ]]; then
    echo "$helper_name is not App Sandbox entitled"
    exit 1
  fi
  for capability in \
    com.apple.security.network.client \
    com.apple.security.network.server \
    com.apple.security.device.microphone \
    com.apple.security.device.camera; do
    value="$(/usr/libexec/PlistBuddy -c "Print :$capability" "$helper_plist" 2>/dev/null || echo false)"
    if [[ "$value" == "true" ]]; then
      echo "$helper_name unexpectedly has $capability"
      exit 1
    fi
  done
  local attestation
  attestation="$("$helper_executable" --attest-only)"
  if [[ "$attestation" != "sandbox-ok" ]]; then
    echo "$helper_name did not complete sandbox self-attestation"
    exit 1
  fi
  echo "$helper_name OK"
  rm -f "$helper_plist"
}

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

verify_helper "AuraPluginHost"
verify_helper "AuraAutomationHelper"
verify_helper "AuraShellHelper"

echo "=== Signature verification ==="
codesign -dv --verbose=4 "$APP_PATH"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
if [[ "$SIGNATURE_DETAILS" != *"runtime"* ]]; then
  echo "Main app is not signed with Hardened Runtime"
  exit 1
fi

echo ""
echo "=== Entitlements ==="
codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | plutil -p -
MAIN_PLIST="$(mktemp -t aura-main-entitlements)"
codesign -d --entitlements :- "$APP_PATH" 2>/dev/null > "$MAIN_PLIST"
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$MAIN_PLIST" 2>/dev/null || echo false)" == "true" ]]; then
  echo "Main app unexpectedly enables App Sandbox; CLI/Accessibility helper migration is incomplete"
  rm -f "$MAIN_PLIST"
  exit 1
fi
for invalid_capability in \
  com.apple.security.accessibility \
  com.apple.security.screen-recording \
  com.apple.security.device.microphone \
  com.apple.security.files.bookmarks.app-scope \
  com.apple.security.files.user-selected.read-write; do
  if /usr/libexec/PlistBuddy -c "Print :$invalid_capability" "$MAIN_PLIST" >/dev/null 2>&1; then
    echo "Main app contains unsupported entitlement $invalid_capability"
    rm -f "$MAIN_PLIST"
    exit 1
  fi
done
rm -f "$MAIN_PLIST"
echo "Main app sandbox: intentionally disabled; TCC and policy enforce protected capabilities"

echo ""
echo "=== Designated requirement ==="
codesign -d -r- "$APP_PATH"

echo ""
echo "=== Strict validation ==="
codesign --verify --deep --strict "$APP_PATH"

echo ""
echo "Signature OK: $APP_PATH"

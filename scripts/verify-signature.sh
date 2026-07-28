#!/bin/zsh
set -euo pipefail

# Verify code signature and entitlements for AURA.app.
# This script is a Phase 20 release-readiness placeholder.
# It returns non-zero if the signature is invalid or entitlements are missing.

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
APP_PATH="${1:-$SCRIPT_DIR/../.build/release-app/AURA.app}"
HELPER_PATH="$APP_PATH/Contents/Helpers/AuraPluginHost.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi
if [[ ! -d "$HELPER_PATH" ]]; then
  echo "Plugin helper not found: $HELPER_PATH"
  exit 1
fi

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
echo "=== Plugin helper sandbox ==="
codesign --verify --strict "$HELPER_PATH"
HELPER_PLIST="$(mktemp -t aura-plugin-helper-entitlements)"
trap 'rm -f "$HELPER_PLIST"' EXIT
codesign -d --entitlements :- "$HELPER_PATH" 2>/dev/null > "$HELPER_PLIST"
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$HELPER_PLIST")" != "true" ]]; then
  echo "Plugin helper is not App Sandbox entitled"
  exit 1
fi
for capability in \
  com.apple.security.network.client \
  com.apple.security.network.server \
  com.apple.security.device.microphone \
  com.apple.security.device.camera; do
  value="$(/usr/libexec/PlistBuddy -c "Print :$capability" "$HELPER_PLIST" 2>/dev/null || echo false)"
  if [[ "$value" == "true" ]]; then
    echo "Plugin helper unexpectedly has $capability"
    exit 1
  fi
done
attestation="$("$HELPER_PATH/Contents/MacOS/AuraPluginHost" --attest-only)"
if [[ "$attestation" != "sandbox-ok" ]]; then
  echo "Plugin helper did not complete sandbox self-attestation"
  exit 1
fi

echo ""
echo "Signature OK: $APP_PATH"

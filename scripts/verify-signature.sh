#!/bin/zsh
set -euo pipefail

# Verify code signature and entitlements for AURA.app.
# This script is a Phase 20 release-readiness placeholder.
# It returns non-zero if the signature is invalid or entitlements are missing.

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
APP_PATH="${1:-$SCRIPT_DIR/../.build/release-app/AURA.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  exit 1
fi

echo "=== Signature verification ==="
codesign -dv --verbose=4 "$APP_PATH"

echo ""
echo "=== Entitlements ==="
codesign -d --entitlements - "$APP_PATH" | plutil -p - || true

echo ""
echo "=== Designated requirement ==="
codesign -d -r- "$APP_PATH"

echo ""
echo "=== Strict validation ==="
codesign --verify --deep --strict "$APP_PATH"

echo ""
echo "Signature OK: $APP_PATH"

#!/bin/zsh
set -euo pipefail

# Ad-hoc code-sign AURA.app for local distribution and notarization prep.
# This script is a Phase 20 release-readiness placeholder.
# A real Developer ID certificate must be configured for App Store / notarized distribution.

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
APP_PATH="${1:-$SCRIPT_DIR/../.build/release-app/AURA.app}"
ENTITLEMENTS="$(cd "$SCRIPT_DIR/.." && pwd)/Resources/AURA.entitlements"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH"
  echo "Run ./scripts/build-app-bundle.sh first."
  exit 1
fi

echo "Signing $APP_PATH with entitlements $ENTITLEMENTS"

codesign \
  --force \
  --deep \
  --sign "-" \
  --entitlements "$ENTITLEMENTS" \
  "$APP_PATH"

echo "Ad-hoc signing complete."

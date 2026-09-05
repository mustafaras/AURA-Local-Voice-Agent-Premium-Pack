#!/bin/bash
# Install the AURA Chrome native messaging host manifest and copy the host
# binary into AURA's Application Support directory.
#
# Chrome discovers native messaging hosts by reading a JSON manifest from
# ~/Library/Application Support/Google/Chrome/NativeMessagingHosts/<name>.json
# whose "path" points at the host executable. The host is a plain SwiftPM
# executable; we install it beside the app's own Application Support data so
# it survives and is easy to find.
set -euo pipefail

HOST_NAME="ai.aura.local.agent"
APP_SUPPORT="$HOME/Library/Application Support/AURA"
HOST_DIR="$APP_SUPPORT/ChromeNativeHost"
HOST_BIN="$HOST_DIR/AuraChromeNativeHost"
MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
MANIFEST="$MANIFEST_DIR/$HOST_NAME.json"

# Locate the freshly built host binary. Prefer the release build, then debug.
BUILD_DIR="${BUILD_DIR:-}"
if [[ -z "$BUILD_DIR" ]]; then
  if [[ -f ".build/release/AuraChromeNativeHost" ]]; then
    BUILD_DIR=".build/release"
  elif [[ -f ".build/debug/AuraChromeNativeHost" ]]; then
    BUILD_DIR=".build/debug"
  else
    echo "error: AuraChromeNativeHost binary not found; run 'swift build' first" >&2
    exit 1
  fi
fi

mkdir -p "$HOST_DIR" "$MANIFEST_DIR"
chmod 700 "$APP_SUPPORT" "$HOST_DIR"
HOST_TMP="$HOST_DIR/.AuraChromeNativeHost.new"
cp "$BUILD_DIR/AuraChromeNativeHost" "$HOST_TMP"
chmod 700 "$HOST_TMP"

# Match the containing app's local identity. This is not Developer ID or
# notarization; it gives macOS a stable local code identity for the host.
SIGNING_IDENTITY="${AURA_CODESIGN_IDENTITY:-AURA Stable Local Signing}"
if security find-identity -v -p codesigning | grep -Fq "$SIGNING_IDENTITY"; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$HOST_TMP"
else
  codesign --force --sign - --timestamp=none "$HOST_TMP"
fi
mv -f "$HOST_TMP" "$HOST_BIN"

# Chrome requires native messaging manifests to list exact extension origins.
# The public `key` in the unpacked extension manifest gives it a stable ID on
# every machine. Chrome derives that ID from the first 128 bits of SHA-256 over
# the DER public key, mapping hexadecimal 0...f to letters a...p.
EXTENSION_ID="$(python3 - <<'PY'
import base64, hashlib, json
with open("Resources/ChromeExtension/manifest.json", encoding="utf-8") as stream:
    key = json.load(stream)["key"]
digest = hashlib.sha256(base64.b64decode(key)).hexdigest()[:32]
print("".join(chr(ord("a") + int(char, 16)) for char in digest))
PY
)"

MANIFEST_TMP="$MANIFEST_DIR/.$HOST_NAME.json.new"
cat > "$MANIFEST_TMP" <<EOF
{
  "name": "$HOST_NAME",
  "description": "AURA read-only browser bridge native messaging host",
  "path": "$HOST_BIN",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$EXTENSION_ID/"
  ]
}
EOF
chmod 600 "$MANIFEST_TMP"
mv -f "$MANIFEST_TMP" "$MANIFEST"

CONFIG_TMP="$HOST_DIR/.host-config.json.new"
cat > "$CONFIG_TMP" <<EOF
{
  "extensionID": "com.aura.safari-extension",
  "profileID": "personal",
  "sharedContainerPath": "$HOME/Library/Application Support/AURA/SafariBridge/observation.json",
  "extensionPath": "$PWD/Resources/ChromeExtension"
}
EOF
chmod 600 "$CONFIG_TMP"
mv -f "$CONFIG_TMP" "$HOST_DIR/host-config.json"

echo "Installed Chrome native messaging host:"
echo "  manifest: $MANIFEST"
echo "  binary:   $HOST_BIN"
echo "  extension: chrome-extension://$EXTENSION_ID/"

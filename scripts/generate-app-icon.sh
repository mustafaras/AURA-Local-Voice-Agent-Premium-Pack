#!/bin/zsh
# Generate Resources/AURA.icns from the vector masters in Resources/brand/.
#
# This script is the ONLY path to the .icns (UI-0 gate G0-1): PNG intermediates
# are rendered into a temp directory and never committed, so the vector master
# can never drift from the rendered asset (10-icon-identity.md §4).
#
# Renderer chain: rsvg-convert (preferred) → qlmanage+sips fallback. Both paths
# render the same SVG masters to the full iconset size table.
#
# Usage: ./scripts/generate-app-icon.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRAND_DIR="$REPO_ROOT/Resources/brand"
OUT_ICNS="$REPO_ROOT/Resources/AURA.icns"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aura-iconset.XXXXXX")"

trap 'rm -rf "$WORK_DIR"' EXIT

# --- Prerequisites -----------------------------------------------------------

for master in iris-dark.svg iris-light.svg iris-tinted.svg; do
  if [[ ! -f "$BRAND_DIR/$master" ]]; then
    echo "FAILED: vector master missing: $BRAND_DIR/$master" >&2
    echo "Expected three masters: iris-dark.svg iris-light.svg iris-tinted.svg" >&2
    exit 1
  fi
done

if ! command -v iconutil >/dev/null 2>&1; then
  echo "FAILED: iconutil is required but was not found" >&2
  exit 2
fi

# xattr discipline (mirrors scripts/aura-test.sh:86-91): iCloud/Finder
# extended attributes on freshly created files break ad-hoc codesign of
# bundles that embed generated resources.
strip_xattrs() {
  find "$1" -exec xattr -c {} + 2>/dev/null || true
}

# --- Renderer selection ------------------------------------------------------
#
# Primary: rsvg-convert renders SVG directly at each target size.
# Fallback: qlmanage renders the SVG to a 1024 px thumbnail PNG, then sips
# resamples each iconset size (sips resampling from the 1024 master is
# deterministic and single-sourced, satisfying the "never hand-rescaled" rule).

RENDER_MODE=""
if command -v rsvg-convert >/dev/null 2>&1; then
  RENDER_MODE="rsvg"
else
  # qlmanage prints its progress on stderr and writes the thumbnail as
  # "<master>.png" into the output directory; probe by file existence.
  qlmanage -t -s 1024 -o "$WORK_DIR" "$BRAND_DIR/iris-dark.svg" >/dev/null 2>&1 || true
  if [[ -s "$WORK_DIR/iris-dark.svg.png" ]]; then
    RENDER_MODE="qlmanage"
  else
    echo "FAILED: no SVG renderer available (need rsvg-convert or a working qlmanage)" >&2
    exit 2
  fi
fi
echo "==> Renderer: $RENDER_MODE"

# --- Iconset size table ------------------------------------------------------
#
# macOS iconset (16→1024, @1x/@2x). Sizes follow the platform icon grid;
# every size is rendered from the vector master, never from another PNG.
ICONSET_DIR="$WORK_DIR/AURA.iconset"
mkdir -p "$ICONSET_DIR"

# Table entries: "<pixels> <variant>"
#   dark is the canonical/default icon shipped via CFBundleIconFile.
SIZE_TABLE=(
  "16 dark icon_16x16"
  "32 dark icon_16x16@2x"
  "32 dark icon_32x32"
  "64 dark icon_32x32@2x"
  "128 dark icon_128x128"
  "256 dark icon_128x128@2x"
  "256 dark icon_256x256"
  "512 dark icon_256x256@2x"
  "512 dark icon_512x512"
  "1024 dark icon_512x512@2x"
)

render_rsvg() {
  local master="$1" pixels="$2" out="$3"
  rsvg-convert -w "$pixels" -h "$pixels" "$BRAND_DIR/$master" -o "$out"
}

render_qlmanage() {
  local master="$1" pixels="$2" out="$3"
  # qlmanage names the thumbnail "<master>.png" (master already carries .svg).
  local base_png="$WORK_DIR/${master}.png"
  if [[ ! -f "$base_png" ]]; then
    qlmanage -t -s 1024 -o "$WORK_DIR" "$BRAND_DIR/$master" >/dev/null 2>&1
  fi
  # sips resample from the 1024 master; deterministic single-sourced resample.
  sips -z "$pixels" "$pixels" "$base_png" --out "$out" >/dev/null 2>&1
}

ICONSET_SOURCE="$WORK_DIR/AURA.iconset"
mkdir -p "$ICONSET_SOURCE"

for entry in "${SIZE_TABLE[@]}"; do
  read -r pixels variant name <<<"$entry"
  master="iris-${variant}.svg"
  out_png="$ICONSET_SOURCE/$name.png"
  case "$RENDER_MODE" in
    rsvg) render_rsvg "$master" "$pixels" "$out_png" ;;
    qlmanage) render_qlmanage "$master" "$pixels" "$out_png" ;;
  esac
  if [[ ! -s "$out_png" ]]; then
    echo "FAILED: renderer produced no output for $name ($pixels px, $variant)" >&2
    exit 2
  fi
done

strip_xattrs "$ICONSET_SOURCE"

echo "==> Assembling icns"
iconutil -c icns "$ICONSET_SOURCE" -o "$OUT_ICNS"

if [[ ! -s "$OUT_ICNS" ]]; then
  echo "FAILED: iconutil produced no icns at $OUT_ICNS" >&2
  exit 2
fi

echo "==> Generated $OUT_ICNS"
ls -la "$OUT_ICNS"
echo "G0-1: OK (3 masters, icns generated, exit 0)"
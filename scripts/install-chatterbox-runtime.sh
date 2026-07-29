#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/Runtime/chatterbox"
AURA_SUPPORT_ROOT="${AURA_SUPPORT_ROOT:-${HOME}/Library/Application Support/AURA}"
RUNTIME_ROOT="$AURA_SUPPORT_ROOT/Runtime/chatterbox"
MODEL_DIR="$AURA_SUPPORT_ROOT/Models/chatterbox-v3"
VOICE_DIR="$AURA_SUPPORT_ROOT/Voices"
ENVIRONMENT_DIR="$RUNTIME_ROOT/.venv"

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required to install the pinned Chatterbox runtime." >&2
  exit 1
fi

mkdir -p "$RUNTIME_ROOT" "$MODEL_DIR" "$VOICE_DIR"
chmod 700 "$RUNTIME_ROOT" "$MODEL_DIR" "$VOICE_DIR"

uv python install 3.11.15
UV_PROJECT_ENVIRONMENT="$ENVIRONMENT_DIR" \
  uv sync \
    --project "$PROJECT_DIR" \
    --python 3.11.15 \
    --frozen

"$ENVIRONMENT_DIR/bin/python" \
  "$PROJECT_DIR/install_model.py" \
  --model-dir "$MODEL_DIR"

echo "Chatterbox runtime installed:"
echo "  Python: $ENVIRONMENT_DIR/bin/python"
echo "  Model:  $MODEL_DIR"
echo "Add an owned/consented female Turkish WAV at:"
echo "  $VOICE_DIR/aura-female-reference.wav"

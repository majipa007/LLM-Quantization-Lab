#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

HF_BIN="$VENV_DIR/bin/hf"
require_executable "$HF_BIN"
require_dir "$HF_UPLOAD_DIR"

if [[ "$HF_REPO_ID" == YOUR_USERNAME/* ]]; then
  die "Set HF_REPO_ID in config.env before uploading."
fi

if ! "$HF_BIN" auth whoami >/dev/null 2>&1; then
  die "Not logged in to Hugging Face. Run: $HF_BIN auth login"
fi

create_args=(repos create "$HF_REPO_ID" --exist-ok)
if [[ "${HF_PRIVATE,,}" == "true" ]]; then
  create_args+=(--private)
fi

log "Creating/checking Hugging Face repo: $HF_REPO_ID"
"$HF_BIN" "${create_args[@]}"

log "Uploading GGUF files and model card"
export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"
"$HF_BIN" upload "$HF_REPO_ID" "$HF_UPLOAD_DIR" . \
  --revision "$HF_REVISION" \
  --commit-message "Upload ${MODEL_NAME} GGUF quantization experiment"

log "Upload complete: https://huggingface.co/$HF_REPO_ID"

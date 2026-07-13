#!/usr/bin/env bash
#
# 13_upload_huggingface.sh — publish the hf_upload/ folder to Hugging Face.
#
# Uses the `hf` CLI to create (or reuse) the target repo and upload the staged
# folder. Verifies HF_REPO_ID was configured and that you are logged in first,
# so it fails early instead of halfway through an upload.
#
# Outputs: files pushed to the Hugging Face repo $HF_REPO_ID (nothing local).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Need the hf CLI and a prepared upload folder (from script 12).
HF_BIN="$VENV_DIR/bin/hf"
require_executable "$HF_BIN"
require_dir "$HF_UPLOAD_DIR"

# Refuse to run until the placeholder repo id has been replaced in config.env.
if [[ "$HF_REPO_ID" == YOUR_USERNAME/* ]]; then
  die "Set HF_REPO_ID in config.env before uploading."
fi

# Make sure we are authenticated before attempting any uploads.
if ! "$HF_BIN" auth whoami >/dev/null 2>&1; then
  die "Not logged in to Hugging Face. Run: $HF_BIN auth login"
fi

# Build repo-creation args; add --private when HF_PRIVATE is set to "true".
create_args=(repos create "$HF_REPO_ID" --exist-ok)
if [[ "${HF_PRIVATE,,}" == "true" ]]; then
  create_args+=(--private)
fi

# Ensure the repo exists (--exist-ok makes this a no-op if it already does).
log "Creating/checking Hugging Face repo: $HF_REPO_ID"
"$HF_BIN" "${create_args[@]}"

# Upload the whole staging folder. Enable Xet high-performance transfer unless
# the caller already set it. The "." maps the local folder to the repo root.
log "Uploading GGUF files and model card"
export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"
"$HF_BIN" upload "$HF_REPO_ID" "$HF_UPLOAD_DIR" . \
  --revision "$HF_REVISION" \
  --commit-message "Upload ${MODEL_NAME} GGUF quantization experiment"

log "Upload complete: https://huggingface.co/$HF_REPO_ID"

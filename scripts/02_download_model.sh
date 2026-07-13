#!/usr/bin/env bash
#
# 02_download_model.sh — download the source model from Hugging Face.
#
# Uses the `hf` CLI (installed into the venv by script 01) to fetch the model
# at the requested revision, then records the exact resolved commit hash so the
# download can be reproduced later.
#
# Outputs: models/hf/<MODEL_NAME>/ and results/metadata/hf_model_*.txt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# The HF CLI lives in the venv created by script 01.
require_executable "$VENV_DIR/bin/hf"

# Download the model files into models/hf/<MODEL_NAME>/.
log "Downloading $MODEL_REPO at revision $MODEL_REVISION"
"$VENV_DIR/bin/hf" download "$MODEL_REPO" \
  --revision "$MODEL_REVISION" \
  --local-dir "$HF_MODEL_DIR"

# A branch/tag like "main" moves over time. Ask the Hub API for the exact
# commit it resolved to and save it, so the experiment stays reproducible.
"$VENV_DIR/bin/python" - "$MODEL_REPO" "$MODEL_REVISION" "$METADATA_DIR/hf_model_commit.txt" <<'PY'
import sys
from huggingface_hub import HfApi

repo_id, revision, output = sys.argv[1:]
info = HfApi().model_info(repo_id=repo_id, revision=revision)
with open(output, "w", encoding="utf-8") as f:
    f.write(f"{info.sha}\n")
print(f"Resolved Hugging Face commit: {info.sha}")
PY

# Also record what we asked for (repo id and requested revision).
printf '%s\n' "$MODEL_REPO" > "$METADATA_DIR/hf_model_repo.txt"
printf '%s\n' "$MODEL_REVISION" > "$METADATA_DIR/hf_model_requested_revision.txt"

log "Model downloaded to $HF_MODEL_DIR"

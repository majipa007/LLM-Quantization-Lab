#!/usr/bin/env bash
#
# 03_convert_to_gguf.sh — convert the downloaded HF model to a GGUF file.
#
# This produces the full-precision baseline GGUF (e.g. BF16) that every later
# quantization is derived from, using llama.cpp's convert_hf_to_gguf.py.
#
# Outputs: models/gguf/<MODEL_NAME>-BF16.gguf and results/raw/convert.log

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Need the downloaded model, the converter script, and the venv's Python.
require_dir "$HF_MODEL_DIR"
require_file "$LLAMA_CPP_DIR/convert_hf_to_gguf.py"
require_executable "$VENV_DIR/bin/python"

# Build the conversion command as an array (safe quoting, easy to log).
log "Converting Hugging Face model to GGUF ($OUTTYPE)"
cmd=(
  "$VENV_DIR/bin/python"
  "$LLAMA_CPP_DIR/convert_hf_to_gguf.py"
  "$HF_MODEL_DIR"
  --outfile "$GGUF_BF16"
  --outtype "$OUTTYPE"
)

# Save the exact command, then run it while teeing output to a log.
write_command_log "$METADATA_DIR/convert_command.txt" "${cmd[@]}"
"${cmd[@]}" 2>&1 | tee "$RESULTS_DIR/raw/convert.log"

# Confirm the output really got created.
require_file "$GGUF_BF16"
log "Created $GGUF_BF16"

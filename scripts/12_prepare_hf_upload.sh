#!/usr/bin/env bash
#
# 12_prepare_hf_upload.sh — assemble the hf_upload/ staging folder for release.
#
# Collects everything needed to publish on Hugging Face: hard-links (or copies)
# each GGUF into the folder, renders the model card from hf_model_card_template.md
# by substituting {{PLACEHOLDERS}}, and copies the result CSVs and SHA256SUMS in.
#
# Outputs: hf_upload/ containing the GGUF files, README.md (model card),
#          SHA256SUMS, and the size/speed/perplexity result CSVs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Start from a clean staging folder.
rm -rf "$HF_UPLOAD_DIR"
mkdir -p "$HF_UPLOAD_DIR"

# Temp file collects the markdown bullet list of quant filenames for the model card.
model_count=0
quant_list_file="$(mktemp)"
trap 'rm -f "$quant_list_file"' EXIT

# Stage each GGUF model into the upload folder.
while IFS= read -r -d '' model; do
  ((model_count+=1))
  destination="$HF_UPLOAD_DIR/$(basename "$model")"

  # Hard links avoid duplicating multi-GB files while presenting regular files
  # to the uploader. Fall back to a copy when hard links are unavailable.
  if ! ln "$model" "$destination" 2>/dev/null; then
    cp --reflink=auto "$model" "$destination"
  fi

  # Add this model to the bullet list rendered into the model card.
  printf -- '- `%s`\n' "$(basename "$model")" >> "$quant_list_file"
done < <(list_gguf_models)

(( model_count > 0 )) || die "No GGUF files found in $GGUF_DIR"

# Read the recorded source commits if available; otherwise mark them unknown.
hf_model_commit="unknown"
llama_cpp_commit="unknown"
[[ -f "$METADATA_DIR/hf_model_commit.txt" ]] && hf_model_commit="$(cat "$METADATA_DIR/hf_model_commit.txt")"
[[ -f "$METADATA_DIR/llama_cpp_commit.txt" ]] && llama_cpp_commit="$(cat "$METADATA_DIR/llama_cpp_commit.txt")"

# Render the model card: run an inline Python script that reads the template,
# replaces each {{PLACEHOLDER}} with the shell values expanded below, and writes
# hf_upload/README.md. Args passed to Python: template path, output path, quant-list path.
require_file "$ROOT_DIR/hf_model_card_template.md"
"${VENV_DIR}/bin/python" - \
  "$ROOT_DIR/hf_model_card_template.md" \
  "$HF_UPLOAD_DIR/README.md" \
  "$quant_list_file" <<PY
from pathlib import Path
import sys

template_path, output_path, quant_list_path = sys.argv[1:]
text = Path(template_path).read_text(encoding="utf-8")
quant_list = Path(quant_list_path).read_text(encoding="utf-8").strip()

replacements = {
    "{{MODEL_REPO}}": "${MODEL_REPO}",
    "{{MODEL_REVISION}}": "${MODEL_REVISION}",
    "{{MODEL_NAME}}": "${MODEL_NAME}",
    "{{HF_MODEL_COMMIT}}": "${hf_model_commit}",
    "{{LLAMA_CPP_REF}}": "${LLAMA_CPP_REF}",
    "{{LLAMA_CPP_COMMIT}}": "${llama_cpp_commit}",
    "{{OUTTYPE}}": "${OUTTYPE}",
    "{{THREADS}}": "${THREADS}",
    "{{GPU_LAYERS}}": "${GPU_LAYERS}",
    "{{PROMPT_TOKENS}}": "${PROMPT_TOKENS}",
    "{{GEN_TOKENS}}": "${GEN_TOKENS}",
    "{{BENCH_REPETITIONS}}": "${BENCH_REPETITIONS}",
    "{{PPL_CONTEXT}}": "${PPL_CONTEXT}",
    "{{PPL_CHUNKS}}": "${PPL_CHUNKS}",
    "{{QUANT_LIST}}": quant_list,
}
for old, new in replacements.items():
    text = text.replace(old, new)
Path(output_path).write_text(text, encoding="utf-8")
PY

# Copy the checksums and result CSVs into the folder if they exist.
[[ -f "$RESULTS_DIR/SHA256SUMS" ]] && cp "$RESULTS_DIR/SHA256SUMS" "$HF_UPLOAD_DIR/SHA256SUMS"
[[ -f "$RESULTS_DIR/size_results.csv" ]] && cp "$RESULTS_DIR/size_results.csv" "$HF_UPLOAD_DIR/size_results.csv"
[[ -f "$RESULTS_DIR/speed_results.csv" ]] && cp "$RESULTS_DIR/speed_results.csv" "$HF_UPLOAD_DIR/speed_results.csv"
[[ -f "$RESULTS_DIR/perplexity_results.csv" ]] && cp "$RESULTS_DIR/perplexity_results.csv" "$HF_UPLOAD_DIR/perplexity_results.csv"

log "Prepared Hugging Face upload folder at $HF_UPLOAD_DIR"
warn "Add the companion GitHub URL to $HF_UPLOAD_DIR/README.md before publishing."

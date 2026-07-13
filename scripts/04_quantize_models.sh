#!/usr/bin/env bash
#
# 04_quantize_models.sh — create every quantized GGUF from the BF16 baseline.
#
# Loops over the QUANTS list from config.env and runs llama-quantize once per
# format. Already-built formats are skipped, so the script is safe to re-run.
# By default a failed format is logged and skipped; set STRICT_QUANTIZATION=true
# to stop on the first failure instead.
#
# Outputs: models/gguf/<MODEL_NAME>-<QUANT>.gguf and logs under
#          results/raw/quantization/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

QUANTIZER="$BIN_DIR/llama-quantize"
require_executable "$QUANTIZER"
require_file "$GGUF_BF16"     # the baseline we quantize from

mkdir -p "$RESULTS_DIR/raw/quantization"
failures=()   # collects any formats that fail

# Build one GGUF per requested quant format, into the quantized/ subfolder
# (the BF16 baseline stays one level up in GGUF_DIR).
for quant in "${QUANTS[@]}"; do
  output="$GGUF_QUANT_DIR/${MODEL_NAME}-${quant}.gguf"
  log_file="$RESULTS_DIR/raw/quantization/${quant}.log"
  command_file="$RESULTS_DIR/raw/quantization/${quant}.command.txt"

  # Don't redo work: skip if this format already exists.
  if [[ -f "$output" ]]; then
    log "Skipping $quant because output already exists"
    continue
  fi

  # Assemble the command, optionally adding an importance matrix.
  cmd=("$QUANTIZER")
  if [[ -n "$IMATRIX_FILE" ]]; then
    require_file "$IMATRIX_FILE"
    cmd+=(--imatrix "$IMATRIX_FILE")
  fi
  cmd+=("$GGUF_BF16" "$output" "$quant" "$THREADS")

  log "Quantizing to $quant"
  write_command_log "$command_file" "${cmd[@]}"

  # Run it. On failure, delete the partial file and record the format.
  if "${cmd[@]}" 2>&1 | tee "$log_file"; then
    log "Created $output"
  else
    rm -f "$output"
    failures+=("$quant")
    warn "Quantization failed for $quant. See $log_file"
    if [[ "${STRICT_QUANTIZATION,,}" == "true" ]]; then
      die "Stopping because STRICT_QUANTIZATION=true"
    fi
  fi
done

# Write (or clear) a summary of which formats failed.
if (( ${#failures[@]} > 0 )); then
  printf '%s\n' "${failures[@]}" > "$RESULTS_DIR/failed_quantizations.txt"
  warn "Unsupported/failed quantizations: ${failures[*]}"
else
  rm -f "$RESULTS_DIR/failed_quantizations.txt"
fi

log "Quantization stage complete"

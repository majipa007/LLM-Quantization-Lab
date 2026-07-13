#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

PPL_BIN="$BIN_DIR/llama-perplexity"
WIKITEXT_FILE="$DATA_DIR/wikitext-2-raw/wiki.test.raw"

require_executable "$PPL_BIN"
require_file "$WIKITEXT_FILE"

summary_csv="$RESULTS_DIR/perplexity_results.csv"
printf 'format,ppl,uncertainty,context,chunks,threads,gpu_layers,status\n' > "$summary_csv"

model_count=0
while IFS= read -r -d '' model; do
  ((model_count+=1))
  format="$(quant_from_filename "$model")"
  safe_format="${format//[^A-Za-z0-9_.-]/_}"
  log_file="$RAW_PPL_DIR/${safe_format}.log"
  command_file="$RAW_PPL_DIR/${safe_format}.command.txt"

  cmd=(
    "$PPL_BIN"
    -m "$model"
    -f "$WIKITEXT_FILE"
    -c "$PPL_CONTEXT"
    -t "$THREADS"
    -ngl "$GPU_LAYERS"
  )

  if [[ "$PPL_CHUNKS" =~ ^[1-9][0-9]*$ ]]; then
    cmd+=(--chunks "$PPL_CHUNKS")
  fi

  log "Benchmarking perplexity: $format"
  write_command_log "$command_file" "${cmd[@]}"

  if "${cmd[@]}" 2>&1 | tee "$log_file"; then
    final_line="$(grep -E 'Final estimate: PPL = ' "$log_file" | tail -n 1 || true)"
    if [[ "$final_line" =~ PPL[[:space:]]*=[[:space:]]*([0-9.eE+-]+)[[:space:]]*\+/-[[:space:]]*([0-9.eE+-]+) ]]; then
      ppl="${BASH_REMATCH[1]}"
      uncertainty="${BASH_REMATCH[2]}"
      status="ok"
    else
      ppl=""
      uncertainty=""
      status="parse_failed"
    fi
  else
    ppl=""
    uncertainty=""
    status="command_failed"
  fi

  printf '"%s","%s","%s",%s,%s,%s,%s,"%s"\n' \
    "$format" "$ppl" "$uncertainty" "$PPL_CONTEXT" "$PPL_CHUNKS" \
    "$THREADS" "$GPU_LAYERS" "$status" >> "$summary_csv"
done < <(list_gguf_models)

(( model_count > 0 )) || die "No GGUF files found in $GGUF_DIR"

log "Wrote $summary_csv"
column -s, -t "$summary_csv" 2>/dev/null || cat "$summary_csv"

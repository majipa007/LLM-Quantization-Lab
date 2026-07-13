#!/usr/bin/env bash
#
# 08_benchmark_perplexity.sh — measure model quality (perplexity) for each GGUF.
#
# Runs llama-perplexity on every quantized model against the WikiText-2 corpus
# from step 07. Lower perplexity = better; comparing each quant to the baseline
# shows how much quality each compression level costs. Each run's outcome is
# recorded with a status column (ok / parse_failed / command_failed).
#
# Outputs: results/perplexity_results.csv (plus per-format logs in RAW_PPL_DIR)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

PPL_BIN="$BIN_DIR/llama-perplexity"
WIKITEXT_FILE="$DATA_DIR/wikitext-2-raw/wiki.test.raw"

# Preconditions: the llama-perplexity binary and the WikiText-2 test file (from step 07) must exist.
require_executable "$PPL_BIN"
require_file "$WIKITEXT_FILE"

summary_csv="$RESULTS_DIR/perplexity_results.csv"
# Write the CSV header row.
printf 'format,ppl,uncertainty,context,chunks,threads,gpu_layers,status\n' > "$summary_csv"

model_count=0
# Iterate over every GGUF (NUL-separated so filenames with spaces are safe).
while IFS= read -r -d '' model; do
  ((model_count+=1))
  format="$(quant_from_filename "$model")"     # e.g. "Q4_K_M" derived from the filename
  safe_format="${format//[^A-Za-z0-9_.-]/_}"   # sanitize for use in filenames
  log_file="$RAW_PPL_DIR/${safe_format}.log"
  command_file="$RAW_PPL_DIR/${safe_format}.command.txt"

  # Build the llama-perplexity invocation: model, corpus, context size, threads, GPU layers.
  cmd=(
    "$PPL_BIN"
    -m "$model"
    -f "$WIKITEXT_FILE"
    -c "$PPL_CONTEXT"
    -t "$THREADS"
    -ngl "$GPU_LAYERS"
  )

  # Optionally cap the number of chunks evaluated (only when PPL_CHUNKS is a positive integer).
  if [[ "$PPL_CHUNKS" =~ ^[1-9][0-9]*$ ]]; then
    cmd+=(--chunks "$PPL_CHUNKS")
  fi

  log "Benchmarking perplexity: $format"
  write_command_log "$command_file" "${cmd[@]}"   # record the exact command for reproducibility

  # Run it, teeing all output to the log. If the command succeeds, pull the final PPL line;
  # otherwise mark the run as command_failed.
  if "${cmd[@]}" 2>&1 | tee "$log_file"; then
    # Grab the last "Final estimate: PPL = ..." line and extract the value and its +/- uncertainty.
    final_line="$(grep -E 'Final estimate: PPL = ' "$log_file" | tail -n 1 || true)"
    if [[ "$final_line" =~ PPL[[:space:]]*=[[:space:]]*([0-9.eE+-]+)[[:space:]]*\+/-[[:space:]]*([0-9.eE+-]+) ]]; then
      ppl="${BASH_REMATCH[1]}"
      uncertainty="${BASH_REMATCH[2]}"
      status="ok"
    else
      # Command ran but the expected line wasn't found/parseable.
      ppl=""
      uncertainty=""
      status="parse_failed"
    fi
  else
    # The perplexity binary itself exited non-zero.
    ppl=""
    uncertainty=""
    status="command_failed"
  fi

  # Append one CSV row per model, including the run's status.
  printf '"%s","%s","%s",%s,%s,%s,%s,"%s"\n' \
    "$format" "$ppl" "$uncertainty" "$PPL_CONTEXT" "$PPL_CHUNKS" \
    "$THREADS" "$GPU_LAYERS" "$status" >> "$summary_csv"
done < <(list_gguf_models)   # list_gguf_models emits every GGUF, NUL-separated and sorted

# Fail loudly if the directory turned out to have no models to benchmark.
(( model_count > 0 )) || die "No GGUF files found in $GGUF_DIR"

log "Wrote $summary_csv"
# Pretty-print the CSV as an aligned table if `column` is available, else dump raw.
column -s, -t "$summary_csv" 2>/dev/null || cat "$summary_csv"

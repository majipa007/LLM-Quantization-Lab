#!/usr/bin/env bash
#
# 06_benchmark_speed.sh — measure inference throughput for each GGUF.
#
# Runs llama-bench on each GGUF to measure prompt-processing and text-generation
# speed (tokens/second), then parses llama-bench's JSON with jq into a tidy CSV.
#
# Like the perplexity stage, this is interactive and resumable:
#   * Before each model you are asked whether to run it (y/n).
#   * Each model's parsed rows are saved as soon as it finishes.
#   * On a later run, models that already have a saved result are skipped —
#     you are asked whether to rerun and overwrite them.
# So a paused run resumes without recomputing finished models.
#
# Outputs:
#   results/speed_results.csv                (rebuilt from the per-model results)
#   results/raw/speed/<fmt>.result.csv        (saved parsed rows per model)
#   results/raw/speed/<fmt>.json / .stderr.log (raw llama-bench output)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Preconditions: the llama-bench binary must exist and jq must be installed to parse its JSON.
BENCH="$BIN_DIR/llama-bench"
require_executable "$BENCH"
require_command jq

summary_csv="$RESULTS_DIR/speed_results.csv"
CSV_HEADER='format,test,tokens,threads,backend,gpu_layers,avg_tps,stddev_tps,model_size_bytes,model_params,build_commit,test_time'

# ask_yes_no (prompt-per-model, /dev/tty, unattended fallback) comes from lib/common.sh.

# Rebuild the summary CSV from every saved per-model result, in GGUF order.
# Called after each model so the summary always reflects what has been done.
write_summary() {
  printf '%s\n' "$CSV_HEADER" > "$summary_csv"
  local fmt safe rf
  while IFS= read -r -d '' m; do
    fmt="$(quant_from_filename "$m")"
    safe="${fmt//[^A-Za-z0-9_.-]/_}"
    rf="$RAW_SPEED_DIR/${safe}.result.csv"
    # Full if (not `[[ ]] && cat`): under `set -e` a false test as the loop
    # body's last command would abort the script.
    if [[ -f "$rf" ]]; then
      cat "$rf" >> "$summary_csv"
    fi
  done < <(list_gguf_models)
}

model_count=0
# Iterate over every GGUF (NUL-separated so filenames with spaces are safe).
while IFS= read -r -d '' model; do
  ((model_count+=1))
  format="$(quant_from_filename "$model")"        # e.g. "Q4_K_M" from the filename
  safe_format="${format//[^A-Za-z0-9_.-]/_}"      # sanitize for use in filenames
  result_file="$RAW_SPEED_DIR/${safe_format}.result.csv"  # saved parsed rows
  raw_json="$RAW_SPEED_DIR/${safe_format}.json"   # llama-bench JSON output
  raw_err="$RAW_SPEED_DIR/${safe_format}.stderr.log"
  command_file="$RAW_SPEED_DIR/${safe_format}.command.txt"

  # Decide whether to run this model.
  if [[ -f "$result_file" ]]; then
    if ask_yes_no "[$format] already benchmarked. Rerun and overwrite? [y/N]" "N"; then
      log "Rerunning $format"
    else
      log "Keeping existing result for $format"
      continue
    fi
  else
    if ! ask_yes_no "[$format] not benchmarked yet. Run speed benchmark now? [Y/n]" "Y"; then
      log "Skipping $format for now"
      continue
    fi
  fi

  # Build the llama-bench invocation: model, threads, GPU layers, prompt/gen tokens, repetitions.
  cmd=(
    "$BENCH"
    -m "$model"
    -t "$THREADS"
    -ngl "$GPU_LAYERS"
    -p "$PROMPT_TOKENS"
    -n "$GEN_TOKENS"
    -r "$BENCH_REPETITIONS"
    -o json
  )

  log "Benchmarking speed: $format"
  write_command_log "$command_file" "${cmd[@]}"   # record the exact command
  # Run the benchmark: stdout -> JSON file; stderr is both shown and saved.
  # stdin from /dev/null so it can't consume the piped model list driving the loop.
  "${cmd[@]}" < /dev/null > "$raw_json" 2> >(tee "$raw_err" >&2)

  # Parse each result row from the JSON into one CSV line. The `test` column is derived from
  # the token counts: "pp<N>" = prompt processing only, "tg<N>" = text generation only,
  # "pg<N>+<M>" = combined. `tokens` is whichever of prompt/gen tokens is non-zero.
  # Write to the per-model result file first (the "saved after each model" guarantee).
  jq -r --arg format "$format" '
    .[] |
    [
      $format,
      (if .n_prompt > 0 and .n_gen == 0 then "pp" + (.n_prompt|tostring)
       elif .n_prompt == 0 and .n_gen > 0 then "tg" + (.n_gen|tostring)
       else "pg" + (.n_prompt|tostring) + "+" + (.n_gen|tostring)
       end),
      (if .n_prompt > 0 then .n_prompt else .n_gen end),
      .n_threads,
      .backends,
      .n_gpu_layers,
      .avg_ts,
      .stddev_ts,
      .model_size,
      .model_n_params,
      .build_commit,
      .test_time
    ] | @csv
  ' "$raw_json" > "$result_file"

  # Refresh the combined summary so it always reflects what has been done.
  write_summary
  log "Saved result for $format"
done < <(list_gguf_models)   # list_gguf_models emits every GGUF, NUL-separated and sorted

# Fail loudly if there were no models at all.
(( model_count > 0 )) || die "No GGUF files found in $GGUF_DIR"

# Make sure the summary exists even if every model was skipped this run.
[[ -f "$summary_csv" ]] || write_summary

log "Wrote $summary_csv"
# Pretty-print the CSV as an aligned table if `column` is available, else dump raw.
column -s, -t "$summary_csv" 2>/dev/null || cat "$summary_csv"

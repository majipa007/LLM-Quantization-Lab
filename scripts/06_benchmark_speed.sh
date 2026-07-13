#!/usr/bin/env bash
#
# 06_benchmark_speed.sh — measure inference throughput for each GGUF.
#
# Runs llama-bench on every quantized model to measure prompt-processing and
# text-generation speed (tokens/second), then parses llama-bench's JSON output
# with jq into a single tidy CSV. Raw JSON/logs are kept per format for audit.
#
# Outputs: results/speed_results.csv (plus raw JSON/stderr/command logs in RAW_SPEED_DIR)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Preconditions: the llama-bench binary must exist and jq must be installed to parse its JSON.
BENCH="$BIN_DIR/llama-bench"
require_executable "$BENCH"
require_command jq

summary_csv="$RESULTS_DIR/speed_results.csv"
# Write the CSV header row.
printf 'format,test,tokens,threads,backend,gpu_layers,avg_tps,stddev_tps,model_size_bytes,model_params,build_commit,test_time\n' > "$summary_csv"

model_count=0
# Iterate over every GGUF (NUL-separated so filenames with spaces are safe).
while IFS= read -r -d '' model; do
  ((model_count+=1))
  format="$(quant_from_filename "$model")"        # e.g. "Q4_K_M" derived from the filename
  safe_format="${format//[^A-Za-z0-9_.-]/_}"      # sanitize for use in filenames
  raw_json="$RAW_SPEED_DIR/${safe_format}.json"   # llama-bench JSON output
  raw_err="$RAW_SPEED_DIR/${safe_format}.stderr.log"
  command_file="$RAW_SPEED_DIR/${safe_format}.command.txt"

  # Build the llama-bench invocation: model, threads, GPU layers, prompt/gen token counts, repetitions.
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
  write_command_log "$command_file" "${cmd[@]}"   # record the exact command for reproducibility
  # Run the benchmark: stdout goes to the JSON file; stderr is both shown and saved to the log.
  "${cmd[@]}" > "$raw_json" 2> >(tee "$raw_err" >&2)

  # Parse each result row from the JSON into one CSV line. The `test` column is derived from the
  # token counts: "pp<N>" = prompt processing only, "tg<N>" = text generation only,
  # "pg<N>+<M>" = combined. `tokens` is whichever of prompt/gen tokens is non-zero.
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
  ' "$raw_json" >> "$summary_csv"
done < <(list_gguf_models)   # list_gguf_models emits every GGUF, NUL-separated and sorted

# Fail loudly if the directory turned out to have no models to benchmark.
(( model_count > 0 )) || die "No GGUF files found in $GGUF_DIR"

log "Wrote $summary_csv"
# Pretty-print the CSV as an aligned table if `column` is available, else dump raw.
column -s, -t "$summary_csv" 2>/dev/null || cat "$summary_csv"

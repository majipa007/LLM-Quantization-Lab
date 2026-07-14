#!/usr/bin/env bash
#
# 08_benchmark_perplexity.sh — measure model quality (perplexity) per GGUF.
#
# Runs llama-perplexity on each GGUF against the WikiText-2 corpus from step 07.
# Lower perplexity = better; comparing each quant to the BF16 baseline shows how
# much quality each compression level costs.
#
# This stage is SLOW (tens of minutes per model), so it is interactive and
# resumable:
#   * Before each model you are asked whether to run it (y/n).
#   * Each model's result is saved the moment it finishes.
#   * On a later run, models that already have a saved result are skipped —
#     you are asked whether to rerun and overwrite them.
# So you can stop (Ctrl-C) any time and pick up where you left off; only the
# model that was mid-run is lost, never the completed ones.
#
# Outputs:
#   results/perplexity_results.csv         (rebuilt from the per-model results)
#   results/raw/perplexity/<fmt>.result.csv (one saved row per completed model)
#   results/raw/perplexity/<fmt>.log         (full llama-perplexity output)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

PPL_BIN="$BIN_DIR/llama-perplexity"
WIKITEXT_FILE="$DATA_DIR/wikitext-2-raw/wiki.test.raw"

# Preconditions: the binary and the WikiText-2 test file (from step 07) must exist.
require_executable "$PPL_BIN"
require_file "$WIKITEXT_FILE"

summary_csv="$RESULTS_DIR/perplexity_results.csv"
CSV_HEADER='format,ppl,uncertainty,context,chunks,threads,gpu_layers,status'

# Ask a yes/no question on the terminal and return 0 for yes, 1 for no.
#   $1 = prompt text, $2 = default answer ("Y" or "N") used on empty input.
# Reads from /dev/tty (not stdin) because the main loop's stdin is the piped
# model list. If there is no terminal (e.g. run non-interactively), fall back
# to the default so the pipeline can still run unattended.
ask_yes_no() {
  local prompt="$1" default="$2" reply
  if [[ ! -r /dev/tty ]]; then
    [[ "${default^^}" == "Y" ]]
    return
  fi
  read -r -p "$prompt " reply < /dev/tty || reply=""
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy] ]]
}

# Rebuild the summary CSV from every saved per-model result, in GGUF order.
# Called after each model so the summary always reflects what has been done.
write_summary() {
  printf '%s\n' "$CSV_HEADER" > "$summary_csv"
  local fmt safe rf
  while IFS= read -r -d '' m; do
    fmt="$(quant_from_filename "$m")"
    safe="${fmt//[^A-Za-z0-9_.-]/_}"
    rf="$RAW_PPL_DIR/${safe}.result.csv"
    # Use a full if (not `[[ ]] && cat`): under `set -e` a false test as the
    # loop body's last command would abort the script.
    if [[ -f "$rf" ]]; then
      cat "$rf" >> "$summary_csv"
    fi
  done < <(list_gguf_models)
}

model_count=0
# Iterate over every GGUF (NUL-separated so odd filenames are safe).
while IFS= read -r -d '' model; do
  ((model_count+=1))
  format="$(quant_from_filename "$model")"     # e.g. "Q4_K_M" from the filename
  safe_format="${format//[^A-Za-z0-9_.-]/_}"   # sanitize for use in filenames
  result_file="$RAW_PPL_DIR/${safe_format}.result.csv"
  log_file="$RAW_PPL_DIR/${safe_format}.log"
  command_file="$RAW_PPL_DIR/${safe_format}.command.txt"

  # Decide whether to run this model.
  if [[ -f "$result_file" ]]; then
    # Already have a result: show it and ask whether to redo it (default: no).
    prev_ppl="$(cut -d',' -f2 "$result_file" | tr -d '"')"
    prev_status="$(cut -d',' -f8 "$result_file" | tr -d '"')"
    if ask_yes_no "[$format] already done (status=$prev_status, PPL=$prev_ppl). Rerun and overwrite? [y/N]" "N"; then
      log "Rerunning $format"
    else
      log "Keeping existing result for $format"
      continue
    fi
  else
    # No result yet: ask whether to run it (default: yes).
    if ! ask_yes_no "[$format] not benchmarked yet. Run perplexity now? [Y/n]" "Y"; then
      log "Skipping $format for now"
      continue
    fi
  fi

  # Build the llama-perplexity invocation: model, corpus, context, threads, GPU layers.
  cmd=(
    "$PPL_BIN"
    -m "$model"
    -f "$WIKITEXT_FILE"
    -c "$PPL_CONTEXT"
    -t "$THREADS"
    -ngl "$GPU_LAYERS"
  )

  # Optionally cap the number of chunks (only when PPL_CHUNKS is a positive integer).
  if [[ "$PPL_CHUNKS" =~ ^[1-9][0-9]*$ ]]; then
    cmd+=(--chunks "$PPL_CHUNKS")
  fi

  log "Benchmarking perplexity: $format"
  write_command_log "$command_file" "${cmd[@]}"   # record the exact command

  # Run it, teeing all output to the log. Redirect the command's stdin from
  # /dev/null so it can never consume the piped model list driving the loop.
  if "${cmd[@]}" < /dev/null 2>&1 | tee "$log_file"; then
    # Grab the last "Final estimate: PPL = ..." line; extract value and +/- uncertainty.
    final_line="$(grep -E 'Final estimate: PPL = ' "$log_file" | tail -n 1 || true)"
    if [[ "$final_line" =~ PPL[[:space:]]*=[[:space:]]*([0-9.eE+-]+)[[:space:]]*\+/-[[:space:]]*([0-9.eE+-]+) ]]; then
      ppl="${BASH_REMATCH[1]}"
      uncertainty="${BASH_REMATCH[2]}"
      status="ok"
    else
      ppl=""; uncertainty=""; status="parse_failed"   # ran, but no parseable result
    fi
  else
    ppl=""; uncertainty=""; status="command_failed"    # binary exited non-zero
  fi

  # Save THIS model's result immediately, then refresh the combined summary.
  # This is the "saved after each model" guarantee: a later Ctrl-C won't lose it.
  printf '"%s","%s","%s",%s,%s,%s,%s,"%s"\n' \
    "$format" "$ppl" "$uncertainty" "$PPL_CONTEXT" "$PPL_CHUNKS" \
    "$THREADS" "$GPU_LAYERS" "$status" > "$result_file"
  write_summary
  log "Saved result for $format (status=$status, PPL=$ppl)"
done < <(list_gguf_models)   # list_gguf_models emits every GGUF, NUL-separated and sorted

# Fail loudly if there were no models at all.
(( model_count > 0 )) || die "No GGUF files found in $GGUF_DIR"

# Make sure the summary exists even if every model was skipped this run.
[[ -f "$summary_csv" ]] || write_summary

log "Wrote $summary_csv"
# Pretty-print the CSV as an aligned table if `column` is available, else dump raw.
column -s, -t "$summary_csv" 2>/dev/null || cat "$summary_csv"

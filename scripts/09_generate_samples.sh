#!/usr/bin/env bash
#
# 09_generate_samples.sh — generate text samples from every quantized model.
#
# For each GGUF and each prompt in data/prompts.txt, runs llama-cli with a fixed
# seed and temperature so outputs are reproducible. These samples let you eyeball
# how each quantization level affects generation quality.
#
# Outputs: results/raw/generations/<format>/prompt_NN.txt (plus a .command.txt
#          alongside each recording the exact command used).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Need the llama-cli binary and the prompt list to exist.
CLI="$BIN_DIR/llama-cli"
PROMPTS_FILE="$DATA_DIR/prompts.txt"
require_executable "$CLI"
require_file "$PROMPTS_FILE"

# Loop over every GGUF model (NUL-separated, sorted by list_gguf_models).
model_count=0
while IFS= read -r -d '' model; do
  ((model_count+=1))
  # Derive the quant label (e.g. "Q4_K_M") and sanitize it for use as a dir name.
  format="$(quant_from_filename "$model")"
  safe_format="${format//[^A-Za-z0-9_.-]/_}"
  model_output_dir="$RAW_GEN_DIR/$safe_format"
  mkdir -p "$model_output_dir"

  # Loop over each prompt line; the trailing check handles a last line with no newline.
  prompt_number=0
  while IFS= read -r prompt || [[ -n "$prompt" ]]; do
    # Skip blank lines and comment lines (starting with #).
    [[ -z "$prompt" ]] && continue
    [[ "$prompt" == \#* ]] && continue
    ((prompt_number+=1))

    # One output file (and command log) per prompt, zero-padded for stable sorting.
    output_file="$model_output_dir/prompt_$(printf '%02d' "$prompt_number").txt"
    command_file="$model_output_dir/prompt_$(printf '%02d' "$prompt_number").command.txt"

    # Deterministic generation: fixed seed and temperature, prompt not echoed back.
    cmd=(
      "$CLI"
      -m "$model"
      -p "$prompt"
      -n "$GEN_MAX_TOKENS"
      -t "$THREADS"
      -ngl "$GPU_LAYERS"
      --seed "$GEN_SEED"
      --temp "$GEN_TEMPERATURE"
      --no-display-prompt
    )

    log "Generating sample: $format / prompt $prompt_number"
    # Save the exact command, then write the prompt + generated output to the file.
    write_command_log "$command_file" "${cmd[@]}"
    {
      printf 'PROMPT:\n%s\n\nOUTPUT:\n' "$prompt"
      "${cmd[@]}"
    } > "$output_file" 2>&1
  done < "$PROMPTS_FILE"
done < <(list_gguf_models)

# Fail loudly if no models were found rather than silently doing nothing.
(( model_count > 0 )) || die "No GGUF files found in $GGUF_DIR"
log "Generation samples written to $RAW_GEN_DIR"

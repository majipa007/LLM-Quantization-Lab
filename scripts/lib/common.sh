#!/usr/bin/env bash
#
# common.sh — shared setup for every pipeline script.
#
# Every numbered script (01..13) sources this file first. It does three jobs:
#   1. Turns on strict error handling.
#   2. Loads config.env and fills in default values for anything not set.
#   3. Defines helper functions (log, die, require_*, etc.) used everywhere.
#
# This file is meant to be *sourced*, not run on its own.

# Strict mode: stop on the first error, treat unset variables as errors,
# and make a failure anywhere in a pipe fail the whole pipe.
set -Eeuo pipefail
# Only split words on newlines and tabs (not spaces) to handle paths safely.
IFS=$'\n\t'

# Work out where this file lives, then the project root (two levels up:
# scripts/lib -> scripts -> project root).
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$COMMON_DIR/../.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$ROOT_DIR/config.env}"

# Load the user's settings if config.env exists (it is Bash so it can hold arrays).
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# -------------------------------------------------------------------------
# Settings with defaults.
# The "${VAR:-default}" form means: use VAR if config.env set it, else default.
# So the pipeline works out of the box, and config.env only overrides what it needs.
# -------------------------------------------------------------------------

# --- Which model to quantize ---
MODEL_REPO="${MODEL_REPO:-Qwen/Qwen3-0.6B-Base}"   # Hugging Face repo id
MODEL_REVISION="${MODEL_REVISION:-main}"            # branch/tag/commit to download
MODEL_NAME="${MODEL_NAME:-Qwen3-0.6B}"              # short name used in output filenames
OUTTYPE="${OUTTYPE:-bf16}"                          # precision of the initial GGUF conversion
STRICT_QUANTIZATION="${STRICT_QUANTIZATION:-false}" # true = stop if any quant type fails
IMATRIX_FILE="${IMATRIX_FILE:-}"                    # optional importance matrix file

# --- llama.cpp source and build ---
LLAMA_CPP_REPO="${LLAMA_CPP_REPO:-https://github.com/ggml-org/llama.cpp.git}"
LLAMA_CPP_REF="${LLAMA_CPP_REF:-master}"            # branch/tag/commit to build
BUILD_BACKEND="${BUILD_BACKEND:-cpu}"               # cpu or cuda
BUILD_JOBS="${BUILD_JOBS:-0}"                       # parallel build jobs (0 = all cores)

# --- Benchmark parameters ---
THREADS="${THREADS:-10}"                            # CPU threads for inference
GPU_LAYERS="${GPU_LAYERS:-0}"                       # layers offloaded to GPU (0 = CPU only)
PROMPT_TOKENS="${PROMPT_TOKENS:-512}"               # prompt-processing test size
GEN_TOKENS="${GEN_TOKENS:-128}"                     # text-generation test size
BENCH_REPETITIONS="${BENCH_REPETITIONS:-5}"         # repeats per speed benchmark
PPL_CONTEXT="${PPL_CONTEXT:-4096}"                  # perplexity context window
PPL_CHUNKS="${PPL_CHUNKS:-0}"                       # perplexity chunks (0 = whole corpus)
GEN_MAX_TOKENS="${GEN_MAX_TOKENS:-128}"             # tokens generated per sample prompt
GEN_SEED="${GEN_SEED:-42}"                          # RNG seed for reproducible samples
GEN_TEMPERATURE="${GEN_TEMPERATURE:-0}"             # 0 = greedy/deterministic sampling

# --- Hugging Face upload target ---
HF_REPO_ID="${HF_REPO_ID:-YOUR_USERNAME/${MODEL_NAME}-GGUF}"
HF_PRIVATE="${HF_PRIVATE:-false}"                   # true = create a private repo
HF_REVISION="${HF_REVISION:-main}"                  # branch to upload to

# List of quantization formats to produce. Only set a default if config.env
# did not already define the QUANTS array.
if ! declare -p QUANTS >/dev/null 2>&1; then
  QUANTS=(Q8_0 Q4_K_M Q2_K Q1_0 IQ3_S IQ3_M IQ4_NL IQ4_XS)
fi

# -------------------------------------------------------------------------
# Derived paths. Everything the pipeline reads or writes lives under these.
# -------------------------------------------------------------------------
TOOLS_DIR="${TOOLS_DIR:-$ROOT_DIR/tools}"                    # where llama.cpp is cloned
LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-$TOOLS_DIR/llama.cpp}"       # llama.cpp checkout
LLAMA_BUILD_DIR="${LLAMA_BUILD_DIR:-$LLAMA_CPP_DIR/build}"   # cmake build directory
BIN_DIR="${BIN_DIR:-$LLAMA_BUILD_DIR/bin}"                   # compiled llama-* binaries
VENV_DIR="${VENV_DIR:-$ROOT_DIR/.venv}"                      # Python virtual environment

MODEL_DIR="${MODEL_DIR:-$ROOT_DIR/models}"                  # all model files
HF_MODEL_DIR="${HF_MODEL_DIR:-$MODEL_DIR/hf/$MODEL_NAME}"   # downloaded HF model
GGUF_DIR="${GGUF_DIR:-$MODEL_DIR/gguf}"                     # holds the BF16 baseline GGUF
GGUF_QUANT_DIR="${GGUF_QUANT_DIR:-$GGUF_DIR/quantized}"     # holds the quantized GGUFs
GGUF_BF16="${GGUF_BF16:-$GGUF_DIR/${MODEL_NAME}-BF16.gguf}" # the full-precision GGUF

RESULTS_DIR="${RESULTS_DIR:-$ROOT_DIR/results}"                 # summary CSVs + everything below
RAW_SPEED_DIR="${RAW_SPEED_DIR:-$RESULTS_DIR/raw/speed}"        # raw speed benchmark output
RAW_PPL_DIR="${RAW_PPL_DIR:-$RESULTS_DIR/raw/perplexity}"       # raw perplexity logs
RAW_GEN_DIR="${RAW_GEN_DIR:-$RESULTS_DIR/raw/generations}"      # generated text samples
METADATA_DIR="${METADATA_DIR:-$RESULTS_DIR/metadata}"          # commit hashes, env, config
DATA_DIR="${DATA_DIR:-$ROOT_DIR/data}"                         # prompts + WikiText-2 corpus
HF_UPLOAD_DIR="${HF_UPLOAD_DIR:-$ROOT_DIR/hf_upload}"          # staging folder for HF upload

# Create every directory up front so no script has to worry about it.
mkdir -p \
  "$TOOLS_DIR" "$HF_MODEL_DIR" "$GGUF_DIR" "$GGUF_QUANT_DIR" \
  "$RAW_SPEED_DIR" "$RAW_PPL_DIR" "$RAW_GEN_DIR" \
  "$METADATA_DIR" "$DATA_DIR" "$HF_UPLOAD_DIR"

# -------------------------------------------------------------------------
# Helper functions used by all scripts.
# -------------------------------------------------------------------------

# Print a timestamped, blue-highlighted status line.
log() {
  printf '\n\033[1;34m[%s]\033[0m %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# Print a yellow warning to stderr (does not stop the script).
warn() {
  printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2
}

# Print a red error to stderr and exit immediately.
die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

# Fail fast unless the named command is on PATH.
require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# Fail fast unless the given path is a regular file.
require_file() {
  [[ -f "$1" ]] || die "Required file not found: $1"
}

# Fail fast unless the given path is a directory.
require_dir() {
  [[ -d "$1" ]] || die "Required directory not found: $1"
}

# Fail fast unless the given path is an executable file.
require_executable() {
  [[ -x "$1" ]] || die "Required executable not found: $1"
}

# Decide how many parallel jobs to use for the build:
# an explicit BUILD_JOBS if positive, otherwise the CPU count, otherwise 4.
job_count() {
  if [[ "$BUILD_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s\n' "$BUILD_JOBS"
  elif command -v nproc >/dev/null 2>&1; then
    nproc
  else
    printf '4\n'
  fi
}

# Turn a GGUF path into its quant label.
# e.g. ".../Qwen3-0.6B-Q4_K_M.gguf" -> "Q4_K_M"
quant_from_filename() {
  local file="$1"
  local base
  base="$(basename "$file" .gguf)"   # strip directory and .gguf extension
  base="${base#${MODEL_NAME}-}"      # strip the leading "<MODEL_NAME>-" prefix
  printf '%s\n' "$base"
}

# List every GGUF for this model, NUL-separated and sorted, so callers can loop
# safely over names that might contain odd characters. This covers both the
# BF16 baseline (directly in GGUF_DIR) and every quantized file (in the
# quantized/ subfolder), so downstream stages benchmark all of them together.
list_gguf_models() {
  {
    find "$GGUF_DIR" -maxdepth 1 -type f -name "${MODEL_NAME}-*.gguf" -print0
    find "$GGUF_QUANT_DIR" -maxdepth 1 -type f -name "${MODEL_NAME}-*.gguf" -print0
  } | sort -z
}

# Save the exact command that was run to a file, safely quoted, so every step
# is reproducible from the logs.
write_command_log() {
  local output_file="$1"
  shift
  printf '%q ' "$@" > "$output_file"
  printf '\n' >> "$output_file"
}

# Ask a yes/no question on the terminal; return 0 for yes, 1 for no.
#   $1 = prompt text, $2 = default answer ("Y" or "N") used on empty input.
# Reads from /dev/tty (not stdin) because callers often drive a loop from a
# piped list on stdin. When no terminal is attached (an unattended pipeline
# run), it returns the default without blocking. Used by the slow, resumable
# benchmarking stages (06, 08, 09).
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

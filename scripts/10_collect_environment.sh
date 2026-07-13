#!/usr/bin/env bash
#
# 10_collect_environment.sh — record the hardware and software environment.
#
# Captures OS, CPU, memory, GPU, storage, tool versions, source revisions, and
# the benchmark configuration into one report. This documents exactly where the
# results were produced so they can be interpreted and reproduced later.
#
# Outputs: results/metadata/hardware_and_software.txt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

output="$METADATA_DIR/hardware_and_software.txt"

# Build the whole report inside one block, redirected to the output file at the end.
{
  # ISO timestamp (falling back to plain date) and the project location.
  echo "Captured at: $(date --iso-8601=seconds 2>/dev/null || date)"
  echo "Project root: $ROOT_DIR"
  echo

  # Kernel/OS details.
  echo "== Operating system =="
  uname -a
  [[ -f /etc/os-release ]] && cat /etc/os-release
  echo

  # CPU details via lscpu, falling back to the model name from /proc/cpuinfo.
  echo "== CPU =="
  if command -v lscpu >/dev/null 2>&1; then
    lscpu
  else
    grep -m1 'model name' /proc/cpuinfo 2>/dev/null || true
  fi
  echo

  # Human-readable memory totals.
  echo "== Memory =="
  free -h 2>/dev/null || true
  echo

  # GPU details: prefer nvidia-smi, else list display devices via lspci.
  echo "== GPU =="
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
  elif command -v lspci >/dev/null 2>&1; then
    lspci | grep -Ei 'vga|3d|display' || true
  else
    echo "GPU information unavailable"
  fi
  echo

  # Disk space on the filesystem holding the project.
  echo "== Storage =="
  df -h "$ROOT_DIR"
  echo

  # Versions of the toolchain used to build and run the pipeline.
  echo "== Tool versions =="
  git --version 2>/dev/null || true
  cmake --version 2>/dev/null | head -n1 || true
  python3 --version 2>/dev/null || true
  "$VENV_DIR/bin/python" --version 2>/dev/null || true
  "$VENV_DIR/bin/hf" version 2>/dev/null || true
  "$BIN_DIR/llama-cli" --version 2>/dev/null || true
  echo

  # Exact source commits used, for reproducibility.
  echo "== Revisions =="
  if [[ -d "$LLAMA_CPP_DIR/.git" ]]; then
    echo "llama.cpp commit: $(git -C "$LLAMA_CPP_DIR" rev-parse HEAD)"
  fi
  if [[ -f "$METADATA_DIR/hf_model_commit.txt" ]]; then
    echo "Hugging Face model commit: $(cat "$METADATA_DIR/hf_model_commit.txt")"
  fi
  echo

  # The config values that drove this run (from config.env).
  echo "== Benchmark configuration =="
  echo "MODEL_REPO=$MODEL_REPO"
  echo "MODEL_REVISION=$MODEL_REVISION"
  echo "MODEL_NAME=$MODEL_NAME"
  echo "OUTTYPE=$OUTTYPE"
  echo "BUILD_BACKEND=$BUILD_BACKEND"
  echo "THREADS=$THREADS"
  echo "GPU_LAYERS=$GPU_LAYERS"
  echo "PROMPT_TOKENS=$PROMPT_TOKENS"
  echo "GEN_TOKENS=$GEN_TOKENS"
  echo "BENCH_REPETITIONS=$BENCH_REPETITIONS"
  echo "PPL_CONTEXT=$PPL_CONTEXT"
  echo "PPL_CHUNKS=$PPL_CHUNKS"
  # QUANTS is an array, so print its elements space-separated on one line.
  printf 'QUANTS='
  printf '%s ' "${QUANTS[@]}"
  printf '\n'
} > "$output"

log "Wrote $output"

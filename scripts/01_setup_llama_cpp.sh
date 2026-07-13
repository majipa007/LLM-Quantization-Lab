#!/usr/bin/env bash
#
# 01_setup_llama_cpp.sh — clone and build llama.cpp, and create the Python venv.
#
# Steps:
#   1. Clone (or update) llama.cpp at the pinned ref, recording the commit.
#   2. Create a Python virtualenv and install the conversion + HF requirements.
#   3. Build the four llama.cpp tools the pipeline uses (quantize, bench,
#      cli, perplexity) for the chosen backend (cpu or cuda).
#
# Outputs: tools/llama.cpp/build/bin/* and results/metadata/llama_cpp_*.txt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# These must exist before we can build anything.
require_command git
require_command cmake
require_command python3

# Clone llama.cpp on first run; otherwise fetch new commits/tags.
if [[ ! -d "$LLAMA_CPP_DIR/.git" ]]; then
  log "Cloning llama.cpp"
  git clone "$LLAMA_CPP_REPO" "$LLAMA_CPP_DIR"
else
  log "llama.cpp already exists; fetching references"
  git -C "$LLAMA_CPP_DIR" fetch --tags --prune origin
fi

# Check out the exact ref requested in config.env (branch, tag or commit).
log "Checking out llama.cpp ref: $LLAMA_CPP_REF"
git -C "$LLAMA_CPP_DIR" checkout "$LLAMA_CPP_REF"

# If we landed on a branch (not a detached commit), fast-forward to latest.
if git -C "$LLAMA_CPP_DIR" symbolic-ref -q HEAD >/dev/null 2>&1; then
  git -C "$LLAMA_CPP_DIR" pull --ff-only || warn "Could not fast-forward the selected branch; continuing with the checked-out commit."
fi

# Record exactly which commit we built, for reproducibility.
LLAMA_COMMIT="$(git -C "$LLAMA_CPP_DIR" rev-parse HEAD)"
printf '%s\n' "$LLAMA_COMMIT" > "$METADATA_DIR/llama_cpp_commit.txt"
printf '%s\n' "$LLAMA_CPP_REF" > "$METADATA_DIR/llama_cpp_requested_ref.txt"

# Create the Python virtualenv once; reuse it on later runs.
if [[ ! -d "$VENV_DIR" ]]; then
  log "Creating Python virtual environment"
  python3 -m venv "$VENV_DIR"
fi

# Install the packages llama.cpp's converter needs, plus the Hugging Face CLI.
log "Installing llama.cpp conversion requirements and Hugging Face CLI"
"$VENV_DIR/bin/python" -m pip install --upgrade pip wheel
"$VENV_DIR/bin/python" -m pip install -r "$LLAMA_CPP_DIR/requirements.txt"
"$VENV_DIR/bin/python" -m pip install --upgrade "huggingface_hub[hf_xet]"

# Base CMake flags: a native, optimized Release build using Ninja.
CMAKE_ARGS=(
  -S "$LLAMA_CPP_DIR"
  -B "$LLAMA_BUILD_DIR"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DGGML_NATIVE=ON
)

# Add backend-specific flags. `${BUILD_BACKEND,,}` lowercases the value.
case "${BUILD_BACKEND,,}" in
  cpu)
    CMAKE_ARGS+=( -DGGML_CUDA=OFF )   # CPU-only build
    ;;
  cuda)
    require_command nvcc              # CUDA toolkit must be installed
    CMAKE_ARGS+=( -DGGML_CUDA=ON )    # enable GPU offload
    ;;
  *)
    die "BUILD_BACKEND must be 'cpu' or 'cuda', got: $BUILD_BACKEND"
    ;;
esac

log "Configuring llama.cpp ($BUILD_BACKEND build)"
cmake "${CMAKE_ARGS[@]}"

# Build only the four tools the pipeline actually uses, in parallel.
log "Building llama.cpp tools"
cmake --build "$LLAMA_BUILD_DIR" \
  --target llama-quantize llama-bench llama-cli llama-perplexity \
  -j "$(job_count)"

# Fail loudly if any expected binary is missing after the build.
for binary in llama-quantize llama-bench llama-cli llama-perplexity; do
  require_executable "$BIN_DIR/$binary"
done

# Record the built binary's version string (never fail on this).
"$BIN_DIR/llama-cli" --version > "$METADATA_DIR/llama_cpp_version.txt" 2>&1 || true

log "llama.cpp is ready at $LLAMA_CPP_DIR"
log "Pinned commit: $LLAMA_COMMIT"

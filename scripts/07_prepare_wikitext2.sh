#!/usr/bin/env bash
#
# 07_prepare_wikitext2.sh — download the WikiText-2 corpus for perplexity testing.
#
# Fetches the WikiText-2 raw test set using llama.cpp's bundled helper script.
# This is the text the next step (08) feeds to llama-perplexity to measure how
# much each quantization degrades model quality.
#
# Outputs: data/wikitext-2-raw/wiki.test.raw and metadata/wikitext2_path.txt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Preconditions: llama.cpp's download helper must exist, and unzip is needed to extract the archive.
require_file "$LLAMA_CPP_DIR/scripts/get-wikitext-2.sh"
require_command unzip

log "Downloading the WikiText-2 raw test corpus using llama.cpp's official helper"
# Run the helper from inside DATA_DIR (subshell so the cd doesn't affect the rest of the script);
# the helper downloads and unzips the corpus into the current directory.
(
  cd "$DATA_DIR"
  bash "$LLAMA_CPP_DIR/scripts/get-wikitext-2.sh"
)

# Confirm the expected test file landed, then record its path for later steps to read.
WIKITEXT_FILE="$DATA_DIR/wikitext-2-raw/wiki.test.raw"
require_file "$WIKITEXT_FILE"
printf '%s\n' "$WIKITEXT_FILE" > "$METADATA_DIR/wikitext2_path.txt"

log "Corpus ready at $WIKITEXT_FILE"

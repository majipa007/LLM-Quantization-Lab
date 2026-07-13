#!/usr/bin/env bash
#
# 11_generate_checksums.sh — compute SHA-256 checksums for every GGUF file.
#
# Produces a standard SHA256SUMS file listing each model's basename and hash,
# so downloaders can verify the files were not corrupted or tampered with.
#
# Outputs: results/SHA256SUMS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Need sha256sum; start with an empty output file to append to.
require_command sha256sum
output="$RESULTS_DIR/SHA256SUMS"
: > "$output"

# Hash each GGUF model in turn.
model_count=0
while IFS= read -r -d '' model; do
  ((model_count+=1))
  # cd into the GGUF dir so the checksum records only the basename (no path),
  # keeping SHA256SUMS portable. Runs in a subshell so the cd is local.
  (
    cd "$GGUF_DIR"
    sha256sum "$(basename "$model")"
  ) >> "$output"
done < <(list_gguf_models)

# Fail if there were no models to checksum.
(( model_count > 0 )) || die "No GGUF files found in $GGUF_DIR"
log "Wrote $output"
cat "$output"

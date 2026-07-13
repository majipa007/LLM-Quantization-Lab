#!/usr/bin/env bash
#
# run_pipeline.sh — run the whole quantization experiment end to end.
#
# It simply runs scripts 01..12 in order. Each script is self-contained and
# can also be run on its own; see scripts/README.md.
#
# Usage:  ./run_pipeline.sh
# First run creates config.env from the example and stops so you can edit it.

set -Eeuo pipefail
# Absolute path to this script's directory (the project root).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# On the very first run there is no config.env yet: create it from the template
# and stop so the user can review settings before anything heavy runs.
if [[ ! -f "$ROOT_DIR/config.env" ]]; then
  cp "$ROOT_DIR/config.env.example" "$ROOT_DIR/config.env"
  echo "Created config.env. Review it, then run this script again."
  exit 0
fi

# The ordered list of pipeline stages. (Script 00 installs OS packages and 13
# uploads to Hugging Face — both are run manually, not as part of the pipeline.)
steps=(
  01_setup_llama_cpp.sh
  02_download_model.sh
  03_convert_to_gguf.sh
  04_quantize_models.sh
  05_collect_sizes.sh
  06_benchmark_speed.sh
  07_prepare_wikitext2.sh
  08_benchmark_perplexity.sh
  09_generate_samples.sh
  10_collect_environment.sh
  11_generate_checksums.sh
  12_prepare_hf_upload.sh
)

# Run each stage in turn. `set -e` above means the pipeline stops at the first
# stage that fails, so you never benchmark against a half-built model.
for step in "${steps[@]}"; do
  echo
  echo "============================================================"
  echo "Running $step"
  echo "============================================================"
  "$ROOT_DIR/scripts/$step"
done

echo
echo "Pipeline complete. Review results/ and hf_upload/ before publishing."

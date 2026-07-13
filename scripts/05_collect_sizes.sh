#!/usr/bin/env bash
#
# 05_collect_sizes.sh — measure each GGUF's file size on disk.
#
# Walks every quantized GGUF, records its size, and computes how much smaller
# it is than the full-precision BF16 baseline. This is the headline "how much
# space did quantization save?" table.
#
# Outputs: results/size_results.csv

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Preconditions: we need `stat` to read file sizes and the BF16 file to compare against.
require_command stat
require_file "$GGUF_BF16"

output_csv="$RESULTS_DIR/size_results.csv"
# Size of the uncompressed baseline, used as the denominator for the % reduction.
baseline_bytes="$(stat -c '%s' "$GGUF_BF16")"

# Write the CSV header row.
printf 'format,file,size_bytes,size_mib,size_gib,reduction_vs_bf16_percent\n' > "$output_csv"

# Iterate over every GGUF (NUL-separated so filenames with spaces are safe).
while IFS= read -r -d '' file; do
  bytes="$(stat -c '%s' "$file")"           # raw file size in bytes
  format="$(quant_from_filename "$file")"   # e.g. "Q4_K_M" derived from the filename

  # Convert bytes to MiB/GiB and compute the size reduction vs. baseline (0% for BF16 itself).
  awk -v format="$format" \
      -v file="$(basename "$file")" \
      -v bytes="$bytes" \
      -v baseline="$baseline_bytes" \
      'BEGIN {
         mib = bytes / 1024 / 1024;
         gib = bytes / 1024 / 1024 / 1024;
         reduction = (1 - bytes / baseline) * 100;
         if (format == "BF16") reduction = 0;
         printf "\"%s\",\"%s\",%d,%.2f,%.4f,%.2f\n", format, file, bytes, mib, gib, reduction;
       }' >> "$output_csv"
done < <(list_gguf_models)   # list_gguf_models emits every GGUF, NUL-separated and sorted

log "Wrote $output_csv"
# Pretty-print the CSV as an aligned table if `column` is available, else dump raw.
column -s, -t "$output_csv" 2>/dev/null || cat "$output_csv"

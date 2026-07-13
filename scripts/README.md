![LLM Quantization Lab](../readme.png)

# `scripts/`

The pipeline stages. Each script is numbered in the order it runs and is
self-contained: it can be run on its own, or all together via
[`../run_pipeline.sh`](../run_pipeline.sh). Every script (except `00`) sources
[`lib/common.sh`](lib/common.sh) first to load settings and helpers.

Settings come from `config.env` (copied from `../config.env.example`).

## What each file does

| File | Purpose |
| --- | --- |
| `00_install_dependencies.sh` | Install OS packages (compilers, CMake, Ninja, Git LFS, Python, jq…). Run once, needs sudo. The only script that does **not** use `lib/common.sh`. |
| `01_setup_llama_cpp.sh` | Clone & build llama.cpp at the pinned commit, and create the Python virtualenv with the conversion + Hugging Face requirements. |
| `02_download_model.sh` | Download the source model from Hugging Face and record its exact resolved commit hash. |
| `03_convert_to_gguf.sh` | Convert the downloaded model into the full-precision baseline GGUF (e.g. BF16). |
| `04_quantize_models.sh` | Produce every quantized GGUF listed in `QUANTS` from the baseline. Safe to re-run (skips existing formats). |
| `05_collect_sizes.sh` | Measure each GGUF's file size and % reduction vs BF16 → `results/size_results.csv`. |
| `06_benchmark_speed.sh` | Run `llama-bench` on each GGUF (prompt + generation throughput) → `results/speed_results.csv`. |
| `07_prepare_wikitext2.sh` | Download the WikiText-2 raw test corpus (used for perplexity) into `data/`. |
| `08_benchmark_perplexity.sh` | Run `llama-perplexity` on each GGUF against WikiText-2 → `results/perplexity_results.csv`. |
| `09_generate_samples.sh` | Generate deterministic text samples for each GGUF from `data/prompts.txt` → `results/raw/generations/`. |
| `10_collect_environment.sh` | Record hardware + software + config → `results/metadata/hardware_and_software.txt`. |
| `11_generate_checksums.sh` | SHA-256 every GGUF → `results/SHA256SUMS`. |
| `12_prepare_hf_upload.sh` | Stage the `hf_upload/` folder: GGUFs, rendered model card, result CSVs, checksums. |
| `13_upload_huggingface.sh` | Upload the staged folder to Hugging Face (run manually after login). |
| `lib/` | Shared setup and helper functions — see [`lib/README.md`](lib/README.md). |

## Order

`run_pipeline.sh` runs stages **01 → 12**. Stage `00` (system packages) and
stage `13` (upload) are run manually.

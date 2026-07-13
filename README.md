![LLM Quantization Lab](readme.png)

# LLM Quantization Lab

A reproducible llama.cpp workflow for downloading a Hugging Face model, converting it to GGUF, creating multiple quantizations, benchmarking size/speed/perplexity, generating deterministic samples, recording the environment and preparing a Hugging Face upload.

The default configuration reproduces the Qwen3-0.6B Base experiment.

## Repository layout

```text
.
├── config.env.example
├── data/prompts.txt
├── models/
│   ├── hf/
│   └── gguf/
├── results/
├── scripts/
├── hf_model_card_template.md
└── run_pipeline.sh
```

## Start

```bash
cp config.env.example config.env
nano config.env

./scripts/00_install_dependencies.sh
./run_pipeline.sh
```

The first `run_pipeline.sh` invocation creates `config.env` when it is missing and exits so you can review it.

## Run individual stages

```bash
./scripts/01_setup_llama_cpp.sh
./scripts/02_download_model.sh
./scripts/03_convert_to_gguf.sh
./scripts/04_quantize_models.sh
./scripts/05_collect_sizes.sh
./scripts/06_benchmark_speed.sh
./scripts/07_prepare_wikitext2.sh
./scripts/08_benchmark_perplexity.sh
./scripts/09_generate_samples.sh
./scripts/10_collect_environment.sh
./scripts/11_generate_checksums.sh
./scripts/12_prepare_hf_upload.sh
```

## Upload to Hugging Face

Set this in `config.env`:

```bash
HF_REPO_ID="YOUR_USERNAME/Qwen3-0.6B-GGUF"
```

Then:

```bash
.venv/bin/hf auth login
./scripts/12_prepare_hf_upload.sh
# Edit hf_upload/README.md
./scripts/13_upload_huggingface.sh
```

## Reproducibility rule

After the first successful run, replace these moving references in `config.env` with exact commit hashes recorded under `results/metadata/`:

```bash
MODEL_REVISION="<exact Hugging Face commit>"
LLAMA_CPP_REF="<exact llama.cpp commit>"
```

Commit the scripts, configuration example, result summaries and metadata to GitHub. Do not commit the GGUF files; publish those on Hugging Face.

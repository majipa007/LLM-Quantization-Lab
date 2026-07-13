---
library_name: llama.cpp
base_model: Qwen/Qwen3-0.6B-Base
tags:
  - gguf
  - quantization
  - llama-cpp
license: apache-2.0
---

# Qwen3-0.6B GGUF Quantization Experiment

This repository contains GGUF files produced from `Qwen/Qwen3-0.6B-Base` for a reproducible size, speed and quality comparison.

## Source and tooling

- Base model: `Qwen/Qwen3-0.6B-Base`
- Base revision: `main`
- llama.cpp revision: `master`
- Conversion precision: `bf16`

Exact pinned commit hashes (Hugging Face model and llama.cpp) are recorded in `results/metadata/` after each run.

## Available files

- `Qwen3-0.6B-BF16.gguf`
- `Qwen3-0.6B-IQ3_M.gguf`
- `Qwen3-0.6B-IQ3_S.gguf`
- `Qwen3-0.6B-IQ4_NL.gguf`
- `Qwen3-0.6B-IQ4_XS.gguf`
- `Qwen3-0.6B-Q1_0.gguf`
- `Qwen3-0.6B-Q2_K.gguf`
- `Qwen3-0.6B-Q3_K_L.gguf`
- `Qwen3-0.6B-Q3_K_M.gguf`
- `Qwen3-0.6B-Q3_K_S.gguf`
- `Qwen3-0.6B-Q4_0.gguf`
- `Qwen3-0.6B-Q4_1.gguf`
- `Qwen3-0.6B-Q4_K_M.gguf`
- `Qwen3-0.6B-Q4_K_S.gguf`
- `Qwen3-0.6B-Q5_0.gguf`
- `Qwen3-0.6B-Q5_1.gguf`
- `Qwen3-0.6B-Q5_K_M.gguf`
- `Qwen3-0.6B-Q5_K_S.gguf`
- `Qwen3-0.6B-Q6_K.gguf`
- `Qwen3-0.6B-Q8_0.gguf`
- `Qwen3-0.6B-TQ1_0.gguf`
- `Qwen3-0.6B-TQ2_0.gguf`

## Reproduction

The full scripts, exact commands, benchmark configuration and raw logs are published in the companion GitHub repository:

`https://github.com/majipa007/LLM-Quantization-Lab`

Core conversion command:

```bash
python llama.cpp/convert_hf_to_gguf.py \
  models/hf/Qwen3-0.6B \
  --outfile models/gguf/Qwen3-0.6B-BF16.gguf \
  --outtype bf16
```

Core quantization pattern:

```bash
./llama.cpp/build/bin/llama-quantize \
  models/gguf/Qwen3-0.6B-BF16.gguf \
  models/gguf/quantized/Qwen3-0.6B-Q4_K_M.gguf \
  Q4_K_M \
  10
```

## Benchmark configuration

- Threads: 10
- GPU layers: 0
- Prompt-processing test: 512 tokens
- Text-generation test: 128 tokens
- Repetitions: 5
- Perplexity corpus: WikiText-2 raw test set
- Perplexity context: 4096
- Perplexity chunks: 0

See `size_results.csv`, `speed_results.csv`, and `perplexity_results.csv` when included.

## Integrity

SHA256 hashes are provided in `SHA256SUMS`.

## Notes

These files are independently quantized derivatives of the source model. Lower-bit formats usually save more memory and may run faster, but can lose more quality. Perplexity is useful when comparing quantized versions sharing the same tokenizer; it is not a complete measure of practical model quality.

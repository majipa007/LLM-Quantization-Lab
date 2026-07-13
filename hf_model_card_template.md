---
library_name: llama.cpp
base_model: {{MODEL_REPO}}
tags:
  - gguf
  - quantization
  - llama-cpp
license: apache-2.0
---

# {{MODEL_NAME}} GGUF Quantization Experiment

This repository contains GGUF files produced from `{{MODEL_REPO}}` for a reproducible size, speed and quality comparison.

## Source and tooling

- Base model: `{{MODEL_REPO}}`
- Requested base revision: `{{MODEL_REVISION}}`
- Resolved base commit: `{{HF_MODEL_COMMIT}}`
- Requested llama.cpp revision: `{{LLAMA_CPP_REF}}`
- Resolved llama.cpp commit: `{{LLAMA_CPP_COMMIT}}`
- Conversion precision: `{{OUTTYPE}}`

## Available files

{{QUANT_LIST}}

## Reproduction

The full scripts, exact commands, benchmark configuration and raw logs should be published in the companion GitHub repository:

`<ADD_GITHUB_REPOSITORY_URL>`

Core conversion command:

```bash
python llama.cpp/convert_hf_to_gguf.py \
  models/hf/{{MODEL_NAME}} \
  --outfile models/gguf/{{MODEL_NAME}}-BF16.gguf \
  --outtype {{OUTTYPE}}
```

Core quantization pattern:

```bash
./llama.cpp/build/bin/llama-quantize \
  {{MODEL_NAME}}-BF16.gguf \
  {{MODEL_NAME}}-Q4_K_M.gguf \
  Q4_K_M \
  {{THREADS}}
```

## Benchmark configuration

- Threads: {{THREADS}}
- GPU layers: {{GPU_LAYERS}}
- Prompt-processing test: {{PROMPT_TOKENS}} tokens
- Text-generation test: {{GEN_TOKENS}} tokens
- Repetitions: {{BENCH_REPETITIONS}}
- Perplexity corpus: WikiText-2 raw test set
- Perplexity context: {{PPL_CONTEXT}}
- Perplexity chunks: {{PPL_CHUNKS}}

See `size_results.csv`, `speed_results.csv`, and `perplexity_results.csv` when included.

## Integrity

SHA256 hashes are provided in `SHA256SUMS`.

## Notes

These files are independently quantized derivatives of the source model. Lower-bit formats usually save more memory and may run faster, but can lose more quality. Perplexity is useful when comparing quantized versions sharing the same tokenizer; it is not a complete measure of practical model quality.

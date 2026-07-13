---
license: apache-2.0
base_model: Qwen/Qwen3-0.6B-Base
base_model_relation: quantized
library_name: gguf
pipeline_tag: text-generation
language:
  - en
tags:
  - gguf
  - quantization
  - llama.cpp
  - qwen3
  - quantized
---

# Qwen3-0.6B — GGUF Quantizations

GGUF quantizations of [`Qwen/Qwen3-0.6B-Base`](https://huggingface.co/Qwen/Qwen3-0.6B-Base),
built with [llama.cpp](https://github.com/ggml-org/llama.cpp) for local, CPU-friendly
inference. This repo ships **21 quantization formats** (from `TQ1_0` up to `Q8_0`) so you
can trade size, speed and quality to fit your hardware.

- **Original model:** https://huggingface.co/Qwen/Qwen3-0.6B-Base
- **Format:** GGUF (works with `llama.cpp`, `llama-cpp-python`, Ollama, LM Studio, Jan, …)
- **Reproducible pipeline:** https://github.com/majipa007/LLM-Quantization-Lab

> These are independently quantized derivatives of the source model. They are **base
> (non-instruct)** weights, so they complete text rather than follow chat instructions.

## Model details

| | |
| --- | --- |
| Base model | `Qwen/Qwen3-0.6B-Base` |
| Architecture | `Qwen3ForCausalLM` (`qwen3`) |
| Parameters | ~0.6B (hidden size 1024, 28 layers, 16 heads / 8 KV heads) |
| Vocabulary | 151,936 |
| Context length | 32,768 |
| Tensor dtype (source) | bfloat16 |
| License | Apache-2.0 |

## Conversion & quantization process

1. Download the source model from the Hugging Face Hub.
2. Convert it to a full-precision **BF16** GGUF with llama.cpp's `convert_hf_to_gguf.py`.
3. Quantize that BF16 baseline into each target format with `llama-quantize`.

```bash
# 1) BF16 baseline
python llama.cpp/convert_hf_to_gguf.py \
  models/hf/Qwen3-0.6B \
  --outfile Qwen3-0.6B-BF16.gguf \
  --outtype bf16

# 2) One quantization (repeat per format)
./llama.cpp/build/bin/llama-quantize \
  Qwen3-0.6B-BF16.gguf \
  Qwen3-0.6B-Q4_K_M.gguf \
  Q4_K_M
```

- **Tooling:** llama.cpp @ `91c631b21d6e5d09e9c6659efdf6baeef5a44ddb` (branch `master`)
- **Importance matrix (imatrix):** not used — these are plain quantizations.

## Available quantizations & file sizes

Sizes are the actual on-disk bytes; “% of BF16” is the size relative to the BF16 baseline
(1439.4 MiB). Smaller = more compression = lower quality.

| File | Bits (approx) | Size | % of BF16 | Notes |
| --- | --- | --- | --- | --- |
| `Qwen3-0.6B-Q8_0.gguf`   | 8.5 | 767.5 MiB | 53.3% | Near-lossless; largest quant |
| `Qwen3-0.6B-Q6_K.gguf`   | 6.6 | 593.9 MiB | 41.3% | Very high quality |
| `Qwen3-0.6B-Q5_1.gguf`   | 6.0 | 553.9 MiB | 38.5% | Legacy 5-bit |
| `Qwen3-0.6B-Q5_K_M.gguf` | 5.7 | 525.8 MiB | 36.5% | High quality |
| `Qwen3-0.6B-Q5_K_S.gguf` | 5.5 | 518.4 MiB | 36.0% | High quality, slightly smaller |
| `Qwen3-0.6B-Q5_0.gguf`   | 5.5 | 518.4 MiB | 36.0% | Legacy 5-bit |
| `Qwen3-0.6B-Q4_1.gguf`   | 5.0 | 482.9 MiB | 33.5% | Legacy 4-bit |
| `Qwen3-0.6B-Q4_K_M.gguf` | 4.8 | 461.8 MiB | 32.1% | **Recommended default** — best size/quality balance |
| `Qwen3-0.6B-Q4_K_S.gguf` | 4.6 | 449.0 MiB | 31.2% | Good balance, smaller |
| `Qwen3-0.6B-IQ4_NL.gguf` | 4.5 | 448.5 MiB | 31.2% | I-quant, non-linear |
| `Qwen3-0.6B-Q4_0.gguf`   | 4.5 | 447.4 MiB | 31.1% | Legacy 4-bit |
| `Qwen3-0.6B-IQ4_XS.gguf` | 4.3 | 431.0 MiB | 29.9% | I-quant, good quality-per-byte |
| `Qwen3-0.6B-Q3_K_L.gguf` | 3.9 | 415.2 MiB | 28.8% | 3-bit, larger variant |
| `Qwen3-0.6B-Q3_K_M.gguf` | 3.7 | 394.8 MiB | 27.4% | 3-bit, medium |
| `Qwen3-0.6B-IQ3_M.gguf`  | 3.5 | 384.2 MiB | 26.7% | I-quant 3-bit |
| `Qwen3-0.6B-IQ3_S.gguf`  | 3.4 | 371.9 MiB | 25.8% | I-quant 3-bit, smaller |
| `Qwen3-0.6B-Q3_K_S.gguf` | 3.4 | 371.9 MiB | 25.8% | 3-bit, small |
| `Qwen3-0.6B-Q2_K.gguf`   | 2.6 | 331.2 MiB | 23.0% | 2-bit; noticeable quality loss |
| `Qwen3-0.6B-TQ2_0.gguf`  | 2.1 | 319.4 MiB | 22.2% | Ternary; experimental |
| `Qwen3-0.6B-TQ1_0.gguf`  | 1.7 | 299.7 MiB | 20.8% | Ternary; experimental |
| `Qwen3-0.6B-Q1_0.gguf`   | 1.0 | 207.6 MiB | 14.4% | 1-bit; extreme compression, large quality loss |

Bit-widths are approximate effective bits-per-weight for the format family.

## Recommended files

For a **0.6B** model, quality degrades quickly at very low bit-widths, so prefer higher bits
when you can afford the size:

- **Best all-round:** `Q4_K_M` — the standard sweet spot.
- **Want more quality:** `Q5_K_M` or `Q6_K`.
- **Maximum fidelity:** `Q8_0` (effectively lossless vs BF16 for most uses).
- **Tight on memory:** `IQ4_XS` or `Q3_K_M` (accept some quality loss).
- **Experimental / research only:** `Q2_K`, `TQ2_0`, `TQ1_0`, `Q1_0` — expect significant
  degradation on a model this small; not recommended for real use.

## Speed benchmarks

> **Pending.** Throughput (prompt-processing and text-generation tokens/s) will be measured
> with `llama-bench` and added here. Methodology: `llama-bench -m <file> -p 512 -n 128 -r 5`
> on the hardware below, CPU-only (`-ngl 0`).

| File | Prompt (t/s) | Generation (t/s) |
| --- | --- | --- |
| _to be added_ | | |

## Quality evaluation

> **Pending.** Perplexity on the WikiText-2 raw test set (via `llama-perplexity`,
> context 4096) will be reported per quantization, alongside the BF16 baseline, so quality
> loss can be compared directly. Note perplexity only compares models sharing the same
> tokenizer and is not a complete measure of practical quality.

| File | Perplexity (WikiText-2) | Δ vs BF16 |
| --- | --- | --- |
| _to be added_ | | |

## Hardware specifications (build & reference)

Quantization and (upcoming) benchmarks were produced on:

| | |
| --- | --- |
| CPU | 13th Gen Intel Core i7-1355U (12 threads: 6 cores × 2) |
| Memory | 16 GB |
| GPU | none (CPU-only) |
| OS | Ubuntu 24.04.4 LTS on WSL2 |
| Compiler | gcc/g++ 13.3.0 |
| CMake | 3.28.3 |
| Python | 3.12 |

## Usage

Replace `majipa007/Qwen3-0.6B-GGUF` with this repo's id if different.

### Download a single file

```bash
pip install -U "huggingface_hub[cli]"
hf download majipa007/Qwen3-0.6B-GGUF Qwen3-0.6B-Q4_K_M.gguf --local-dir .
```

### Run with llama.cpp

```bash
# Interactive / one-shot completion (base model = text completion, not chat)
llama-cli -m Qwen3-0.6B-Q4_K_M.gguf -p "The capital of France is" -n 128

# OpenAI-compatible local server
llama-server -m Qwen3-0.6B-Q4_K_M.gguf -c 4096
```

### Run with Python (`llama-cpp-python`)

```python
from llama_cpp import Llama

llm = Llama(model_path="Qwen3-0.6B-Q4_K_M.gguf", n_ctx=4096)
out = llm("The capital of France is", max_tokens=128)
print(out["choices"][0]["text"])
```

Also loadable directly in **Ollama**, **LM Studio**, **Jan**, and other GGUF runtimes.

## Reproduction

The full, scripted pipeline (download → convert → quantize → benchmark → package) is here:

```bash
git clone https://github.com/majipa007/LLM-Quantization-Lab
cd LLM-Quantization-Lab
cp config.env.example config.env      # edit if desired
./scripts/00_install_dependencies.sh  # system packages (once)
./run_pipeline.sh                     # runs stages 01–12
```

Individual stages (build llama.cpp, download, convert, quantize, size/speed/perplexity
benchmarks, sample generation, checksums, upload packaging) live under `scripts/` and are
documented in the repository.

## License & attribution

- **License:** Apache-2.0, inherited from the base model.
- **Base model:** [`Qwen/Qwen3-0.6B-Base`](https://huggingface.co/Qwen/Qwen3-0.6B-Base)
  by the Qwen team, Alibaba Cloud. All rights to the original weights belong to the authors.
- **Quantization:** produced with [llama.cpp](https://github.com/ggml-org/llama.cpp)
  (`ggml-org/llama.cpp`).
- These GGUF files are derivative works of the base model and are distributed under the same
  license. Please cite and credit the original Qwen3 authors.

## Integrity

SHA-256 checksums for every file are provided in `SHA256SUMS` (when included in the upload).

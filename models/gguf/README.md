![LLM Quantization Lab](../../readme.png)

# `models/gguf/`

The GGUF files used for benchmarking.

> **Large files — not committed to Git.** Only the READMEs are tracked.

## Layout

| Path | Description | Created by |
| --- | --- | --- |
| `<MODEL_NAME>-BF16.gguf` | Full-precision baseline converted from the Hugging Face model. Every quantization is derived from this file. | `scripts/03_convert_to_gguf.sh` |
| `quantized/` | One quantized GGUF per format in the `QUANTS` list — see [`quantized/README.md`](quantized/README.md). | `scripts/04_quantize_models.sh` |

The baseline lives directly in this folder; the quantized files live in the
`quantized/` subfolder. The benchmarking stages read from both. `<MODEL_NAME>`
is configured in `config.env`.

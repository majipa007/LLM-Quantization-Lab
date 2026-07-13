![LLM Quantization Lab](../../readme.png)

# `models/gguf/`

The GGUF files used for benchmarking.

> **Large files — not committed to Git.** Only this README is tracked.

## Contents

| File | Description | Created by |
| --- | --- | --- |
| `<MODEL_NAME>-BF16.gguf` | Full-precision baseline converted from the Hugging Face model. Every quantization is derived from this file. | `scripts/03_convert_to_gguf.sh` |
| `<MODEL_NAME>-<QUANT>.gguf` | One file per quantization format in the `QUANTS` list (e.g. `Q8_0`, `Q4_K_M`, `Q2_K`, `IQ4_XS`…). | `scripts/04_quantize_models.sh` |

`<MODEL_NAME>` and the set of `<QUANT>` formats are configured in `config.env`.
The `<QUANT>` label is a llama.cpp quantization type: higher-bit formats
(e.g. `Q8_0`) are larger and closer to the original; lower-bit formats
(e.g. `Q2_K`) are smaller and faster but lose more quality.

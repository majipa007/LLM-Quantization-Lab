![LLM Quantization Lab](../../../readme.png)

# `models/gguf/quantized/`

The quantized GGUF files, one per format in the `QUANTS` list. Produced from
the BF16 baseline in the parent folder (`../<MODEL_NAME>-BF16.gguf`) by
`scripts/04_quantize_models.sh`.

> **Large files — not committed to Git.** Only this README is tracked. Publish
> the GGUFs on Hugging Face (see `scripts/12`–`13`).

## Naming

```
<MODEL_NAME>-<QUANT>.gguf      e.g. Qwen3-0.6B-Q4_K_M.gguf
```

`<QUANT>` is a llama.cpp quantization type. Higher-bit formats (e.g. `Q8_0`,
`Q6_K`) are larger and stay closer to the original; lower-bit formats (e.g.
`Q2_K`, `IQ3_S`, `TQ1_0`) are smaller and faster but lose more quality.

The default `QUANTS` list in `config.env.example` builds eight representative
formats; set your own list in `config.env` to build more (llama.cpp supports
~20, from `TQ1_0` up to `Q8_0`).

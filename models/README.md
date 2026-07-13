![LLM Quantization Lab](../readme.png)

# `models/`

Holds all model files: the model downloaded from Hugging Face and the GGUF
files produced from it.

> **These files are large and are not committed to Git.** `.gitignore` keeps
> everything here out of version control except the folder READMEs. Publish the
> GGUFs on Hugging Face instead (see the project README and script `13`).

## Layout

| Path | Contents | Created by |
| --- | --- | --- |
| `hf/<MODEL_NAME>/` | The raw model downloaded from Hugging Face (weights, tokenizer, config). | `scripts/02_download_model.sh` |
| `gguf/` | The BF16 baseline GGUF, plus a `quantized/` subfolder holding every quantized GGUF — see [`gguf/README.md`](gguf/README.md). | `scripts/03` and `04` |

The exact model, revision and output name are set by `MODEL_REPO`,
`MODEL_REVISION` and `MODEL_NAME` in `config.env`.

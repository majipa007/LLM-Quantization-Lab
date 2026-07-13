![LLM Quantization Lab](../readme.png)

# `data/`

Inputs for the benchmarking stages.

## What each file does

| File | Purpose | Created by |
| --- | --- | --- |
| `prompts.txt` | Prompts fed to every GGUF during sample generation. One per line; blank lines and `#` comments are ignored. **Tracked in Git.** | maintained by hand |
| `wikitext-2-raw/` | WikiText-2 raw test corpus used for perplexity. Large and downloaded on demand — **not committed** (git-ignored). | `scripts/07_prepare_wikitext2.sh` |

Everything in `data/` except `prompts.txt` and this README is git-ignored,
since it is downloaded automatically by the pipeline.

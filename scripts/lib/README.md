![LLM Quantization Lab](../../readme.png)

# `scripts/lib/`

Shared code sourced by every numbered pipeline script (except `00`).

## What each file does

| File | Purpose |
| --- | --- |
| `common.sh` | Loaded at the top of each stage. Turns on strict error handling, loads `config.env` and fills in defaults for every setting, derives all project paths, creates the working directories, and defines the shared helper functions. |

### Helper functions defined in `common.sh`

| Function | What it does |
| --- | --- |
| `log` | Print a timestamped status line. |
| `warn` | Print a warning to stderr (does not stop the script). |
| `die` | Print an error and exit. |
| `require_command` / `require_file` / `require_dir` / `require_executable` | Fail fast if a prerequisite is missing. |
| `job_count` | Number of parallel build jobs (`BUILD_JOBS`, else CPU count, else 4). |
| `quant_from_filename` | Turn a GGUF path into its quant label, e.g. `Qwen3-0.6B-Q4_K_M.gguf` → `Q4_K_M`. |
| `list_gguf_models` | List every GGUF for the model, NUL-separated and sorted, for safe looping. |
| `write_command_log` | Save the exact command that was run (safely quoted) for reproducibility. |

`common.sh` is meant to be **sourced**, not executed directly.

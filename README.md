# laguna-vllm-docker

Standalone Docker setup for serving [`poolside/Laguna-S-2.1-NVFP4`](https://huggingface.co/poolside/Laguna-S-2.1-NVFP4)
with vLLM on an NVIDIA DGX Spark (GB10, `sm_121a`). No dependency on any
recipe framework — just a Dockerfile, an entrypoint, and Compose.

Follows the vendor's "Maximum performance on the DGX Spark (native NVFP4 +
DFlash)" recipe from the model card: vLLM 0.25.1, CUDA 13 torch, and the
FlashInfer nightly trio for native NVFP4 kernels, paired with the
quantization-matched `Laguna-S-2.1-DFlash-NVFP4` draft model for speculative
decoding.

## Requirements

- NVIDIA DGX Spark (or other Blackwell `sm_121a` box) with the NVIDIA
  Container Toolkit installed
- Docker with the Compose plugin (`docker compose version` should report v2+)
- ~130 GB free disk for the Hugging Face cache (Laguna weights + DFlash draft)

## Usage

```bash
make build   # build the image manually, no Compose
make up      # builds the image, brings the container up via Compose
make logs    # follow vLLM startup / serving logs
make down    # stop the container
make clean   # remove the built image and local build cache
```

`make up` writes a `.env` file (if one doesn't exist) pointing `HF_CACHE` at
`$HOME/.cache/huggingface` on the host, which is bind-mounted into the
container so downloaded weights persist across rebuilds and are shared with
any other Hugging Face models already cached there.

The server listens on port 8000 and serves the model under the name `red`.

First start downloads ~73 GB of weights (main + DFlash draft) and can take
around 15 minutes, including Triton JIT compilation and CUDA graph capture.

## Configuration

`entrypoint.sh` reads its `vllm serve` flags from environment variables, all
with defaults matching the vendor recipe:

| Variable | Default |
|---|---|
| `MODEL` | `poolside/Laguna-S-2.1-NVFP4` |
| `SERVED_MODEL_NAME` | `red` |
| `DFLASH_MODEL` | `poolside/Laguna-S-2.1-DFlash-NVFP4` |
| `NUM_SPECULATIVE_TOKENS` | `15` |
| `HOST` | `0.0.0.0` |
| `PORT` | `8000` |
| `MAX_MODEL_LEN` | `262144` |
| `MAX_NUM_SEQS` | `32` (DFlash crashes vLLM at the default of 256) |
| `GPU_MEMORY_UTILIZATION` | `0.85` |
| `TEMPERATURE` | `0.7` |
| `TOP_P` | `0.95` |

Set overrides in `docker-compose.yml`'s `environment:` block, or via
`-e VAR=value` when running the image directly.

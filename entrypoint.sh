#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-poolside/Laguna-S-2.1-NVFP4}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-red}"
DFLASH_MODEL="${DFLASH_MODEL:-poolside/Laguna-S-2.1-DFlash-NVFP4}"
NUM_SPECULATIVE_TOKENS="${NUM_SPECULATIVE_TOKENS:-15}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-262144}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-32}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.85}"
TEMPERATURE="${TEMPERATURE:-0.7}"
TOP_P="${TOP_P:-0.95}"
ENABLE_THINKING="${ENABLE_THINKING:-true}"

# --max-num-seqs 32 is required: DFlash crashes vLLM at the default of 256.
exec vllm serve "${MODEL}" \
    --served-model-name "${SERVED_MODEL_NAME}" \
    --speculative-config "{\"model\":\"${DFLASH_MODEL}\",\"num_speculative_tokens\":${NUM_SPECULATIVE_TOKENS}}" \
    --enable-auto-tool-choice \
    --tool-call-parser poolside_v1 \
    --reasoning-parser poolside_v1 \
    --default-chat-template-kwargs "{\"enable_thinking\":${ENABLE_THINKING}}" \
    --override-generation-config "{\"temperature\":${TEMPERATURE},\"top_p\":${TOP_P}}" \
    --max-num-seqs "${MAX_NUM_SEQS}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}" \
    --host "${HOST}" --port "${PORT}" \
    "$@"

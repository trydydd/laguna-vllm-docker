#!/usr/bin/env bash
# Restarts laguna-nvfp4 with each candidate NUM_SPECULATIVE_TOKENS value and
# runs a fixed, as-deterministic-as-possible benchmark against it: greedy
# decoding (temperature 0, top-k 1), a fixed random-seeded prompt, and a
# forced output length (--ignore-eos) so runs are comparable to each other.
set -euo pipefail
cd ~/workspace/laguna-vllm-docker

VALUES=(3 5 8 10 15 20 25)
INPUT_LEN=512
OUTPUT_LEN=1024
NUM_PROMPTS=5
RESULTS_FILE=~/workspace/laguna-vllm-docker/spec_sweep_results.txt

: > "${RESULTS_FILE}"
printf "%6s %8s %8s %10s %10s\n" "spec_n" "tok/s" "ttft_ms" "accept_%" "accept_len" | tee -a "${RESULTS_FILE}"

wait_for_ready() {
    for _ in $(seq 1 180); do
        if curl -sf -m 2 http://localhost:8000/v1/models > /dev/null 2>&1; then
            return 0
        fi
        sleep 5
    done
    echo "server did not become ready in time" >&2
    return 1
}

for n in "${VALUES[@]}"; do
    echo "=== NUM_SPECULATIVE_TOKENS=${n} ===" >&2
    NUM_SPECULATIVE_TOKENS="${n}" docker compose up -d >&2
    wait_for_ready

    out=$(docker exec laguna-nvfp4 vllm bench serve \
        --backend openai-chat \
        --base-url http://localhost:8000 \
        --endpoint /v1/chat/completions \
        --model red \
        --tokenizer poolside/Laguna-S-2.1-NVFP4 \
        --dataset-name random \
        --seed 0 \
        --random-input-len "${INPUT_LEN}" \
        --random-output-len "${OUTPUT_LEN}" \
        --num-prompts "${NUM_PROMPTS}" \
        --max-concurrency 1 \
        --temperature 0 \
        --top-k 1 \
        --ignore-eos 2>&1)

    echo "${out}" >> "${RESULTS_FILE}.raw.${n}.log"

    tok_s=$(echo "${out}" | grep "Output token throughput" | awk '{print $NF}')
    ttft=$(echo "${out}" | grep "Mean TTFT" | awk '{print $NF}')
    accept_rate=$(echo "${out}" | grep "Acceptance rate" | awk '{print $NF}')
    accept_len=$(echo "${out}" | grep "Acceptance length" | awk '{print $NF}')

    printf "%6s %8s %8s %10s %10s\n" "${n}" "${tok_s:-NA}" "${ttft:-NA}" "${accept_rate:-NA}" "${accept_len:-NA}" | tee -a "${RESULTS_FILE}"
done

echo "Full results: ${RESULTS_FILE}"

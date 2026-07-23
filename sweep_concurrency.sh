#!/usr/bin/env bash
# No container restarts needed - concurrency is purely a benchmark-client
# property. Same deterministic-as-possible settings as the speculative sweep
# (greedy decoding, seeded prompts, forced output length) so throughput
# differences reflect concurrency, not sampling noise.
set -euo pipefail
cd ~/workspace/laguna-vllm-docker

CONCURRENCIES=(1 2 4 8 16 32)
INPUT_LEN=512
OUTPUT_LEN=1024
RESULTS_FILE=~/workspace/laguna-vllm-docker/concurrency_sweep_results.txt

: > "${RESULTS_FILE}"
printf "%5s %9s %10s %10s %8s %10s\n" "conc" "req/s" "out_tok/s" "total_tok/s" "ttft_ms" "accept_%" | tee -a "${RESULTS_FILE}"

for c in "${CONCURRENCIES[@]}"; do
    num_prompts=$(( c * 4 ))
    echo "=== concurrency=${c} (num_prompts=${num_prompts}) ===" >&2

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
        --num-prompts "${num_prompts}" \
        --max-concurrency "${c}" \
        --temperature 0 \
        --top-k 1 \
        --ignore-eos 2>&1)

    echo "${out}" >> "${RESULTS_FILE}.raw.${c}.log"

    req_s=$(echo "${out}" | grep "Request throughput" | awk '{print $NF}')
    out_tok_s=$(echo "${out}" | grep "Output token throughput" | awk '{print $NF}')
    total_tok_s=$(echo "${out}" | grep "Total token throughput" | awk '{print $NF}')
    ttft=$(echo "${out}" | grep "Mean TTFT" | awk '{print $NF}')
    accept_rate=$(echo "${out}" | grep "Acceptance rate" | awk '{print $NF}')

    printf "%5s %9s %10s %10s %8s %10s\n" "${c}" "${req_s:-NA}" "${out_tok_s:-NA}" "${total_tok_s:-NA}" "${ttft:-NA}" "${accept_rate:-NA}" | tee -a "${RESULTS_FILE}"
done

echo "Full results: ${RESULTS_FILE}"

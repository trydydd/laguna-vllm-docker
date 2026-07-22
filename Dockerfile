# Standalone runner for poolside/Laguna-S-2.1-NVFP4 on DGX Spark (GB10, sm_121a).
# Self-contained: no dependency on the spark-vllm-docker recipe framework.
FROM nvidia/cuda:13.0.0-devel-ubuntu24.04

# Triton JIT needs Python headers; DGX OS/this base image ships without them.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.12 \
        python3.12-dev \
        python3.12-venv \
        curl \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

ENV VENV=/opt/venv
RUN uv venv "${VENV}" -p 3.12
ENV PATH="${VENV}/bin:${PATH}"

# vLLM 0.25.1 with CUDA-13 torch (aarch64 wheels are on PyPI).
RUN uv pip install -p "${VENV}" vllm==0.25.1 --torch-backend=cu130

# FlashInfer nightly trio: without flashinfer-python the NVFP4 path is not
# native; the jit-cache wheel avoids most first-start JIT compilation.
RUN uv pip install -p "${VENV}" \
        "flashinfer-python==0.6.15.dev20260712" \
        "flashinfer-cubin==0.6.15.dev20260712" \
        "flashinfer-jit-cache==0.6.15.dev20260712" \
        --extra-index-url https://flashinfer.ai/whl/nightly/ \
        --extra-index-url https://flashinfer.ai/whl/nightly/cu130/ \
        --index-strategy unsafe-best-match

# Arch string for FP4 kernel JIT (GB10 = sm_121a) and nvcc for JIT compilation.
ENV CUTE_DSL_ARCH=sm_121a
ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV MAX_JOBS=4

# Model weights are downloaded at runtime into this mounted volume so the
# image itself stays small and the cache survives container recreation.
ENV HF_HOME=/root/.cache/huggingface
VOLUME ["/root/.cache/huggingface"]

EXPOSE 8000

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

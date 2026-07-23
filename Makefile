IMAGE_NAME ?= laguna-nvfp4
IMAGE_TAG  ?= latest

.PHONY: build up down restart logs clean

# Manual image build, no compose involved.
build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

.env:
	echo "HF_CACHE=$$HOME/.cache/huggingface" > .env
	echo "COMPILE_CACHE=$$HOME/.cache/laguna-vllm-compile" >> .env

up: .env
	docker compose up -d --build

down:
	docker compose down

restart: down up

logs:
	docker compose logs -f

# Removes the built image, any dangling layers from the build, and the
# builder cache used to produce it. Leaves the Hugging Face model cache
# (mounted from the host) untouched.
clean:
	-docker compose down --rmi local --remove-orphans
	-docker image rm $(IMAGE_NAME):$(IMAGE_TAG)
	docker builder prune -f

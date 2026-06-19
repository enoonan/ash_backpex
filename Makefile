.PHONY: up down shell iex build

CONTAINER_NAME := ash-backpex-dev
IMAGE_NAME := ash-backpex-dev

# Build the image
build:
	docker build -t $(IMAGE_NAME) .devcontainer/

# Start the devcontainer
up: build
	docker run -d --name $(CONTAINER_NAME) \
		-v $(PWD):/workspace \
		-v $(HOME)/.claude:/home/vscode/.claude \
		-v $(HOME)/.ssh:/home/vscode/.ssh:ro \
		-p 4005:4005 \
		-w /workspace \
		$(IMAGE_NAME) sleep infinity
	docker exec $(CONTAINER_NAME) mix deps.get

# Stop the devcontainer
down:
	-docker stop $(CONTAINER_NAME)
	-docker rm $(CONTAINER_NAME)

# Open a bash shell in the container
shell:
	docker exec -it $(CONTAINER_NAME) bash

# Open an iex session in the container
iex:
	docker exec -it $(CONTAINER_NAME) iex -S mix

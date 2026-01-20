.PHONY: up down shell iex build

# Start the devcontainer
up:
	docker compose -f .devcontainer/docker-compose.yml up -d --build

# Stop the devcontainer
down:
	docker compose -f .devcontainer/docker-compose.yml down

# Open a bash shell in the container
shell:
	docker compose -f .devcontainer/docker-compose.yml exec app bash

# Open an iex session in the container
iex:
	docker compose -f .devcontainer/docker-compose.yml exec app iex -S mix

# Rebuild the container from scratch
build:
	docker compose -f .devcontainer/docker-compose.yml up -d --build --force-recreate

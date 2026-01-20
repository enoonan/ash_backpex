FROM elixir:1.18

# Install build dependencies and Node.js
RUN apt-get update && apt-get install -y \
    build-essential \
    inotify-tools \
    postgresql-client \
    git \
    curl \
    ca-certificates \
    gnupg \
    sudo \
    jq \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Create workspace and set ownership
RUN mkdir -p /workspace && chown $USERNAME:$USERNAME /workspace

# Switch to non-root user for all subsequent operations
USER $USERNAME

# Set working directory
WORKDIR /workspace

# Install hex and rebar as the vscode user
RUN mix local.hex --force && \
    mix local.rebar --force

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Add uv to PATH
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Install beads
RUN curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

# Install spec-kit
RUN /home/$USERNAME/.local/bin/uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

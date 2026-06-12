# =============================================================================
# nanobot Dockerfile (Modified — referencing QwenPaw template)
# Base: Ubuntu 26.04 (Resolute Raccoon) + Python 3.13 + uv
# Source: cloned from GitHub during build (no local source files needed)
# =============================================================================

# ---------------------------------------------------------------------------
# Build arguments for remote source
# ---------------------------------------------------------------------------
# Usage:
#   docker build -t nanobot:latest .
#   docker build --build-arg NANOBOT_VERSION=v0.2.1 -t nanobot:v0.2.1 .
#   docker build --build-arg NANOBOT_REPO=https://github.com/your-fork/nanobot.git -t nanobot:custom .
# ---------------------------------------------------------------------------

FROM ubuntu:26.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Build args: remote repo URL and version
# ---------------------------------------------------------------------------
ARG NANOBOT_REPO=https://github.com/HKUDS/nanobot.git
ARG NANOBOT_VERSION=main

# ---------------------------------------------------------------------------
# 1. System base packages + commonly used open-source tools
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # --- Essential ---
        ca-certificates \
        curl \
        wget \
        gnupg \
        lsb-release \
        # --- Python runtime ---
        python3.13 \
        python3.13-venv \
        python3.13-dev \
        python3-pip \
        # --- Build toolchain ---
        build-essential \
        libssl-dev \
        libffi-dev \
        # --- Version control ---
        git \
        # --- SSH ---
        openssh-client \
        # --- Text editors ---
        vim \
        nano \
        # --- System utilities ---
        htop \
        procps \
        jq \
        tmux \
        # --- Archive tools ---
        unzip \
        zip \
        # --- Template rendering (envsubst) ---
        gettext-base \
        # --- Sandbox ---
        bubblewrap \
        # --- Network tools ---
        netcat-openbsd \
        dnsutils \
        # --- Locale ---
        locales \
        # --- Chinese fonts ---
        fonts-wqy-zenhei \
        fonts-wqy-microhei \
        fonts-noto-cjk \
    && \
    # Generate UTF-8 locale
    locale-gen en_US.UTF-8 && \
    # Clean up
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Set locale
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ---------------------------------------------------------------------------
# 2. Install uv (from official Astral image)
# ---------------------------------------------------------------------------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Create Python venv and make it default
RUN python3.13 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"
ENV VIRTUAL_ENV=/app/venv

# ---------------------------------------------------------------------------
# 3. Install Node.js 24 LTS (via NodeSource)
# ---------------------------------------------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 4. Install pnpm (standalone, independent of npm)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://get.pnpm.io/install.sh | env PNPM_HOME=/usr/local/pnpm SHELL=/bin/bash sh - && \
    ln -sf /usr/local/pnpm/pnpm /usr/local/bin/pnpm && \
    ln -sf /usr/local/pnpm/pnpx /usr/local/bin/pnpx
ENV PNPM_HOME=/usr/local/pnpm

# ---------------------------------------------------------------------------
# 5. Install Chromium + Playwright dependencies (for web automation)
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        chromium-browser \
        libx11-xcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxtst6 \
        libnss3 \
        libglib2.0-0 \
        libdrm2 \
        libgbm1 \
        libasound2t64 \
        fonts-liberation \
        libu2f-udev \
    && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Playwright: use system Chromium, skip bundled download
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
# Indicate container environment (Chromium --no-sandbox)
ENV NANOBOT_RUNNING_IN_CONTAINER=1

# ---------------------------------------------------------------------------
# 6. Install modern CLI tools (ripgrep, fd-find, eza, bat, zoxide, delta)
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ripgrep \
        fd-find \
        eza \
        bat \
        zoxide \
        git-delta \
    && \
    # Create symlinks for tools with different binary names
    ln -sf /usr/bin/fdfind /usr/local/bin/fd && \
    ln -sf /usr/bin/batcat /usr/local/bin/bat && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 7. Clone nanobot source from GitHub and install
# ---------------------------------------------------------------------------
WORKDIR /app

# Environment variables
ENV NODE_ENV=production
ENV NANOBOT_WORKING_DIR=/app/working
ENV NANOBOT_SECRET_DIR=/app/working.secret
ENV NANOBOT_BACKUP_DIR=/app/working.backups

# Force all GitHub connections over HTTPS (no SSH required)
RUN git config --global --add url."https://github.com/".insteadOf ssh://git@github.com/ && \
    git config --global --add url."https://github.com/".insteadOf git@github.com:

# Clone the repository at the specified version
RUN git clone --depth 1 --branch ${NANOBOT_VERSION} ${NANOBOT_REPO} /app/src && \
    # Move source files into place \
    cp /app/src/pyproject.toml /app/ 2>/dev/null || true && \
    cp /app/src/README.md /app/ 2>/dev/null || touch /app/README.md && \
    cp /app/src/LICENSE /app/ 2>/dev/null || touch /app/LICENSE && \
    cp /app/src/THIRD_PARTY_NOTICES.md /app/ 2>/dev/null || true && \
    cp /app/src/hatch_build.py /app/ 2>/dev/null || true && \
    # Move nanobot source \
    if [ -d /app/src/nanobot ]; then cp -r /app/src/nanobot /app/; else mkdir -p /app/nanobot && touch /app/nanobot/__init__.py; fi && \
    # Move bridge source \
    if [ -d /app/src/bridge ]; then cp -r /app/src/bridge /app/; else mkdir -p /app/bridge; fi && \
    # Move webui source (optional) \
    if [ -d /app/src/webui ] && [ "$(ls -A /app/src/webui 2>/dev/null)" ]; then \
      cp -r /app/src/webui /app/; \
    else \
      mkdir -p /app/webui; \
    fi && \
    # Remove cloned source to reduce image size \
    rm -rf /app/src

# Install Python package
RUN NANOBOT_FORCE_WEBUI_BUILD=1 uv pip install --no-cache /app

# ---------------------------------------------------------------------------
# 8. Build the WhatsApp bridge (using pnpm, only if package.json exists)
# ---------------------------------------------------------------------------
RUN set -e; \
    if [ -f /app/bridge/package.json ]; then \
      cd /app/bridge && \
      pnpm install --frozen-lockfile 2>/dev/null || pnpm install && \
      pnpm run build && \
      echo "Bridge built successfully"; \
    else \
      echo "No bridge/package.json found, skipping bridge build"; \
    fi

# ---------------------------------------------------------------------------
# 9. Create non-root user and config directory
# ---------------------------------------------------------------------------
RUN useradd -m -u 1000 -s /bin/bash nanobot && \
    mkdir -p /home/nanobot/.nanobot \
              /app/working \
              /app/working.secret \
              /app/working.backups && \
    chown -R nanobot:nanobot /home/nanobot /app

# ---------------------------------------------------------------------------
# 10. Entrypoint
# ---------------------------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

USER nanobot
ENV HOME=/home/nanobot

# Gateway health endpoint and optional WebUI/WebSocket channel ports
EXPOSE 18790 8765

ENTRYPOINT ["entrypoint.sh"]
CMD ["status"]

# =============================================================================
# Nanobot Docker Image
# Base: node:lts-trixie-slim (Debian Trixie + Node.js LTS)
# Tools: pnpm, uv, Python 3.13, nanobot-ai
# =============================================================================

FROM docker.io/library/node:lts-trixie-slim

# Use bash as default shell for install scripts compatibility
SHELL ["/bin/bash", "-c"]

# ---------------------------------------------------------------------------
# 1. Install Chinese fonts and common development tools
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # --- Chinese fonts ---
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    # --- Common dev tools ---
    git \
    curl \
    wget \
    build-essential \
    ca-certificates \
    unzip \
    jq \
    vim \
    nano \
    less \
    procps \
    openssh-client \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Generate and set UTF-8 locale for proper CJK rendering
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ---------------------------------------------------------------------------
# 2. Install pnpm via official script
# ---------------------------------------------------------------------------
ENV PNPM_HOME="/root/.local/share/pnpm"
RUN wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.bashrc" SHELL="$(which bash)" bash -
ENV PATH="${PNPM_HOME}:${PATH}"

# ---------------------------------------------------------------------------
# 3. Install uv via official script
# ---------------------------------------------------------------------------
ENV UV_HOME="/root/.local/bin"
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="${UV_HOME}:${PATH}"

# ---------------------------------------------------------------------------
# 4. Install Python 3.13 as default Python via uv
# ---------------------------------------------------------------------------
RUN uv python install 3.13 && \
    ln -sf "$(uv python find 3.13)" /usr/local/bin/python3 && \
    ln -sf /usr/local/bin/python3 /usr/local/bin/python && \
    python3 --version

# ---------------------------------------------------------------------------
# 5. Install nanobot-ai via uv tool
# ---------------------------------------------------------------------------
# NANOBOT_VERSION 由 CI 同步工作流传入（对齐 HKUDS/nanobot 官方 release）；
# 本地构建留空时安装 PyPI 最新版
ARG NANOBOT_VERSION=""
RUN uv tool install "nanobot-ai${NANOBOT_VERSION:+==${NANOBOT_VERSION}}" && \
    nanobot --version || true

# ---------------------------------------------------------------------------
# 6. Entrypoint & default command
# ---------------------------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["entrypoint.sh"]
CMD ["nanobot"]

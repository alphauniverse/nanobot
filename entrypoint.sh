#!/bin/bash
set -e

# =============================================================================
# Nanobot Container Entrypoint
# =============================================================================
# This script ensures all tool paths are properly loaded before executing
# the user's command. It supports three usage patterns:
#
#   1. docker run <image>                     → starts nanobot (default CMD)
#   2. docker run -it <image> bash            → opens interactive shell
#   3. docker run <image> <any-command>       → runs arbitrary command
# =============================================================================

# --- Ensure pnpm path is available ---
export PNPM_HOME="${PNPM_HOME:-/root/.local/share/pnpm}"
export PATH="${PNPM_HOME}:${PATH}"

# --- Ensure uv and uv-managed tools path is available ---
export UV_HOME="${UV_HOME:-/root/.local/bin}"
export PATH="${UV_HOME}:${PATH}"

# --- Ensure uv-managed Python is preferred ---
export UV_PYTHON_PREFERENCE="only-managed"

# --- Print environment info when running interactively ---
if [ -t 0 ]; then
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Nanobot Docker Environment                             ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║  Node.js : $(node --version 2>/dev/null || echo 'N/A')                                   ║"
    echo "║  pnpm    : $(pnpm --version 2>/dev/null || echo 'N/A')                                   ║"
    echo "║  Python  : $(python3 --version 2>/dev/null || echo 'N/A')                                   ║"
    echo "║  uv      : $(uv --version 2>/dev/null || echo 'N/A')                                   ║"
    echo "║  nanobot : $(nanobot --version 2>/dev/null || echo 'N/A')                                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
fi

# --- Execute the command ---
exec "$@"

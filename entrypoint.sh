#!/bin/sh
# =============================================================================
# nanobot Docker Entrypoint
# Referencing QwenPaw's initialization pattern, keeping nanobot's lightweight
# single-process (exec) design.
# =============================================================================
set -e

# ---------------------------------------------------------------------------
# 1. Directory permission check (from original nanobot)
# ---------------------------------------------------------------------------
dir="$HOME/.nanobot"
if [ -d "$dir" ] && [ ! -w "$dir" ]; then
    owner_uid=$(stat -c %u "$dir" 2>/dev/null || stat -f %u "$dir" 2>/dev/null)
    cat >&2 <<EOF
Error: $dir is not writable (owned by UID $owner_uid, running as UID $(id -u)).

Fix (pick one):
  Host:   sudo chown -R 1000:1000 ~/.nanobot
  Docker: docker run --user \$(id -u):\$(id -g) ...
  Podman: podman run --userns=keep-id ...
EOF
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Auto-initialize if config is missing (referencing QwenPaw)
# ---------------------------------------------------------------------------
if [ ! -f "${NANOBOT_WORKING_DIR:-/app/working}/config.json" ] && \
   [ ! -f "$HOME/.nanobot/config.json" ]; then
    echo "No config.json found, running first-time initialization..."
    nanobot init --defaults --accept-security 2>/dev/null || true
    echo "Initialization complete."
else
    echo "Config found, skipping initialization."
fi

# ---------------------------------------------------------------------------
# 3. Security warning when running without auth in container
#    (referencing QwenPaw's warn_if_auth_off_container_bind)
# ---------------------------------------------------------------------------
is_auth_enabled() {
    flag="${NANOBOT_AUTH_ENABLED:-}"
    flag="$(printf '%s' "$flag" | tr '[:upper:]' '[:lower:]')"
    [ "$flag" = "true" ] || [ "$flag" = "1" ] || [ "$flag" = "yes" ]
}

if ! is_auth_enabled; then
    cat >&2 <<'EOF'
============================================================
SECURITY NOTICE: nanobot is running without authentication.

Anyone who can reach the service may access nanobot APIs without login.

Recommended:
  - Restrict access to a trusted network or protected environment.
  - Enable authentication with NANOBOT_AUTH_ENABLED=true
============================================================
EOF
fi

# ---------------------------------------------------------------------------
# 4. Environment info (helpful for debugging)
# ---------------------------------------------------------------------------
echo "nanobot starting..."
echo "  Python:  $(python3 --version 2>&1)"
echo "  Node.js: $(node --version 2>&1)"
echo "  pnpm:    $(pnpm --version 2>&1)"
echo "  uv:      $(uv --version 2>&1)"
echo "  User:    $(whoami) (UID $(id -u))"
echo "  Home:    $HOME"

# ---------------------------------------------------------------------------
# 5. Start nanobot as PID 1 (exec ensures proper signal handling)
# ---------------------------------------------------------------------------
exec nanobot "$@"

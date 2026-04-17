#!/usr/bin/env bash
# Webtop entrypoint: bootstrap hermes config into the persistent volume, then run gateway.
# Adapted from hermes-agent/docker/entrypoint.sh for the webtop/s6-overlay context.
set -e

HERMES_HOME="${HERMES_HOME:-/config/.hermes}"
INSTALL_DIR="/opt/hermes"

echo "[entrypoint] hermes home: $HERMES_HOME"

# ── Restore linuxbrew if needed (moved to /opt in Dockerfile to survive volume overlay) ──
if [ -d "/opt/linuxbrew" ] && [ ! -d "/home/linuxbrew" ]; then
  echo "[entrypoint] moving linuxbrew from /opt/linuxbrew to /home/linuxbrew"
  mv /opt/linuxbrew /home
fi

# ── Activate Python venv (for bootstrap steps below that use python3) ───────
source "${INSTALL_DIR}/.venv/bin/activate"

# ── Create essential directory structure ────────────────────────────────────
mkdir -p "$HERMES_HOME"/{cron,sessions,logs,hooks,memories,skills,skins,plans,workspace,home}

# ── Bootstrap default configs (only if missing) ────────────────────────────
if [ ! -f "$HERMES_HOME/.env" ]; then
    cp "$INSTALL_DIR/.env.example" "$HERMES_HOME/.env"
fi

# NOTE: config.yaml is intentionally NOT auto-created here. Its absence triggers
# the XDG autostart (hermes-setup.desktop) to open a terminal running `hermes setup`.
# The gateway waits for the `.setup-done` marker (touched AFTER hermes setup
# returns successfully) — NOT for config.yaml alone, since `hermes setup` writes
# config.yaml early in the flow before the user has finished answering prompts.

# Treat an already-configured install as setup-complete so returning users
# don't wait forever for a marker that doesn't exist yet.
if [ -f "$HERMES_HOME/config.yaml" ] && [ ! -f "$HERMES_HOME/.setup-done" ]; then
    touch "$HERMES_HOME/.setup-done"
fi

if [ ! -f "$HERMES_HOME/SOUL.md" ]; then
    cp "$INSTALL_DIR/docker/SOUL.md" "$HERMES_HOME/SOUL.md"
fi

# ── Sync bundled skills (manifest-based so user edits are preserved) ────────
if [ -d "$INSTALL_DIR/skills" ]; then
    python3 "$INSTALL_DIR/tools/skills_sync.py"
fi

# ── Fix ownership ───────────────────────────────────────────────────────────
echo "[entrypoint] setting ownership of $HERMES_HOME to 1000:1000..."
chown -R 1000:1000 "$HERMES_HOME"

# ── Wait for user to complete `hermes setup` (touches .setup-done marker) ──
if [ ! -f "$HERMES_HOME/.setup-done" ]; then
    echo "[entrypoint] waiting for $HERMES_HOME/.setup-done (user must complete 'hermes setup' in the desktop terminal)..."
    while [ ! -f "$HERMES_HOME/.setup-done" ]; do
        sleep 2
    done
    echo "[entrypoint] setup complete, proceeding to start gateway"
fi

# ── Start hermes gateway (foreground, as UID 1000) ──────────────────────────
# setpriv drops to a fresh process, so the venv must be re-sourced inside it
echo "[entrypoint] starting hermes gateway..."
cd "$INSTALL_DIR"
exec setpriv --clear-groups --reuid=1000 --regid=1000 -- \
    bash -c "source ${INSTALL_DIR}/.venv/bin/activate && exec hermes gateway"

#!/usr/bin/env bash
# Webtop entrypoint: bootstrap hermes config into the persistent volume, then run gateway.
# Adapted from hermes-agent/docker/entrypoint.sh for the webtop/s6-overlay context.
set -e

HERMES_HOME="${HERMES_HOME:-/opt/data}"
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

# ── Create persistent user venv for user-installed Python packages ─────────
# Packages live in $HERMES_HOME/.venv-user and are picked up by
# /opt/hermes/.venv via user-venv.pth (written at build time).
# This survives image upgrades since $HERMES_HOME is a volume mount point.
if [ ! -x "$HERMES_HOME/.venv-user/bin/python" ]; then
    echo "[entrypoint] creating persistent user venv at $HERMES_HOME/.venv-user..."
    # --clear handles stale/incomplete venvs left by interrupted previous runs
    rm -rf "$HERMES_HOME/.venv-user"
    uv venv "$HERMES_HOME/.venv-user" --python "${INSTALL_DIR}/.venv/bin/python"
fi

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

# SOUL.md:
#   - Always bootstrap on first run.
#   - On subsequent runs, force-refresh from image default by default so
#     image-baked updates propagate. Set HERMES_SYNC_SOUL_MD=0 (or any value
#     other than 1/true) to preserve user edits across gateway restarts.
if [ ! -f "$HERMES_HOME/SOUL.md" ] \
   || [ "${HERMES_SYNC_SOUL_MD:-1}" = "1" ] \
   || [ "${HERMES_SYNC_SOUL_MD:-1}" = "true" ]; then
    cp "$INSTALL_DIR/docker/SOUL.md" "$HERMES_HOME/SOUL.md"
fi

# ── Sync bundled skills (manifest-based so user edits are preserved) ────────
if [ -d "$INSTALL_DIR/skills" ]; then
    python3 "$INSTALL_DIR/tools/skills_sync.py"
fi

# ── Fix ownership / permissions ─────────────────────────────────────────────
# The setup wrapper (runs as UID 1000 from XFCE) needs write access to
# $HERMES_HOME to touch .setup-done. In rootless containers chown may be a
# no-op, so also chmod to ensure the directory is traversable + writable.
echo "[entrypoint] setting ownership of $HERMES_HOME to 1000:1000..."
chown -R 1000:1000 "$HERMES_HOME" 2>/dev/null || true
chmod -R a+rwX "$HERMES_HOME" 2>/dev/null || true
chown -R 1000:1000 "/config" 2>/dev/null || true

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

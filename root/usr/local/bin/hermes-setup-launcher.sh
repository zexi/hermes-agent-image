#!/usr/bin/env bash
# Launched by XDG autostart when the XFCE desktop starts.
# If setup has not been completed, open a maximized terminal running
# `hermes setup` so the user can complete first-run configuration. The s6
# svc-hermes-agent service waits for $HERMES_HOME/.setup-done before starting
# the gateway. After `hermes setup` succeeds, this script also spawns a second
# maximized terminal tailing the gateway logs.
set -e

HERMES_HOME="${HERMES_HOME:-/config/.hermes}"
CONFIG="${HERMES_HOME}/config.yaml"
SETUP_DONE="${HERMES_HOME}/.setup-done"

# Already configured — just open the gateway logs terminal and exit.
if [ -f "$CONFIG" ] && [ -f "$SETUP_DONE" ]; then
    exec /usr/local/bin/hermes-open-terminal.sh "Hermes Logs" \
        "source /opt/hermes/.venv/bin/activate; hermes logs --follow; exec bash"
fi

# Inner command that runs inside the setup terminal:
#   1. activate venv
#   2. print welcome banner
#   3. start a background watcher that opens a logs terminal once the marker
#      appears — MUST run alongside (not after) the setup wrapper, because the
#      wrapper may os.execvp into `hermes chat`, replacing itself, so any code
#      after the wrapper call would only run once the user exits chat.
#   4. run the setup wrapper (touches marker before chat launches)
#   5. fall through to an interactive shell
INNER='source /opt/hermes/.venv/bin/activate; \
echo "=============================================="; \
echo "  Welcome to Hermes Agent"; \
echo "  Please complete first-run setup below."; \
echo "  The gateway will start automatically as"; \
echo "  soon as setup finishes."; \
echo "=============================================="; \
( while [ ! -f "'"$SETUP_DONE"'" ]; do sleep 1; done; \
  setsid /usr/local/bin/hermes-open-terminal.sh "Hermes Logs" \
    "source /opt/hermes/.venv/bin/activate; hermes logs --follow; exec bash" \
    </dev/null >/dev/null 2>&1 ) & \
HERMES_SETUP_DONE_MARKER="'"$SETUP_DONE"'" /usr/local/bin/hermes-setup-wrapper; \
echo; \
exec bash'

exec /usr/local/bin/hermes-open-terminal.sh "Hermes Setup" "$INNER"

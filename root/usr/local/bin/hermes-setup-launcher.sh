#!/usr/bin/env bash
# Launched by XDG autostart when the XFCE desktop starts.
# If config.yaml is missing, open a terminal running `hermes setup` so the user
# can complete first-run configuration. The s6 svc-hermes-agent service is
# concurrently waiting for config.yaml to appear before starting the gateway.
set -e

HERMES_HOME="${HERMES_HOME:-/config/.hermes}"
CONFIG="${HERMES_HOME}/config.yaml"
SETUP_DONE="${HERMES_HOME}/.setup-done"

# Already configured and setup finished — nothing to do
if [ -f "$CONFIG" ] && [ -f "$SETUP_DONE" ]; then
    exit 0
fi

# Pick the first available terminal emulator
TERMINAL=""
for t in xfce4-terminal xterm gnome-terminal konsole lxterminal; do
    if command -v "$t" >/dev/null 2>&1; then
        TERMINAL="$t"
        break
    fi
done

if [ -z "$TERMINAL" ]; then
    echo "[hermes-setup-launcher] ERROR: no terminal emulator found" >&2
    exit 1
fi

# The inner command: source venv, print banner, run `hermes setup`, then touch
# the "setup complete" marker so the waiting s6 gateway service starts. Keeps
# the terminal open after setup so the user can see any output / run `hermes`.
INNER='source /opt/hermes/.venv/bin/activate; \
echo "=============================================="; \
echo "  Welcome to Hermes Agent"; \
echo "  Please complete first-run setup below."; \
echo "  After setup finishes, the gateway will"; \
echo "  start automatically in the background."; \
echo "=============================================="; \
if hermes setup; then \
    touch "'"$SETUP_DONE"'"; \
    echo; \
    echo "[hermes-setup-launcher] setup complete — gateway starting..."; \
else \
    echo; \
    echo "[hermes-setup-launcher] setup did not complete successfully; gateway will not start until you finish setup"; \
fi; \
exec bash'

# Maximize the terminal window once mapped (fallback for emulators without a
# native maximize flag like xterm/lxterminal/konsole). Runs in background.
maximize_window() {
    (
        command -v wmctrl >/dev/null 2>&1 || exit 0
        for i in $(seq 1 40); do
            if wmctrl -l 2>/dev/null | grep -q "Hermes Setup"; then
                wmctrl -r "Hermes Setup" -b add,maximized_vert,maximized_horz 2>/dev/null
                break
            fi
            sleep 0.25
        done
    ) &
}

case "$TERMINAL" in
    xfce4-terminal)
        exec xfce4-terminal --title="Hermes Setup" --maximize --hold -e "bash -c '$INNER'"
        ;;
    xterm)
        maximize_window
        exec xterm -title "Hermes Setup" -e bash -c "$INNER"
        ;;
    gnome-terminal)
        exec gnome-terminal --title="Hermes Setup" --maximize -- bash -c "$INNER"
        ;;
    konsole)
        maximize_window
        exec konsole -p "tabtitle=Hermes Setup" -e bash -c "$INNER"
        ;;
    lxterminal)
        maximize_window
        exec lxterminal --title="Hermes Setup" -e "bash -c \"$INNER\""
        ;;
esac

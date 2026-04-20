#!/usr/bin/env bash
# Open a maximized terminal window with the given title running the given
# bash command. Detects the first available terminal emulator. Intended to be
# invoked from within the X session (DISPLAY/XAUTHORITY already set).
#
# Usage: hermes-open-terminal.sh <title> <bash-command>
set -e

TITLE="${1:?title required}"
CMD="${2:?command required}"

TERMINAL=""
for t in xfce4-terminal xterm gnome-terminal konsole lxterminal; do
    if command -v "$t" >/dev/null 2>&1; then
        TERMINAL="$t"
        break
    fi
done

if [ -z "$TERMINAL" ]; then
    echo "[hermes-open-terminal] ERROR: no terminal emulator found" >&2
    exit 1
fi

# Maximize fallback for emulators without a native --maximize flag.
maximize_window() {
    (
        command -v wmctrl >/dev/null 2>&1 || exit 0
        for i in $(seq 1 40); do
            if wmctrl -l 2>/dev/null | grep -q "$TITLE"; then
                wmctrl -r "$TITLE" -b add,maximized_vert,maximized_horz 2>/dev/null
                break
            fi
            sleep 0.25
        done
    ) &
}

case "$TERMINAL" in
    xfce4-terminal)
        exec xfce4-terminal --title="$TITLE" --maximize --hold -e "bash -c '$CMD'"
        ;;
    xterm)
        maximize_window
        exec xterm -title "$TITLE" -e bash -c "$CMD"
        ;;
    gnome-terminal)
        exec gnome-terminal --title="$TITLE" --maximize -- bash -c "$CMD"
        ;;
    konsole)
        maximize_window
        exec konsole -p "tabtitle=$TITLE" -e bash -c "$CMD"
        ;;
    lxterminal)
        maximize_window
        exec lxterminal --title="$TITLE" -e "bash -c \"$CMD\""
        ;;
esac

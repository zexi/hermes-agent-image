#!/usr/bin/env bash
# Applied on every XFCE session start via XDG autostart.
# Adjusts XFCE panel size, DPI, and title font so text in the top panel and
# window title bars is legible in the webtop remote display. Safe to re-run;
# xfconf-query idempotently sets the target value.
set -e

command -v xfconf-query >/dev/null 2>&1 || exit 0

# Give xfconfd a moment to come up with the session.
for i in $(seq 1 20); do
    xfconf-query -c xsettings -l >/dev/null 2>&1 && break
    sleep 0.25
done

set_prop() {
    # Usage: set_prop <channel> <property> <type> <value>
    local channel="$1" prop="$2" type="$3" value="$4"
    xfconf-query -c "$channel" -p "$prop" -n -t "$type" -s "$value" 2>/dev/null \
        || xfconf-query -c "$channel" -p "$prop" -s "$value" 2>/dev/null \
        || true
}

# ── Font DPI + rendering ───────────────────────────────────────────────────
set_prop xsettings /Xft/DPI int 132
set_prop xsettings /Xft/Antialias int 1
set_prop xsettings /Xft/Hinting int 1
set_prop xsettings /Xft/HintStyle string hintslight
set_prop xsettings /Xft/RGBA string rgb

# ── GTK default fonts (affects panel plugins, menus, dialogs) ──────────────
set_prop xsettings /Gtk/FontName string "Sans 11"
set_prop xsettings /Gtk/MonospaceFontName string "Monospace 11"

# ── Window-manager title (xfwm4) font size ─────────────────────────────────
set_prop xfwm4 /general/title_font string "Sans Bold 9"

# ── Top panel size (px) + increase plugin icon size ────────────────────────
# panel-1 is the top panel on webtop:ubuntu-xfce.
set_prop xfce4-panel /panels/panel-1/size int 32
set_prop xfce4-panel /panels/panel-1/icon-size int 22
set_prop xfce4-panel /panels/panel-1/nrows int 1

# Apply panel changes without a full session restart.
if command -v xfce4-panel >/dev/null 2>&1; then
    xfce4-panel --restart >/dev/null 2>&1 || true
fi

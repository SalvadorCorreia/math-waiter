#!/bin/bash
# Opens the game website in its own browser window, or brings it to front if already open.

source "$(dirname "$0")/common.sh"

if [ -z "$BROWSER" ]; then
    # No browser the scripts can control: open the game once per login session as a normal
    # tab in the default browser. It cannot be closed or refocused automatically.
    if [ ! -f "$RUN_DIR/fallback" ]; then
        mkdir -p "$RUN_DIR" && touch "$RUN_DIR/fallback"
        setsid -f xdg-open "$GAME_URL" > /dev/null 2>&1
        notify-send "Math Waiter" \
            "Opened in your browser. Install Firefox, Chrome, Edge or Brave so the game opens and closes with Claude." \
            > /dev/null 2>&1
    fi
    exit 0
fi

# The prompt was just submitted, so the focused window is the one Claude Code runs in.
save_focus

PID=$(game_pid)
if [ -n "$PID" ]; then
    focus_pid "$PID"
    exit 0
fi

launch_game
exit 0

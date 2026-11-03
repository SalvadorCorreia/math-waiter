#!/bin/bash
# Opens game.html in its own browser window, or brings it to front if already open.

source "$(dirname "$0")/common.sh"

if [ -z "$BROWSER" ]; then
    # No browser the scripts can control (e.g. only Safari): open the game once per login
    # session as a normal tab in the default browser. It cannot be closed or refocused automatically.
    if [ ! -f "$RUN_DIR/fallback" ]; then
        mkdir -p "$RUN_DIR" && touch "$RUN_DIR/fallback"
        install_game
        open "$GAME_URL"
        osascript -e 'display notification "Opened in your browser. Install Firefox, Chrome, Edge or Brave so the game opens and closes with Claude." with title "Math Waiter"' \
            > /dev/null 2>&1
    fi
    exit 0
fi

# The prompt was just submitted, so the frontmost app is the one Claude Code runs in.
save_focus

PID=$(game_pid)
if [ -n "$PID" ]; then
    focus_pid "$PID"
    exit 0
fi

launch_game
exit 0

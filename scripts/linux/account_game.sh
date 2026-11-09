#!/bin/bash
# The login command: opens the game window on its sign-in and account screen, and keeps it open
# after this turn. Signing in there signs in the game window, which has its own browser profile.

source "$(dirname "$0")/common.sh"

if [ -z "$BROWSER" ]; then
    setsid -f xdg-open "$ACCOUNT_URL" > /dev/null 2>&1
    exit 0
fi

mkdir -p "$RUN_DIR" && touch "$KEEP_OPEN_FILE"
close_game
launch_game "$ACCOUNT_URL"
exit 0

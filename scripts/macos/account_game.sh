#!/bin/bash
# The login and profile commands: open the game window on the account or profile page, and keep it
# open after this turn. Signing in there signs in the game window, which has its own browser profile.

source "$(dirname "$0")/common.sh"

if [ -z "$BROWSER" ]; then
    open "$ACCOUNT_URL"
    exit 0
fi

mkdir -p "$RUN_DIR" && touch "$KEEP_OPEN_FILE"
close_game
launch_game "$ACCOUNT_URL"
exit 0

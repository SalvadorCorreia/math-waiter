#!/bin/bash
# Claude finished: close the game window and return focus to Claude.

source "$(dirname "$0")/common.sh"

# The login command opened the window on purpose in this turn: leave it for the player.
[ -f "$KEEP_OPEN_FILE" ] && exit 0

close_game

restore_focus
exit 0

#!/bin/bash
# Claude finished: close the game window and return focus to Claude.

source "$(dirname "$0")/common.sh"

PID=$(game_pid)
if [ -n "$PID" ]; then
    # Close normally first so the browser shuts down cleanly. The game itself is saved on the server after every answer.
    # Force it only if it has not exited after 3 seconds.
    close_pid "$PID"
    for _ in $(seq 30); do
        kill -0 "$PID" 2> /dev/null || break
        sleep 0.1
    done
    kill -0 "$PID" 2> /dev/null && kill -KILL "$PID" 2> /dev/null
fi

restore_focus
exit 0

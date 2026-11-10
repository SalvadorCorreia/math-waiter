#!/bin/sh
# Entry point for the plugin's hooks and commands: runs <action>_game for this OS.
# Usage: run.sh start|pause|stop|end|account|profile|status
#
# Hook commands run through sh on macOS and Linux and through Git Bash on Windows,
# so one POSIX sh script can pick the right folder everywhere. The on/off settings live here
# for the same reason: one implementation for every OS.

case "$1" in
    start | pause | stop | end | account | profile | status) ;;
    *) exit 0 ;;
esac

DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/math-waiter"
SESSIONS_DIR="$CONFIG_DIR/sessions"
STATUS_FILE="$CONFIG_DIR/status"
# One empty file per conversation whose Claude is working. Several conversations share one game
# window, which closes only when the last of them finishes.
WORKING_DIR="${TMPDIR:-/tmp}/math-waiter-$(id -u)/working"
# A conversation that crashed or was killed never finishes, so its mark stops counting after 3 hours.
WORKING_MAX_MINUTES=180

run_os() {
    case "$(uname -s)" in
        Darwin) bash "$DIR/macos/$1_game.sh" ;;
        Linux)  bash "$DIR/linux/$1_game.sh" ;;
        MINGW* | MSYS* | CYGWIN*)
            powershell.exe -NoProfile -ExecutionPolicy Bypass \
                -File "$(cygpath -w "$DIR/windows/$1_game.ps1")" ;;
    esac
}

# "off" only when the player chose it; on is the default.
default_mode() {
    if [ "$(cat "$CONFIG_DIR/default" 2> /dev/null)" = off ]; then echo off; else echo on; fi
}

# A conversation the player never switched follows the default.
session_mode() {
    mode=$(cat "$SESSIONS_DIR/$SESSION" 2> /dev/null)
    case "$mode" in on | off) echo "$mode" ;; *) default_mode ;; esac
}

remember_session() {
    mkdir -p "$SESSIONS_DIR" && printf '%s\n' "$1" > "$SESSIONS_DIR/$SESSION"
    # Conversations are rarely resumed after a month; keep the folder small.
    find "$SESSIONS_DIR" -type f -mtime +30 -exec rm -f {} + 2> /dev/null
}

# Read by /math-waiter:status and printed after every switch command.
write_status() {
    mkdir -p "$CONFIG_DIR"
    printf 'Math Waiter in this conversation: %s. In new conversations: %s.\n' "$(session_mode)" "$(default_mode)" > "$STATUS_FILE"
}

case "$1" in
    status)
        cat "$STATUS_FILE" 2> /dev/null || printf 'Math Waiter in new conversations: %s.\n' "$(default_mode)"
        exit 0 ;;
    account | profile)
        MATH_WAITER_PAGE="$1" run_os account > /dev/null 2>&1
        exit 0 ;;
esac

# Hooks get JSON on stdin with the conversation's session_id and, for UserPromptSubmit, the prompt.
# Without it (running a script by hand) the game is simply on.
INPUT=""
[ -t 0 ] || INPUT=$(cat)
SESSION=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id" *: *"\([A-Za-z0-9_-]*\)".*/\1/p' | head -n 1)
[ -n "$SESSION" ] || { [ "$1" = end ] || run_os "$1" > /dev/null 2>&1; exit 0; }
# Each conversation remembers its own terminal window, so focus goes back to the right one.
export MATH_WAITER_SESSION="$SESSION"

others_working() {
    find "$WORKING_DIR" -type f -mmin +$WORKING_MAX_MINUTES -exec rm -f {} + 2> /dev/null
    [ -n "$(ls -A "$WORKING_DIR" 2> /dev/null)" ]
}

# This conversation's turn is over. Focus goes back to it either way; the game closes only when
# no other conversation is still working.
finish() {
    rm -f "$WORKING_DIR/$SESSION"
    if others_working; then run_os pause; else run_os stop; fi > /dev/null 2>&1
}

# Stop does not run when the player interrupts Claude, nor when the conversation is closed mid-turn.
# The idle notification (a minute after Claude is left waiting) and SessionEnd catch those turns.
# Neither does anything for a turn already finished, so they never move focus unasked.
if [ "$1" = end ] || { [ "$1" = pause ] && printf '%s' "$INPUT" | grep -q -E '"notification_type" *: *"idle_prompt"'; }; then
    [ -f "$WORKING_DIR/$SESSION" ] && finish
    exit 0
fi

# The switch commands arrive here as the prompt, before Claude runs them, so the hook applies them.
if [ "$1" = start ]; then
    COMMAND=$(printf '%s' "$INPUT" | grep -o -E '"prompt" *: *"/math-waiter:(on|off|status|default( +(on|off))?)' | sed 's/.*:\(.*\)$/\1/' | head -n 1)
    case "$COMMAND" in
        on) remember_session on ;;
        off) remember_session off
             rm -f "$WORKING_DIR/$SESSION"
             others_working || run_os stop > /dev/null 2>&1 ;;
        "default on" | "default  on") mkdir -p "$CONFIG_DIR" && echo on > "$CONFIG_DIR/default" ;;
        "default off" | "default  off") mkdir -p "$CONFIG_DIR" && echo off > "$CONFIG_DIR/default" ;;
    esac
    write_status
    # A switch command is not work to wait through, so it never opens the game.
    [ -n "$COMMAND" ] && exit 0
fi

[ "$(session_mode)" = on ] || exit 0
case "$1" in
    start) mkdir -p "$WORKING_DIR" && touch "$WORKING_DIR/$SESSION"
           run_os start > /dev/null 2>&1 ;;
    pause) # Refreshed, so a long turn that keeps asking for permission is not taken for a crashed one.
           [ -f "$WORKING_DIR/$SESSION" ] && touch "$WORKING_DIR/$SESSION"
           run_os pause > /dev/null 2>&1 ;;
    stop)  finish ;;
esac
exit 0

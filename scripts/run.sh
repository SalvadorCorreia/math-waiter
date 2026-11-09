#!/bin/sh
# Entry point for the plugin's hooks: runs <action>_game for this OS.
# Usage: run.sh start|pause|stop|account
#
# Hook commands run through sh on macOS and Linux and through Git Bash on Windows,
# so one POSIX sh script can pick the right folder everywhere.

case "$1" in
    start | pause | stop | account) ;;
    *) exit 0 ;;
esac

DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
    Darwin) exec bash "$DIR/macos/$1_game.sh" ;;
    Linux)  exec bash "$DIR/linux/$1_game.sh" ;;
    MINGW* | MSYS* | CYGWIN*)
        exec powershell.exe -NoProfile -ExecutionPolicy Bypass \
            -File "$(cygpath -w "$DIR/windows/$1_game.ps1")" ;;
esac
exit 0

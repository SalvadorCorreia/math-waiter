# Shared helpers for the macOS scripts. Sourced by start/pause/stop, not run directly.
# macOS ships bash 3.2, so this file avoids newer bash features.
#
# Browser: the user's default browser when it is Chromium- or Firefox-based, otherwise the
# first installed one. Chromium browsers get a real app window (--app); Firefox gets a
# dedicated profile whose settings (../firefox) hide the tabs and toolbars. Safari cannot
# run a separate instance, so it is only used as a last-resort fallback.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$HOME/Library/Application Support/math-waiter"
RUN_DIR="${TMPDIR:-/tmp/}math-waiter"
# One per conversation (run.sh exports its ID), so each returns focus to its own terminal.
FOCUS_FILE="$RUN_DIR/focus${MATH_WAITER_SESSION:+-$MATH_WAITER_SESSION}"

# The game is the website. MATH_WAITER_SITE points it at another address, such as a local
# development server.
SITE="${MATH_WAITER_SITE:-https://mathwaiter.tech}"
GAME_URL="$SITE/play"
# The login and profile commands open their own page; run.sh sets which.
case "$MATH_WAITER_PAGE" in profile) ACCOUNT_URL="$SITE/profile" ;; *) ACCOUNT_URL="$SITE/account" ;; esac
# Set by the login command: the window it opened must survive the Stop hook of that same turn.
KEEP_OPEN_FILE="$RUN_DIR/keep-open"

# Versions before 0.2.0 opened a local copy of the game; remove it.
remove_old_game_copy() {
    rm -rf -- "$STATE_DIR/game"
}

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2> /dev/null
}

# "chromium" (supports --app), "firefox", or nothing for browsers the game cannot control.
browser_kind() {
    case "$1" in
        com.google.Chrome* | org.chromium.Chromium | com.brave.Browser* | com.microsoft.edgemac* \
            | com.vivaldi.Vivaldi) echo chromium ;;
        org.mozilla.* | io.gitlab.librewolf-community | app.zen-browser.zen | net.waterfox.waterfox \
            | one.ablaze.floorp) echo firefox ;;
    esac
}

# Path of the app that opens https links, e.g. /Applications/Firefox.app.
default_browser() {
    osascript -l JavaScript -e 'ObjC.import("AppKit");
        $.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL($.NSURL.URLWithString("https://example.com")).path.js' \
        2> /dev/null
}

BROWSER=""
KIND=""
BUNDLE_ID=""
use_browser() {
    [ -d "$1" ] || return 1
    BUNDLE_ID=$(plist_value "$1" CFBundleIdentifier)
    KIND=$(browser_kind "$BUNDLE_ID")
    [ -n "$KIND" ] && BROWSER="$1/Contents/MacOS/$(plist_value "$1" CFBundleExecutable)"
}
DEFAULT_BROWSER=$(default_browser)
[ -n "$DEFAULT_BROWSER" ] && use_browser "$DEFAULT_BROWSER"
if [ -z "$BROWSER" ]; then
    for app in "Google Chrome" "Microsoft Edge" "Brave Browser" "Chromium" "Vivaldi" "Firefox"; do
        use_browser "/Applications/$app.app" && break
        use_browser "$HOME/Applications/$app.app" && break
    done
fi
[ -z "$BROWSER" ] && KIND=""

# A dedicated profile makes the game its own browser process, so stop_game.sh can close it
# without touching the user's normal browser windows. It also keeps the player signed in, so it
# lives in persistent storage rather than /tmp. Each browser gets its own profile, since
# browsers cannot share one.
PROFILE_DIR=""
[ -n "$BROWSER" ] && PROFILE_DIR="$STATE_DIR/profile-$BUNDLE_ID"

# Start the game window, on the page given or the game itself, in the background, so the hook returns at once.
launch_game() {
    remove_old_game_copy
    mkdir -p "$PROFILE_DIR"
    case "$KIND" in
        chromium)
            "$BROWSER" --app="${1:-$GAME_URL}" --user-data-dir="$PROFILE_DIR" \
                --no-first-run --no-default-browser-check --window-size=700,800 > /dev/null 2>&1 & ;;
        firefox)
            mkdir -p "$PROFILE_DIR/chrome"
            cp "$SCRIPTS_DIR/firefox/user.js" "$PROFILE_DIR/user.js"
            cp "$SCRIPTS_DIR/firefox/userChrome.css" "$PROFILE_DIR/chrome/userChrome.css"
            "$BROWSER" -no-remote -profile "$PROFILE_DIR" "${1:-$GAME_URL}" > /dev/null 2>&1 & ;;
    esac
}

# PID of the game's main browser process, or nothing if the game is not running.
game_pid() {
    [ -z "$PROFILE_DIR" ] && return
    local dir
    dir=$(sed 's/[][\.*^$+?(){}|]/\\&/g' <<< "$PROFILE_DIR")
    case "$KIND" in
        chromium) pgrep -o -f -- "--user-data-dir=$dir( |\$)" ;;
        firefox)  pgrep -o -f -- "-profile $dir( |\$)" ;;
    esac 2> /dev/null
}

# The frontmost app and its front window, as "pid<TAB>x<TAB>y<TAB>width<TAB>height<TAB>title".
# AppleScript has no lasting window ID, so the window is found again by where it is and, failing
# that, by its title. Without a window (or without permission to read it) only the pid is given.
frontmost_window() {
    osascript 2> /dev/null <<'APPLESCRIPT'
tell application "System Events"
    set p to first process whose frontmost is true
    set out to (unix id of p) as text
    try
        set w to value of attribute "AXFocusedWindow" of p
        set {x, y} to position of w
        set {ww, hh} to size of w
        set n to ""
        try
            set n to name of w as text
        end try
        set out to out & tab & x & tab & y & tab & ww & tab & hh & tab & n
    end try
    return out
end tell
APPLESCRIPT
}

# Remember the frontmost window (the one Claude Code runs in), so focus can return to that window
# rather than to whichever window of the same app happens to be in front. Skipped when it is the game.
save_focus() {
    local line
    line=$(frontmost_window)
    [ -z "$line" ] && return
    [ "${line%%[[:space:]]*}" = "$(game_pid)" ] && return
    mkdir -p "$RUN_DIR"
    printf '%s\n' "$line" > "$FOCUS_FILE"
}

# Bring the app with the given process ID to front.
focus_pid() {
    osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $1) to true" \
        > /dev/null 2>&1
}

# Bring the app to front and raise the window with the saved position and size, or else the saved
# title. If neither is there any more, the app's own front window stays in front.
focus_window() {
    osascript - "$@" > /dev/null 2>&1 <<'APPLESCRIPT'
on run argv
    set pidNum to (item 1 of argv) as integer
    set px to (item 2 of argv) as integer
    set py to (item 3 of argv) as integer
    set pw to (item 4 of argv) as integer
    set ph to (item 5 of argv) as integer
    set wantedName to ""
    if (count of argv) > 5 then set wantedName to item 6 of argv
    tell application "System Events"
        set p to first process whose unix id is pidNum
        set target to missing value
        repeat with w in (windows of p)
            if (position of w) is {px, py} and (size of w) is {pw, ph} then
                set target to contents of w
                exit repeat
            end if
        end repeat
        if target is missing value and wantedName is not "" then
            repeat with w in (windows of p)
                if (name of w as text) is wantedName then
                    set target to contents of w
                    exit repeat
                end if
            end repeat
        end if
        set frontmost of p to true
        if target is not missing value then perform action "AXRaise" of target
    end tell
end run
APPLESCRIPT
}

# Return focus to the window saved by save_focus. A file from before 0.3.0 holds only a pid.
restore_focus() {
    [ -f "$FOCUS_FILE" ] || return
    local pid x y w h name
    IFS="$(printf '\t')" read -r pid x y w h name < "$FOCUS_FILE"
    [ -n "$pid" ] || return
    if [ -n "$h" ]; then
        focus_window "$pid" "$x" "$y" "$w" "$h" "$name"
    else
        focus_pid "$pid"
    fi
}

# Send the game's browser process the same quit request as Cmd+Q, so it shuts down cleanly
# and saves game progress. Addressed by PID, so the user's normal browser keeps running.
close_pid() {
    local sent
    sent=$(osascript -l JavaScript -e "ObjC.import('AppKit');
        var app = \$.NSRunningApplication.runningApplicationWithProcessIdentifier($1);
        app.isNil() ? false : app.terminate" 2> /dev/null)
    [ "$sent" = "true" ] || kill "$1" 2> /dev/null
}

# Close the game window normally, so the browser shuts down cleanly, and force it only if it
# has not exited after 3 seconds. The game itself is saved on the server after every answer.
close_game() {
    local pid
    pid=$(game_pid)
    [ -n "$pid" ] || return 0
    close_pid "$pid"
    for _ in $(seq 30); do
        kill -0 "$pid" 2> /dev/null || return 0
        sleep 0.1
    done
    kill -KILL "$pid" 2> /dev/null
}

# Shared helpers for the macOS scripts. Sourced by start/pause/stop, not run directly.
# macOS ships bash 3.2, so this file avoids newer bash features.
#
# Browser: the user's default browser when it is Chromium- or Firefox-based, otherwise the
# first installed one. Chromium browsers get a real app window (--app); Firefox gets a
# dedicated profile whose settings (../firefox) hide the tabs and toolbars. Safari cannot
# run a separate instance, so it is only used as a last-resort fallback.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$(cd "$SCRIPTS_DIR/../game" && pwd)"
STATE_DIR="$HOME/Library/Application Support/math-waiter"
RUN_DIR="${TMPDIR:-/tmp/}math-waiter"
FOCUS_FILE="$RUN_DIR/focus"

# Percent-encode everything except unreserved characters and '/', byte by byte.
url_encode() {
    local LC_ALL=C s="$1" out="" c i
    for ((i = 0; i < ${#s}; i++)); do
        c="${s:i:1}"
        case "$c" in
            [A-Za-z0-9/._~-]) out+="$c" ;;
            *) out+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    printf '%s' "$out"
}
# The browser stores the leaderboard and saved run per file:// path, and the plugin's own
# folder changes with every plugin update. So the game is copied to a fixed per-user folder
# and always opened from there.
GAME_COPY_DIR="$STATE_DIR/game"
GAME_URL="file://$(url_encode "$GAME_COPY_DIR/game.html")"

# Refresh the fixed copy, so plugin updates still reach the game.
install_game() {
    mkdir -p "$GAME_COPY_DIR"
    cp "$GAME_DIR/game.html" "$GAME_COPY_DIR/game.html"
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
# without touching the user's normal browser windows. It also keeps the leaderboard, so it
# lives in persistent storage rather than /tmp. Each browser gets its own profile, since
# browsers cannot share one.
PROFILE_DIR=""
[ -n "$BROWSER" ] && PROFILE_DIR="$STATE_DIR/profile-$BUNDLE_ID"

# Start the game window in the background, so the hook returns at once.
launch_game() {
    install_game
    mkdir -p "$PROFILE_DIR"
    case "$KIND" in
        chromium)
            "$BROWSER" --app="$GAME_URL" --user-data-dir="$PROFILE_DIR" \
                --no-first-run --no-default-browser-check --window-size=700,800 > /dev/null 2>&1 & ;;
        firefox)
            mkdir -p "$PROFILE_DIR/chrome"
            cp "$SCRIPTS_DIR/firefox/user.js" "$PROFILE_DIR/user.js"
            cp "$SCRIPTS_DIR/firefox/userChrome.css" "$PROFILE_DIR/chrome/userChrome.css"
            "$BROWSER" -no-remote -profile "$PROFILE_DIR" "$GAME_URL" > /dev/null 2>&1 & ;;
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

frontmost_pid() {
    osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true' \
        2> /dev/null
}

# Remember the frontmost app (the one Claude Code runs in), so focus can return to it later.
# Skipped when the frontmost app is the game itself.
save_focus() {
    local pid
    pid=$(frontmost_pid)
    [ -z "$pid" ] && return
    [ "$pid" = "$(game_pid)" ] && return
    mkdir -p "$RUN_DIR"
    echo "$pid" > "$FOCUS_FILE"
}

# Bring the app with the given process ID to front.
focus_pid() {
    osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $1) to true" \
        > /dev/null 2>&1
}

# Return focus to the app saved by save_focus.
restore_focus() {
    [ -f "$FOCUS_FILE" ] && focus_pid "$(cat "$FOCUS_FILE")"
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

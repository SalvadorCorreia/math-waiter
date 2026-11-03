# Shared helpers for the Linux scripts. Sourced by start/pause/stop, not run directly.
#
# Browser: the user's default browser when it is Chromium- or Firefox-based, otherwise the
# first installed one. Chromium browsers get a real app window (--app); Firefox gets a
# dedicated profile whose settings (../firefox) hide the tabs and toolbars.
#
# Linux has no standard way to focus a window, so focus handling is best effort:
# Hyprland (hyprctl), Sway (swaymsg + jq) and X11 (xdotool, or wmctrl + xprop).
# Anywhere else (e.g. GNOME or KDE on Wayland) the game still opens and closes,
# and its timer still pauses on blur; only the automatic focus switching is skipped.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$(cd "$SCRIPTS_DIR/../game" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-math-waiter"
if [ -n "$XDG_RUNTIME_DIR" ]; then
    RUN_DIR="$XDG_RUNTIME_DIR/claude-math-waiter"
else
    RUN_DIR="/tmp/claude-math-waiter-$(id -u)"
fi
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
GAME_URL="file://$(url_encode "$GAME_DIR/game.html")"

# "chromium" (supports --app), "firefox", or nothing for browsers the game cannot control.
browser_kind() {
    case "$(basename "$1")" in
        google-chrome* | chrome | chromium* | brave* | microsoft-edge* | msedge | vivaldi*) echo chromium ;;
        firefox* | librewolf* | waterfox* | floorp* | zen*) echo firefox ;;
    esac
}

# Command of the default browser, read from the Exec= line of its .desktop file.
# Flatpak browsers run inside a sandbox the scripts cannot manage, so they are skipped.
default_browser() {
    local id file dir word
    id=$(xdg-settings get default-web-browser 2> /dev/null)
    [ -z "$id" ] && id=$(xdg-mime query default x-scheme-handler/https 2> /dev/null)
    [ -z "$id" ] && return
    local IFS=:
    for dir in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
        if [ -f "$dir/applications/$id" ]; then
            file="$dir/applications/$id"
            break
        fi
    done
    unset IFS
    [ -z "$file" ] && return
    # First word of the first Exec= line, skipping an "env VAR=value" prefix.
    for word in $(sed -n 's/^Exec=//p' "$file" | head -n 1 | tr -d '"'); do
        case "$word" in
            env | *=*) continue ;;
            */flatpak | flatpak) return ;;
            *) echo "$word"; return ;;
        esac
    done
}

BROWSER=""
KIND=""
use_browser() {
    local path
    path=$(command -v "$1" 2> /dev/null) || return 1
    KIND=$(browser_kind "$path")
    [ -n "$KIND" ] && BROWSER="$path"
}
DEFAULT_BROWSER=$(default_browser)
[ -n "$DEFAULT_BROWSER" ] && use_browser "$DEFAULT_BROWSER"
if [ -z "$BROWSER" ]; then
    for candidate in google-chrome-stable google-chrome chromium chromium-browser brave-browser brave \
        microsoft-edge-stable microsoft-edge vivaldi-stable vivaldi firefox firefox-esr librewolf; do
        use_browser "$candidate" && break
    done
fi
[ -z "$BROWSER" ] && KIND=""

# A dedicated profile makes the game its own browser process, so stop_game.sh can close it
# without touching the user's normal browser windows. It also keeps the leaderboard, so it
# lives in persistent storage rather than /tmp. Each browser gets its own profile, since
# browsers cannot share one. Snap browsers cannot write to hidden folders in $HOME, so they
# get a folder inside their own snap directory instead.
case "$BROWSER" in
    "")      PROFILE_DIR="" ;;
    /snap/*) PROFILE_DIR="$HOME/snap/$(basename "$BROWSER")/common/claude-math-waiter-profile" ;;
    *)       PROFILE_DIR="$STATE_DIR/profile-$(basename "$BROWSER")" ;;
esac

# Start the game window detached, so the hook returns at once and the game outlives it.
launch_game() {
    mkdir -p "$PROFILE_DIR"
    case "$KIND" in
        chromium)
            setsid -f "$BROWSER" --app="$GAME_URL" --user-data-dir="$PROFILE_DIR" \
                --no-first-run --no-default-browser-check --window-size=700,800 ;;
        firefox)
            mkdir -p "$PROFILE_DIR/chrome"
            cp "$SCRIPTS_DIR/firefox/user.js" "$PROFILE_DIR/user.js"
            cp "$SCRIPTS_DIR/firefox/userChrome.css" "$PROFILE_DIR/chrome/userChrome.css"
            setsid -f "$BROWSER" -no-remote -profile "$PROFILE_DIR" "$GAME_URL" ;;
    esac > /dev/null 2>&1
}

# PID of the game's main browser process, or nothing if the game is not running.
# Matching on the profile path works even when the browser is started through a wrapper script.
game_pid() {
    [ -z "$PROFILE_DIR" ] && return
    local dir
    dir=$(sed 's/[][\.*^$+?(){}|]/\\&/g' <<< "$PROFILE_DIR")
    case "$KIND" in
        chromium) pgrep -o -f -- "--user-data-dir=$dir( |\$)" ;;
        firefox)  pgrep -o -f -- "-profile $dir( |\$)" ;;
    esac 2> /dev/null
}

focus_backend() {
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl > /dev/null 2>&1; then
        echo hyprland
    elif [ -n "$SWAYSOCK" ] && command -v swaymsg > /dev/null 2>&1 && command -v jq > /dev/null 2>&1; then
        echo sway
    elif [ -z "$WAYLAND_DISPLAY" ] && [ -n "$DISPLAY" ] && command -v xdotool > /dev/null 2>&1; then
        echo xdotool
    elif [ -z "$WAYLAND_DISPLAY" ] && [ -n "$DISPLAY" ] && command -v wmctrl > /dev/null 2>&1 \
        && command -v xprop > /dev/null 2>&1; then
        echo wmctrl
    fi
}

# Remember the focused window (the one Claude Code runs in), so focus can return to it later.
# Skipped when the focused window is the game itself.
save_focus() {
    local id="" pid="" json
    case "$(focus_backend)" in
        hyprland) json=$(hyprctl activewindow -j 2> /dev/null)
                  id=$(sed -n 's/.*"address": *"\(0x[0-9a-fA-F]*\)".*/\1/p' <<< "$json" | head -n 1)
                  pid=$(sed -n 's/.*"pid": *\([0-9]*\).*/\1/p' <<< "$json" | head -n 1) ;;
        sway)     read -r id pid < <(swaymsg -t get_tree 2> /dev/null \
                      | jq -r '.. | select(.focused? == true) | "\(.id) \(.pid)"' | head -n 1) ;;
        xdotool)  id=$(xdotool getactivewindow 2> /dev/null)
                  pid=$(xdotool getwindowpid "$id" 2> /dev/null) ;;
        wmctrl)   id=$(xprop -root _NET_ACTIVE_WINDOW 2> /dev/null | awk '{print $NF}')
                  pid=$(xprop -id "$id" _NET_WM_PID 2> /dev/null | awk '{print $NF}') ;;
    esac
    [ -z "$id" ] && return
    [ -n "$pid" ] && [ "$pid" = "$(game_pid)" ] && return
    mkdir -p "$RUN_DIR"
    echo "$id" > "$FOCUS_FILE"
}

# Return focus to the window saved by save_focus.
restore_focus() {
    [ -f "$FOCUS_FILE" ] || return
    local id
    id=$(cat "$FOCUS_FILE")
    case "$(focus_backend)" in
        hyprland) hyprctl dispatch focuswindow "address:$id" ;;
        sway)     swaymsg "[con_id=$id] focus" ;;
        xdotool)  xdotool windowactivate "$id" ;;
        wmctrl)   wmctrl -i -a "$id" ;;
    esac > /dev/null 2>&1
}

# Close the window owned by the given process as if its close button was clicked, so the
# browser shuts down cleanly and saves game progress. Firefox does not shut down cleanly on
# SIGTERM, so that is only the fallback for desktops without a supported tool.
close_pid() {
    local pid="$1"
    case "$(focus_backend)" in
        hyprland) hyprctl dispatch closewindow "pid:$pid" > /dev/null 2>&1 ;;
        sway)     swaymsg "[pid=$pid] kill" > /dev/null 2>&1 ;;
        *)        local win=""
                  if [ -z "$WAYLAND_DISPLAY" ] && command -v wmctrl > /dev/null 2>&1; then
                      win=$(wmctrl -lp 2> /dev/null | awk -v p="$pid" '$3 == p { print $1; exit }')
                  fi
                  if [ -n "$win" ]; then
                      wmctrl -i -c "$win" > /dev/null 2>&1
                  else
                      kill "$pid" 2> /dev/null
                  fi ;;
    esac
}

# Bring the window owned by the given process to front.
focus_pid() {
    local pid="$1" win
    case "$(focus_backend)" in
        hyprland) hyprctl dispatch focuswindow "pid:$pid" ;;
        sway)     swaymsg "[pid=$pid] focus" ;;
        xdotool)  win=$(xdotool search --onlyvisible --pid "$pid" 2> /dev/null | tail -n 1)
                  [ -n "$win" ] && xdotool windowactivate "$win" ;;
        wmctrl)   win=$(wmctrl -lp 2> /dev/null | awk -v p="$pid" '$3 == p { print $1; exit }')
                  [ -n "$win" ] && wmctrl -i -a "$win" ;;
    esac > /dev/null 2>&1
}

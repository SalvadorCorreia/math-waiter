# claude-code-math-waiter

A math game that keeps you busy while Claude Code works. Claude Code hooks open the game in a browser window when you submit a prompt, hand focus back to Claude when it needs your input, and close the game when Claude finishes. Your current run is saved, so it continues the next time the game opens.

## How it works

| Event | Script | Effect |
|---|---|---|
| `UserPromptSubmit` | `start_game` | Opens `game/game.html` in a browser app window, or brings it to front if already open |
| `Notification` (`permission_prompt`, `idle_prompt`) | `pause_game` | Brings Claude back to front. The game's timer pauses itself when its window loses focus. |
| `Stop` | `stop_game` | Closes the game window and brings Claude back to front |

The game runs in its own window with a separate browser profile, so closing it never touches your normal browser windows. The profile also keeps the leaderboard.

`start_game` remembers the window you submitted the prompt from, and `pause_game` / `stop_game` return focus to it.

## Browser

The game uses your default browser when it can control it, otherwise the first installed one it can:

* **Chromium-based** (Chrome, Edge, Brave, Vivaldi, Chromium): a real app window with no browser UI.
* **Firefox-based** (Firefox, LibreWolf, Zen, Waterfox, Floorp): a separate Firefox instance whose settings (`scripts/firefox/`) hide the tabs and toolbars.
* **Anything else** (e.g. Safari only): the game opens once per login session as a normal tab, and you get a notification. It cannot close or refocus itself.

Each browser gets its own game profile, so switching your default browser starts a fresh leaderboard.

## Project layout

```
game/game.html        the game (shared by all platforms)
scripts/windows/      PowerShell scripts
scripts/macos/        bash + osascript scripts
scripts/linux/        bash scripts
scripts/firefox/      settings for the game's Firefox profile (shared by all platforms)

Each OS folder has start_game, pause_game and stop_game, plus common.sh / common.ps1
with the shared helpers (browser detection, profile, focus).
```

## Installation

The hooks go in the user-level `~/.claude/settings.json`, so the game runs in every Claude Code session. They point at the scripts by absolute path, so keep this folder somewhere permanent. If you move it, update the paths.

Merge the block below into `~/.claude/settings.json`. Keep every other key and existing hook. Replace `GAME_DIR` with this folder's absolute path. Do not use `~`.

### Windows

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"GAME_DIR/scripts/windows/start_game.ps1\"" }] }
    ],
    "Notification": [
      { "matcher": "permission_prompt|idle_prompt", "hooks": [{ "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"GAME_DIR/scripts/windows/pause_game.ps1\"" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"GAME_DIR/scripts/windows/stop_game.ps1\"" }] }
    ]
  }
}
```

* Profiles in `%LOCALAPPDATA%\claude-math-waiter`.

### macOS

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "\"GAME_DIR/scripts/macos/start_game.sh\"" }] }
    ],
    "Notification": [
      { "matcher": "permission_prompt|idle_prompt", "hooks": [{ "type": "command", "command": "\"GAME_DIR/scripts/macos/pause_game.sh\"" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "\"GAME_DIR/scripts/macos/stop_game.sh\"" }] }
    ]
  }
}
```

* Keep the folder out of `~/Desktop`, `~/Documents` and `~/Downloads`. macOS privacy protection can block scripts there, and iCloud can offload the files. `~/claude-code-math-waiter` works well.
* Profiles in `~/Library/Application Support/claude-math-waiter`.
* The first run may ask for permission to control "System Events". Click **Allow**. If you dismissed it, enable it in System Settings → Privacy & Security → Automation / Accessibility.

### Linux

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "\"GAME_DIR/scripts/linux/start_game.sh\"" }] }
    ],
    "Notification": [
      { "matcher": "permission_prompt|idle_prompt", "hooks": [{ "type": "command", "command": "\"GAME_DIR/scripts/linux/pause_game.sh\"" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "\"GAME_DIR/scripts/linux/stop_game.sh\"" }] }
    ]
  }
}
```

* Profiles in `~/.local/state/claude-math-waiter`, or inside the browser's snap folder for snap browsers.
* Linux has no standard way to switch or close windows, so focus switching works on Hyprland, Sway (needs `jq`) and X11 (needs `xdotool`, or `wmctrl` + `xprop`). On other desktops, such as GNOME or KDE on Wayland, the game still opens, pauses on blur and closes; you switch windows yourself. There, a Firefox game window is closed with `SIGTERM`, which can lose the last few seconds of progress.
* Flatpak browsers are not supported.

## After installing

Hooks load when a session starts, so start a new Claude Code session. Sessions that are already open won't show the game.

To check the scripts by hand: run `start_game` (a "Math Waiter" window opens), run it again (no second window opens), then run `stop_game` (the window closes and your other browser windows stay open).

## Known limitations

* Several sessions running at once share one game window. The first session to finish closes it, even if another is still working.
* To turn the game off, remove the three hook entries from `~/.claude/settings.json`.

# Math Waiter

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

## Installation

Math Waiter is a Claude Code plugin. Its hooks run in every Claude Code session: the terminal CLI, the desktop app and the IDE extensions.

From GitHub, inside Claude Code:

```
/plugin marketplace add SalvadorCorreia/math-waiter
/plugin install math-waiter@math-waiter
```

From a local copy of this folder, in a shell:

```bash
claude plugin marketplace add /path/to/math-waiter
claude plugin install math-waiter@math-waiter
```

Then start a new Claude Code session. Hooks load when a session starts, so sessions that are already open won't show the game.

To try it for one session without installing: `claude --plugin-dir /path/to/math-waiter`.

To turn it off: `/plugin disable math-waiter@math-waiter`, or `/plugin uninstall math-waiter@math-waiter` to remove it.

### Updates

Updates ship through the same marketplace. Bump `version` in `.claude-plugin/plugin.json` and push; users get the new version with `/plugin marketplace update math-waiter`, or automatically if they turned on auto-update for the marketplace.

### Per-platform notes

* **Windows:** needs [Git for Windows](https://git-scm.com/download/win), which Claude Code uses to run hooks. Without it Claude Code runs hooks in PowerShell, and the game does not start. Profiles live in `%LOCALAPPDATA%\math-waiter`.
* **macOS:** the first run may ask for permission to control "System Events". Click **Allow**. If you dismissed it, enable it in System Settings → Privacy & Security → Automation / Accessibility. Profiles live in `~/Library/Application Support/math-waiter`.
* **Linux:** profiles live in `~/.local/state/math-waiter`, or inside the browser's snap folder for snap browsers. Linux has no standard way to switch or close windows, so focus switching works on Hyprland, Sway (needs `jq`) and X11 (needs `xdotool`, or `wmctrl` + `xprop`). On other desktops, such as GNOME or KDE on Wayland, the game still opens, pauses on blur and closes; you switch windows yourself. There, a Firefox game window is closed with `SIGTERM`, which can lose the last few seconds of progress. Flatpak browsers are not supported.

## Project layout

```
.claude-plugin/       plugin.json (the plugin) and marketplace.json (lets people install it)
hooks/hooks.json      the three hooks; each runs scripts/run.sh <start|pause|stop>
game/game.html        the game (shared by all platforms)
scripts/run.sh        picks the scripts for the current OS
scripts/windows/      PowerShell scripts
scripts/macos/        bash + osascript scripts
scripts/linux/        bash scripts
scripts/firefox/      settings for the game's Firefox profile (shared by all platforms)
```

Each OS folder has `start_game`, `pause_game` and `stop_game`, plus `common.sh` / `common.ps1` with the shared helpers (browser detection, profile, focus). To test them by hand, run `scripts/run.sh start` (a "Math Waiter" window opens), run it again (no second window opens), then `scripts/run.sh stop` (the window closes and your other browser windows stay open).

## Known limitations

* Several sessions running at once share one game window. The first session to finish closes it, even if another is still working.

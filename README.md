# Math Waiter

A math game that keeps you busy while Claude Code works. Claude Code hooks open [mathwaiter.tech](https://mathwaiter.tech) in a browser window when you submit a prompt, hand focus back to Claude when it needs your input, and close the game when Claude finishes. Your current run is saved, so it continues the next time the game opens. The game needs an internet connection.

## How it works

| Event | Script | Effect |
|---|---|---|
| `UserPromptSubmit` | `start_game` | Opens `https://mathwaiter.tech/play` in a browser app window, or brings it to front if already open |
| `Notification` (`permission_prompt`, `idle_prompt`) | `pause_game` | Brings Claude back to front. The game's timer pauses itself when its window loses focus. |
| `Stop` | `stop_game` | Closes the game window and brings Claude back to front |
| `/math-waiter:login` command | `account_game` | Opens the game window on its sign-in screen and keeps it open past that turn |

The game runs in its own window with a separate browser profile, so closing it never touches your normal browser windows. The profile also keeps you signed in.

## Turning it on and off

Type these in Claude Code:

| Command | What it does |
|---|---|
| `/math-waiter:off` | Turns the game off in this conversation, and closes it if it is open |
| `/math-waiter:on` | Turns it back on in this conversation |
| `/math-waiter:default off` | New conversations start with the game off, until you run `/math-waiter:on` in one |
| `/math-waiter:default on` | New conversations start with the game on (how it comes installed) |
| `/math-waiter:status` | Shows whether it is on here and in new conversations |

A conversation you switched keeps its choice; the others follow the default. The settings are kept in `~/.config/math-waiter`. To remove the plugin entirely, see [Installation](#installation).

## Your account

You can play without an account. An account keeps your scores across devices and puts your name on room leaderboards. You can sign in with Google, or with an email and password.

* **In the game window**, which is what the plugin opens: run `/math-waiter:login` in Claude Code. The game window opens on its sign-in screen, where you can sign in, create an account or change your profile, and it stays open until your next prompt finishes. The game window uses its own browser profile, so sign in there once even if you are already signed in in your normal browser.
* **In your normal browser**: go to [mathwaiter.tech/account](https://mathwaiter.tech/account). This also works to play without Claude Code, at [mathwaiter.tech/play](https://mathwaiter.tech/play).

Creating an account with email sends one email to confirm the address. After that, signing in sends no email.

## What it does on your machine

The hooks run as shell commands with your user permissions, so here is everything they do:

* **Network and data:** the scripts themselves send nothing and never read your prompts, conversation or files. The game is the website `https://mathwaiter.tech`, so the game window talks to that server: your answers, scores and, if you create one, your account. See the [privacy page](https://mathwaiter.tech/privacy). The browser may also make its own background requests, such as update checks.
* **Programs started:** your browser, with a dedicated profile. On Windows, PowerShell runs the scripts with `-ExecutionPolicy Bypass`, because script execution is off by default. If no supported browser is found, the game opens as a normal tab, with a desktop notification.
* **Window control:** the scripts read which window is focused and later return focus to it, using `hyprctl`, `swaymsg`, `xdotool` or `wmctrl` on Linux, `osascript` (System Events) on macOS and Win32 calls on Windows.
* **Closing the game:** the scripts ask the game window to close, and force-kill it after 3 seconds if it is still open. They find it by its profile path, so other browser windows are not affected.
* **Files written:** your on/off settings in `~/.config/math-waiter`, the browser profile (including Firefox settings from `scripts/firefox/`) and a small record of the focused window, all in the per-user folders listed under [Per-platform notes](#per-platform-notes) or in temporary storage.

`start_game` remembers the window you submitted the prompt from, and `pause_game` / `stop_game` return focus to it.

## Browser

The game uses your default browser when it can control it, otherwise the first installed one it can:

* **Chromium-based** (Chrome, Edge, Brave, Vivaldi, Chromium): a real app window with no browser UI.
* **Firefox-based** (Firefox, LibreWolf, Zen, Waterfox, Floorp): a separate Firefox instance whose settings (`scripts/firefox/`) hide the tabs and toolbars.
* **Anything else** (e.g. Safari only): the game opens once per login session as a normal tab, and you get a notification. It cannot close or refocus itself.

Each browser gets its own game profile, so after switching your default browser you sign in again.

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
* **Linux:** profiles live in `~/.local/state/math-waiter`, or inside the browser's snap folder for snap browsers. Linux has no standard way to switch or close windows, so focus switching works on Hyprland, Sway (needs `jq`) and X11 (needs `xdotool`, or `wmctrl` + `xprop`). On other desktops, such as GNOME or KDE on Wayland, the game still opens, pauses on blur and closes; you switch windows yourself. There, a Firefox game window is closed with `SIGTERM`. Flatpak browsers are not supported.

## Project layout

```
.claude-plugin/       plugin.json (the plugin), marketplace.json (lets people install it) and the plugin icon
assets/               editable source of the plugin icon
hooks/hooks.json      the three hooks; each runs scripts/run.sh <start|pause|stop>
commands/             /math-waiter:login, :on, :off, :default and :status
scripts/run.sh        picks the scripts for the current OS
scripts/windows/      PowerShell scripts
scripts/macos/        bash + osascript scripts
scripts/linux/        bash scripts
scripts/firefox/      settings for the game's Firefox profile (shared by all platforms)
```

Each OS folder has `start_game`, `pause_game`, `stop_game` and `account_game`, plus `common.sh` / `common.ps1` with the shared helpers (browser detection, profile, focus). To test them by hand, run `scripts/run.sh start` (a "Math Waiter" window opens), run it again (no second window opens), then `scripts/run.sh stop` (the window closes and your other browser windows stay open).

## Known limitations

* Several sessions running at once share one game window. The first session to finish closes it, even if another is still working.
* Without an internet connection the window shows the browser's offline page instead of the game.

## License and affiliation

MIT, see [LICENSE](LICENSE). Math Waiter is an independent project. It works with Claude Code but is not affiliated with or endorsed by Anthropic.

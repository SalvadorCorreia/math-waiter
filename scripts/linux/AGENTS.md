# scripts/linux/: agent guide

Parent: [../AGENTS.md](../AGENTS.md) (contract all OSes implement). Siblings: [../macos/AGENTS.md](../macos/AGENTS.md), [../windows/AGENTS.md](../windows/AGENTS.md).

Bash. `common.sh` is sourced by `start_game.sh`, `pause_game.sh` and `stop_game.sh`; put shared logic there. Note: sourcing it from zsh fails (`${s:i:1}`); always use bash.

## Specifics

- **Default browser:** `xdg-settings get default-web-browser` (fallback `xdg-mime query default x-scheme-handler/https`), then the `Exec=` line of that `.desktop` file. Flatpak browsers are skipped.
- **Profiles:** `${XDG_STATE_HOME:-~/.local/state}/math-waiter/profile-<browser>`; snap browsers use `~/snap/<name>/common/math-waiter-profile` (snaps cannot write hidden dirs in `$HOME`).
- **Game copy:** `<state>/game/game.html` (snap: `~/snap/<name>/common/math-waiter-game/`), refreshed by `install_game()` before each launch.
- **Runtime state** (focus file, fallback marker): `$XDG_RUNTIME_DIR/math-waiter`, else `/tmp/math-waiter-<uid>`.
- **Launch:** `setsid -f` so the hook returns and the game outlives it.
- **Game PID:** `pgrep -o -f` on `--user-data-dir=<profile>` (Chromium) or `-profile <profile>` (Firefox).
- **Focus/close backends**, picked by `focus_backend()`: Hyprland (`hyprctl`), Sway (`swaymsg` + `jq`), X11 (`xdotool`, or `wmctrl` + `xprop`). None on GNOME/KDE Wayland: focus switching is skipped and close falls back to SIGTERM.

## Testing

Maintainer runs Arch + Hyprland + Alacritty, default browser Firefox, Chrome also installed. Run `sh ../run.sh start|pause|stop` and check with `hyprctl activewindow -j`. Firefox clean shutdown: after stop, `sessionCheckpoints.json` in the profile must contain `"profile-before-change":true`. Sway, X11 and snap paths are untested.

# scripts/: agent guide

Parent: [../AGENTS.md](../AGENTS.md). Per-OS guides: [linux/AGENTS.md](linux/AGENTS.md), [macos/AGENTS.md](macos/AGENTS.md), [windows/AGENTS.md](windows/AGENTS.md). The game they open: [../game/AGENTS.md](../game/AGENTS.md).

## Files

- `run.sh <start|pause|stop>`: entry point for every hook. POSIX `sh`, picks the OS folder via `uname -s` (`Darwin`, `Linux`, `MINGW*/MSYS*/CYGWIN*` → PowerShell). Unknown actions and unknown OSes exit 0.
- `<os>/start_game`, `pause_game`, `stop_game`, plus `common.sh` / `common.ps1` with the shared helpers. All three OS folders implement the same contract below; keep them in step when changing one.
- `firefox/user.js`, `firefox/userChrome.css`: copied into the game's Firefox profile on every launch by all three OSes; they hide tabs/toolbars and first-run pages, since Firefox has no app mode.

## Contract every OS implements

1. **Browser choice:** the default browser if it is Chromium-based (launched with `--app`) or Firefox-based (`-no-remote -profile`); otherwise the first installed one; otherwise open the game once per login/boot as a plain tab (it then cannot be closed or refocused).
2. **Dedicated profile per browser**, in persistent per-user storage (not `/tmp`), so closing the game never touches the user's own browser and the leaderboard survives.
3. **Find the game by its profile path** on the process command line, not by a saved PID (wrappers and Firefox's Windows launcher change PIDs).
4. **start:** remember the focused window/app (skip it if it is the game), then bring the game to front or launch it detached.
5. **pause:** return focus to the remembered window. The game pauses itself on blur.
6. **stop:** close the game gracefully (window-close request / Cmd+Q / `CloseMainWindow`) so `localStorage` is flushed; force-kill only after 3 s. Then restore focus.
7. **Silent:** no stdout, exit 0.

Firefox does not shut down cleanly on SIGTERM, which loses the last progress; always prefer the graceful close.

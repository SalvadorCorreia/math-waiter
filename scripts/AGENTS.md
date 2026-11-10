# scripts/: agent guide

Parent: [../AGENTS.md](../AGENTS.md). Per-OS guides: [linux/AGENTS.md](linux/AGENTS.md), [macos/AGENTS.md](macos/AGENTS.md), [windows/AGENTS.md](windows/AGENTS.md). The game they open is the website `https://mathwaiter.tech/play` (override the site with `MATH_WAITER_SITE`).

## Files

- `run.sh <start|pause|stop|end|account|profile|status>`: entry point for every hook and command. It also owns the on/off settings and the sharing of one window between conversations, so every OS shares one implementation:
  - Settings: `${XDG_CONFIG_HOME:-~/.config}/math-waiter/default` (`on`/`off`, missing means on) and `sessions/<session_id>` for conversations switched with `/math-waiter:on|off`; files older than 30 days are removed.
  - A command cannot see its conversation's ID, but the UserPromptSubmit hook gets `session_id` and the `prompt` on stdin. So `start` reads a prompt that *starts with* `/math-waiter:on|off|status|default on|off`, applies it, writes `status`, and exits without opening the game. The command then prints `run.sh status`.
  - **Shared window:** `start` touches `<tmp>/math-waiter-<uid>/working/<session_id>`; `stop` removes it and runs the OS `stop` only if no other mark remains, else the OS `pause` (focus back to this conversation, game stays open). Marks older than 3 hours are deleted as crashed; `pause` refreshes the mark. Stop does not run on a user interrupt, so the `idle_prompt` notification and `end` (SessionEnd) finish a turn whose mark still exists, and do nothing otherwise. `:off` removes the mark and closes only if no one else is working.
  - `run.sh` exports `MATH_WAITER_SESSION` (the session ID) so each OS keeps one focus file per conversation, and `MATH_WAITER_PAGE` (`account` or `profile`) for `account_game`.
  - Hooks of a conversation that is off do nothing. Without JSON on stdin (running a script by hand) the game is on. POSIX `sh`, picks the OS folder via `uname -s` (`Darwin`, `Linux`, `MINGW*/MSYS*/CYGWIN*` → PowerShell). Unknown actions and unknown OSes exit 0.
- `<os>/start_game`, `pause_game`, `stop_game`, plus `common.sh` / `common.ps1` with the shared helpers. All three OS folders implement the same contract below; keep them in step when changing one.
- `firefox/user.js`, `firefox/userChrome.css`: copied into the game's Firefox profile on every launch by all three OSes; they hide tabs/toolbars and first-run pages, since Firefox has no app mode.

## Contract every OS implements

1. **Browser choice:** the default browser if it is Chromium-based (launched with `--app`) or Firefox-based (`-no-remote -profile`); otherwise the first installed one; otherwise open the game once per login/boot as a plain tab (it then cannot be closed or refocused).
2. **Dedicated profile per browser**, in persistent per-user storage (not `/tmp`), so closing the game never touches the user's own browser and the player stays signed in.
3. **Open the website**, `GAME_URL` in `common`: `<site>/play`, where the site is `https://mathwaiter.tech` or `MATH_WAITER_SITE` when set. The game saves on the server after every answer. Launching also deletes the local game copy that versions before 0.2.0 left in `<state>/game`.
4. **Find the game by its profile path** on the process command line, not by a saved PID (wrappers and Firefox's Windows launcher change PIDs).
5. **start:** remember the focused window/app in this conversation's focus file (`focus-<MATH_WAITER_SESSION>`) (skip it if it is the game), then bring the game to front or launch it detached.
6. **pause:** return focus to the remembered window. The game pauses itself on blur.
7. **stop:** close the game gracefully (window-close request / Cmd+Q / `CloseMainWindow`) so the browser shuts down cleanly; force-kill only after 3 s. Then restore focus.
8. **account** (the login and profile commands): mark the window keep-open, close the game if running, and launch it on `<site>/account`, or `<site>/profile` when `MATH_WAITER_PAGE=profile`. Without a controllable browser, open that page in the default browser.
9. **Keep-open mark:** `stop` leaves the window alone while the mark exists, because the command's own turn ends with the Stop hook. `start` deletes the mark, so the next prompt's Stop closes the window as usual.
10. **Silent:** no stdout, exit 0.

Firefox does not shut down cleanly on SIGTERM; always prefer the graceful close.

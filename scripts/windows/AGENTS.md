# scripts/windows/: agent guide

Parent: [../AGENTS.md](../AGENTS.md) (contract all OSes implement). Siblings: [../linux/AGENTS.md](../linux/AGENTS.md), [../macos/AGENTS.md](../macos/AGENTS.md).

PowerShell (Windows PowerShell 5.1 compatible). `common.ps1` is dot-sourced by the three scripts. `$ErrorActionPreference = 'SilentlyContinue'` is deliberate: hooks must never print or fail loudly.

## Specifics

- **How they run:** Claude Code runs hooks through Git Bash on Windows, so `../run.sh` calls `powershell.exe -NoProfile -ExecutionPolicy Bypass -File`. Without Git for Windows the hook runs in PowerShell and the game does not start.
- **Default browser:** `HKCU\...\UrlAssociations\https\UserChoice` ProgId, then `HKEY_CLASSES_ROOT\<ProgId>\shell\open\command`.
- **Profiles:** `%LOCALAPPDATA%\claude-math-waiter\profile-<exe name>`.
- **Game PID:** `Get-CimInstance Win32_Process` filtered on the profile path in `CommandLine`, oldest first. Do not use the PID from `Start-Process`: Firefox starts through a launcher process that exits at once.
- **Focus:** `GetForegroundWindow` + `GetWindowThreadProcessId` via `Add-Type`, saved to `%TEMP%\claude_math_game.focus`; restored with `WScript.Shell.AppActivate(pid)`.
- **Close:** `CloseMainWindow()` + `WaitForExit(3000)`, then `taskkill /T /F`.
- `$PROFILE` is an automatic variable; use `$ProfileDir`.

## Testing

Not tested by the maintainer yet, and no PowerShell on the dev machine: changes are not even parse-checked here. Say so, and ask for a test on Windows with Git for Windows installed.

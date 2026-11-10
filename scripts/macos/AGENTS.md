# scripts/macos/: agent guide

Parent: [../AGENTS.md](../AGENTS.md) (contract all OSes implement). Siblings: [../linux/AGENTS.md](../linux/AGENTS.md), [../windows/AGENTS.md](../windows/AGENTS.md).

Bash **3.2** (what macOS ships): no associative arrays, `mapfile`, `${var,,}` or other bash 4+ features. `common.sh` is sourced by the three scripts.

## Specifics

- **Default browser:** JXA `NSWorkspace.URLForApplicationToOpenURL` for an `https` URL; browser kind from the app's `CFBundleIdentifier` (read with `PlistBuddy`). Safari is not controllable (no separate instance), so it only gets the plain-tab fallback.
- **Profiles:** `~/Library/Application Support/math-waiter/profile-<bundle id>` (the path contains a space; keep it quoted).
- **Runtime state:** `${TMPDIR}math-waiter`.
- **Focus:** at start, the frontmost process's unix id plus its `AXFocusedWindow` position, size and title, tab-separated in `focus-<session>`. Restore makes the process frontmost and `AXRaise`s the window with the same position and size, else the same title, else leaves the app's front window. AppleScript has no lasting window ID, hence the matching. A one-field file (before 0.3.0) restores the app only. First run asks the user to allow controlling "System Events".
- **Close:** `NSRunningApplication.terminate` on the game's PID (same as Cmd+Q for that one process). Never quit by app name: that would close the user's own browser.

## Testing

No Mac available to the maintainer: these scripts are syntax-checked only (`bash -n`). Say so in any change, and ask for a test on a real Mac.

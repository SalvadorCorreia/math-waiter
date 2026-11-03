# game/: agent guide

Parent: [../AGENTS.md](../AGENTS.md). Scripts that open and close this file: [../scripts/AGENTS.md](../scripts/AGENTS.md).

`game.html` is the whole game: HTML, CSS and JavaScript in one file, no build step, no external requests. The window title must stay `Math Waiter` (scripts and users look for it).

## Behavior other parts rely on

- **Opened and closed from outside.** The window is killed every time the agent finishes, so the current run is saved after every answer in `localStorage` key `mathProgress` (`{score, lives}`) and restored by `loadProgress()` on start. `endGame()` clears it.
- **Leaderboard** lives in `localStorage` key `mathLeaderboard`. It persists because each browser gets a dedicated profile and the scripts always open a fixed per-user copy of this file (`localStorage` is keyed by file path). Renaming these keys wipes players' data.
- **Pause on blur.** The timer stops while the window does not have focus (`document.hasFocus()` check in the timer loop). Focus switching by the pause script relies on this; there is no other pause signal.
- **Flow:** `generateQuestion()` → `checkAnswer()` → `handleWrong()` / level progression (`showLevelUp()`, `startNextLevel()`) → `endGame()` → `saveScore()` / `renderLeaderboard()`.

## Testing

Open the file directly in a browser, or run `sh ../scripts/run.sh start` to get it the way users do. Check that a reload keeps score and lives, and that the timer freezes when another window is focused.

# Claude finished: close the game window and return focus to Claude.
. (Join-Path $PSScriptRoot 'common.ps1')

# The login command opened the window on purpose in this turn: leave it for the player.
if (Test-Path $KeepOpenFile) { exit 0 }

Close-Game

Restore-Focus
exit 0

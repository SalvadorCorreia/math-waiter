# Claude finished: close the game window and return focus to Claude.
. (Join-Path $PSScriptRoot 'common.ps1')

$GamePid = Get-GamePid
if ($GamePid) {
    # Close the window normally first so the browser shuts down cleanly. The game itself is saved on the server after every answer.
    $Game = Get-Process -Id $GamePid
    if ($Game -and $Game.CloseMainWindow() -and $Game.WaitForExit(3000)) {
    } else {
        taskkill /PID $GamePid /T /F | Out-Null
    }
}

Restore-Focus
exit 0

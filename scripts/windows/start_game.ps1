# Opens the game website in its own browser window, or brings it to front if already open.
. (Join-Path $PSScriptRoot 'common.ps1')

# A new prompt: from here on the Stop hook closes the window again.
Remove-Item $KeepOpenFile -Force

if (-not $Browser) {
    # No browser the scripts can control: open the game once per boot as a normal tab in the
    # default browser. It cannot be closed or refocused automatically.
    $Marker = Join-Path $env:TEMP 'math_waiter.fallback'
    $Boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    if (-not (Test-Path $Marker) -or (Get-Item $Marker).LastWriteTime -lt $Boot) {
        Set-Content $Marker ''
        Start-Process $GameUrl
    }
    exit 0
}

# The prompt was just submitted, so the foreground app is the one Claude Code runs in.
Save-Focus

# A window started from a background process opens behind the app in use, so it is brought to
# front once it exists.
if (-not (Get-GamePid)) { Start-Game }
Show-Game
exit 0

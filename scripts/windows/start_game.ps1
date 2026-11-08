# Opens the game website in its own browser window, or brings it to front if already open.
. (Join-Path $PSScriptRoot 'common.ps1')

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

$GamePid = Get-GamePid
if ($GamePid) {
    Set-FocusPid $GamePid
    exit 0
}

Start-Game
exit 0

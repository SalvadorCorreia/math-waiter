# The login and profile commands: open the game window on the account or profile page, and keep it
# open after this turn. Signing in there signs in the game window, which has its own browser profile.
. (Join-Path $PSScriptRoot 'common.ps1')

if (-not $Browser) {
    Start-Process $AccountUrl
    exit 0
}

Set-Content $KeepOpenFile ''
Close-Game
Start-Game $AccountUrl
exit 0

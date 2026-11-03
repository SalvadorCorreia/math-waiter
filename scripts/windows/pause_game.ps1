# Claude needs input: hand focus back to Claude. The game pauses itself on blur.
. (Join-Path $PSScriptRoot 'common.ps1')

Restore-Focus
exit 0

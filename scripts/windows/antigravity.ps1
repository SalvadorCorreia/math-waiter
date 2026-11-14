# Antigravity runs hook commands through cmd.exe on Windows, where sh is usually not on PATH, so
# ../../hooks.json falls back to this script. It runs ../antigravity.sh with Git for Windows' sh,
# which the game scripts need anyway. Without Git it still answers the PreToolUse hook: no reply
# would deny the tool.
# Usage: antigravity.ps1 start|pause|stop, with Antigravity's hook JSON on stdin.
param([string]$Action)
$ErrorActionPreference = 'SilentlyContinue'

$hookInput = [Console]::In.ReadToEnd()

# git.exe sits in Git\cmd, Git\bin or Git\mingw64\bin; sh.exe in Git\bin.
$sh = $null
$candidates = @("$env:ProgramFiles\Git\bin\sh.exe", "${env:ProgramFiles(x86)}\Git\bin\sh.exe", "$env:LOCALAPPDATA\Programs\Git\bin\sh.exe")
$git = Get-Command git.exe | Select-Object -First 1
if ($git) {
    $dir = Split-Path $git.Source
    for ($i = 0; $i -lt 3 -and $dir; $i++) {
        $dir = Split-Path $dir
        if ($dir) { $candidates = @("$dir\bin\sh.exe") + $candidates }
    }
}
foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) { $sh = $candidate; break }
}

if ($sh) {
    $script = (Join-Path (Split-Path $PSScriptRoot) 'antigravity.sh') -replace '\\', '/'
    $hookInput | & $sh $script $Action
} elseif ($Action -eq 'pause') {
    if ($hookInput -match '"name"\s*:\s*"ask_question"') { '{"decision":"allow"}' } else { '{"decision":"ask"}' }
}
exit 0

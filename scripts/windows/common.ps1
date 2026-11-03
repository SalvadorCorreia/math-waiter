# Shared helpers for the Windows scripts. Dot-sourced by start/pause/stop, not run directly.
#
# Browser: the user's default browser when it is Chromium- or Firefox-based, otherwise the
# first installed one. Chromium browsers get a real app window (--app); Firefox gets a
# dedicated profile whose settings (..\firefox) hide the tabs and toolbars.
$ErrorActionPreference = 'SilentlyContinue'

$ScriptsDir = Split-Path $PSScriptRoot
# AbsoluteUri percent-encodes spaces; Start-Process would otherwise split the URL at them.
$GameUrl    = ([System.Uri](Resolve-Path (Join-Path $ScriptsDir '..\game\game.html')).Path).AbsoluteUri
$StateDir   = Join-Path $env:LOCALAPPDATA 'claude-math-waiter'
$FocusFile  = Join-Path $env:TEMP 'claude_math_game.focus'

# "chromium" (supports --app), "firefox", or nothing for browsers the game cannot control.
function Get-BrowserKind($Exe) {
    switch -Regex ([IO.Path]::GetFileName($Exe)) {
        '^(chrome|chromium|brave|msedge|vivaldi)\.exe$'           { 'chromium' }
        '^(firefox|librewolf|waterfox|floorp|zen)\.exe$'          { 'firefox' }
    }
}

# Executable of the default browser, from the https handler's open command, which looks like:
# "C:\Program Files\Mozilla Firefox\firefox.exe" -osint -url "%1"
function Get-DefaultBrowser {
    $ProgId = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice').ProgId
    if (-not $ProgId) { return }
    $Command = (Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\$ProgId\shell\open\command").'(default)'
    if ($Command -match '^\s*"([^"]+)"') { return $Matches[1] }
    if ($Command -match '^\s*(\S+)') { return $Matches[1] }
}

$Candidates = @(
    (Get-DefaultBrowser),
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe",
    "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
)
$Browser = $Candidates | Where-Object { $_ -and (Test-Path $_) -and (Get-BrowserKind $_) } | Select-Object -First 1
$Kind    = if ($Browser) { Get-BrowserKind $Browser }

# A dedicated profile makes the game its own browser process, so stop_game can close it
# without touching the user's normal browser windows. It also keeps the leaderboard.
# Each browser gets its own profile, since browsers cannot share one.
$ProfileDir = if ($Browser) { Join-Path $StateDir ('profile-' + [IO.Path]::GetFileNameWithoutExtension($Browser)) }

function Start-Game {
    New-Item -ItemType Directory -Force $ProfileDir | Out-Null
    if ($Kind -eq 'chromium') {
        $Arguments = @(
            "--app=$GameUrl",
            "--user-data-dir=`"$ProfileDir`"",
            '--no-first-run',
            '--no-default-browser-check',
            '--window-size=700,800'
        )
    } else {
        $ChromeDir = Join-Path $ProfileDir 'chrome'
        New-Item -ItemType Directory -Force $ChromeDir | Out-Null
        Copy-Item (Join-Path $ScriptsDir 'firefox\user.js') $ProfileDir
        Copy-Item (Join-Path $ScriptsDir 'firefox\userChrome.css') $ChromeDir
        $Arguments = @('-no-remote', '-profile', "`"$ProfileDir`"", $GameUrl)
    }
    Start-Process -FilePath $Browser -ArgumentList $Arguments
}

# PID of the game's main browser process, or nothing if the game is not running.
# Found by the profile path on its command line rather than the PID Start-Process returns,
# because Firefox starts through a launcher process that exits right away.
function Get-GamePid {
    if (-not $Browser) { return }
    $Flag = if ($Kind -eq 'chromium') { '--user-data-dir="?' } else { '-profile "?' }
    $Pattern = $Flag + [regex]::Escape($ProfileDir) + '"?(\s|$)'
    $Name = [IO.Path]::GetFileName($Browser)
    Get-CimInstance Win32_Process -Filter "Name = '$Name'" |
        Where-Object { $_.CommandLine -match $Pattern } |
        Sort-Object CreationDate |
        Select-Object -First 1 -ExpandProperty ProcessId
}

Add-Type -Namespace MathWaiter -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
'@

# Remember the foreground app (the one Claude Code runs in), so focus can return to it later.
# Skipped when the foreground app is the game itself.
function Save-Focus {
    [uint32]$FocusPid = 0
    [void][MathWaiter.Win32]::GetWindowThreadProcessId([MathWaiter.Win32]::GetForegroundWindow(), [ref]$FocusPid)
    if ($FocusPid -and $FocusPid -ne (Get-GamePid)) { $FocusPid | Set-Content $FocusFile }
}

function Set-FocusPid($ProcessId) {
    (New-Object -ComObject WScript.Shell).AppActivate([int]$ProcessId) | Out-Null
}

# Return focus to the app saved by Save-Focus.
function Restore-Focus {
    if (Test-Path $FocusFile) { Set-FocusPid (Get-Content $FocusFile) }
}

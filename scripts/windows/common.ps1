# Shared helpers for the Windows scripts. Dot-sourced by start/pause/stop, not run directly.
#
# Browser: the user's default browser when it is Chromium- or Firefox-based, otherwise the
# first installed one. Chromium browsers get a real app window (--app); Firefox gets a
# dedicated profile whose settings (..\firefox) hide the tabs and toolbars.
$ErrorActionPreference = 'SilentlyContinue'

$ScriptsDir = Split-Path $PSScriptRoot
$StateDir   = Join-Path $env:LOCALAPPDATA 'math-waiter'
# The game is the website. MATH_WAITER_SITE points it at another address, such as a local
# development server.
$Site       = if ($env:MATH_WAITER_SITE) { $env:MATH_WAITER_SITE } else { 'https://mathwaiter.tech' }
$GameUrl    = "$Site/play"
# The login and profile commands open their own page; run.sh sets which.
$AccountUrl = if ($env:MATH_WAITER_PAGE -eq 'profile') { "$Site/profile" } else { "$Site/account" }
# Set by the login command: the window it opened must survive the Stop hook of that same turn.
$KeepOpenFile = Join-Path $env:TEMP 'math_waiter.keep_open'
# One per conversation (run.sh exports its ID), so each returns focus to its own terminal.
$FocusFile  = Join-Path $env:TEMP ('math_waiter.focus' + $(if ($env:MATH_WAITER_SESSION -match '^[A-Za-z0-9_-]+$') { "-$env:MATH_WAITER_SESSION" } else { '' }))

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
# without touching the user's normal browser windows. It also keeps the player signed in.
# Each browser gets its own profile, since browsers cannot share one.
$ProfileDir = if ($Browser) { Join-Path $StateDir ('profile-' + [IO.Path]::GetFileNameWithoutExtension($Browser)) }

# Versions before 0.2.0 opened a local copy of the game; remove it.
function Remove-OldGameCopy {
    Remove-Item -Recurse -Force (Join-Path $StateDir 'game')
}

# Opens the game window on the page given, or the game itself.
function Start-Game($Url = $GameUrl) {
    Remove-OldGameCopy
    New-Item -ItemType Directory -Force $ProfileDir | Out-Null
    if ($Kind -eq 'chromium') {
        $Arguments = @(
            "--app=$Url",
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
        $Arguments = @('-no-remote', '-profile', "`"$ProfileDir`"", $Url)
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
[DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
[DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
'@

# Remember the foreground window (the one Claude Code runs in) as "<window handle> <pid>", so focus
# returns to that window rather than to whichever window of the same app is in front: Windows
# Terminal runs all its windows in one process. Skipped when the foreground app is the game itself.
function Save-Focus {
    [uint32]$FocusPid = 0
    $Window = [MathWaiter.Win32]::GetForegroundWindow()
    [void][MathWaiter.Win32]::GetWindowThreadProcessId($Window, [ref]$FocusPid)
    if ($FocusPid -and $FocusPid -ne (Get-GamePid)) { "$($Window.ToInt64()) $FocusPid" | Set-Content $FocusFile }
}

function Set-FocusPid($ProcessId) {
    (New-Object -ComObject WScript.Shell).AppActivate([int]$ProcessId) | Out-Null
}

# Windows only lets the foreground app hand the foreground on, and a hook runs in the background,
# so this borrows the foreground app's input queue for the moment of the switch. When Windows still
# refuses, SwitchToThisWindow (what Alt+Tab uses) usually gets through. Returns whether the window
# ended up in front.
function Set-FocusWindow([IntPtr]$Window) {
    if ([MathWaiter.Win32]::IsIconic($Window)) { [void][MathWaiter.Win32]::ShowWindow($Window, 9) } # SW_RESTORE
    [uint32]$Ignored = 0
    $ForegroundThread = [MathWaiter.Win32]::GetWindowThreadProcessId([MathWaiter.Win32]::GetForegroundWindow(), [ref]$Ignored)
    $OwnThread = [MathWaiter.Win32]::GetCurrentThreadId()
    $Attached = $ForegroundThread -and $ForegroundThread -ne $OwnThread -and [MathWaiter.Win32]::AttachThreadInput($OwnThread, $ForegroundThread, $true)
    [void][MathWaiter.Win32]::SetForegroundWindow($Window)
    if ($Attached) { [void][MathWaiter.Win32]::AttachThreadInput($OwnThread, $ForegroundThread, $false) }
    if ([MathWaiter.Win32]::GetForegroundWindow() -ne $Window) { [MathWaiter.Win32]::SwitchToThisWindow($Window, $true) }
    [MathWaiter.Win32]::GetForegroundWindow() -eq $Window
}

# Bring the game window to front, waiting up to 5 seconds for a window that is still opening.
function Show-Game {
    for ($i = 0; $i -lt 50; $i++) {
        $GamePid = Get-GamePid
        $Window = if ($GamePid) { (Get-Process -Id $GamePid).MainWindowHandle } else { [IntPtr]::Zero }
        if ($Window -and $Window -ne [IntPtr]::Zero) {
            if (-not (Set-FocusWindow $Window)) { Set-FocusPid $GamePid }
            return
        }
        Start-Sleep -Milliseconds 100
    }
}

# Return focus to the window saved by Save-Focus, or to its app when that window has closed (or its
# handle now belongs to another app). A file from before 0.3.0 holds only a pid.
function Restore-Focus {
    if (-not (Test-Path $FocusFile)) { return }
    $Parts = @((Get-Content $FocusFile -Raw).Trim() -split '\s+')
    if ($Parts.Count -lt 2) { Set-FocusPid $Parts[0]; return }
    $Window = [IntPtr][int64]$Parts[0]
    [uint32]$WindowPid = 0
    if ([MathWaiter.Win32]::IsWindow($Window)) { [void][MathWaiter.Win32]::GetWindowThreadProcessId($Window, [ref]$WindowPid) }
    if ($WindowPid -eq [uint32]$Parts[1] -and (Set-FocusWindow $Window)) { return }
    Set-FocusPid $Parts[1]
}

# Close the game window normally, so the browser shuts down cleanly, and force it only if it has
# not exited after 3 seconds. The game itself is saved on the server after every answer.
function Close-Game {
    $GamePid = Get-GamePid
    if (-not $GamePid) { return }
    $Game = Get-Process -Id $GamePid
    if (-not ($Game -and $Game.CloseMainWindow() -and $Game.WaitForExit(3000))) {
        taskkill /PID $GamePid /T /F | Out-Null
    }
}

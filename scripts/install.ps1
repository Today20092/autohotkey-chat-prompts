param(
    [string]$InstallDir = "$env:LOCALAPPDATA\ChatGPTPrompts",
    [switch]$Compile,
    [switch]$RunNow
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$RepoRoot = Split-Path $PSScriptRoot -Parent | Resolve-Path
$SourceDir = Join-Path $RepoRoot "src"
$InstallDir = [Environment]::ExpandEnvironmentVariables($InstallDir)
$DataDir = Join-Path $env:APPDATA "ChatGPTPrompts"
$TargetDir = Join-Path $InstallDir "src"

if (-not (Get-Command AutoHotkey -ErrorAction SilentlyContinue) -and -not (Get-Command AutoHotkey64 -ErrorAction SilentlyContinue)) {
    Write-Warning "AutoHotkey was not found on PATH. If this was downloaded from the repo, install AutoHotkey v2 first."
}

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null

Copy-Item (Join-Path $SourceDir "ChatGPTPrompts.ahk") $TargetDir -Force
Copy-Item (Join-Path $SourceDir "ChatGPT_Prompts.ahk") $TargetDir -Force

$startupFolder = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = Join-Path $startupFolder "ChatGPTPrompts.lnk"
$appPath = Join-Path $TargetDir "ChatGPTPrompts.ahk"
$exePath = Join-Path $InstallDir "dist\ChatGPTPrompts.exe"
$launchCommand = $null

if ($Compile -and (Get-Command ahk2exe -ErrorAction SilentlyContinue)) {
    & (Join-Path $RepoRoot "scripts\build-exe.ps1")
    if (Test-Path $exePath) {
        $launchCommand = $exePath
    } else {
        Write-Warning "Compilation did not produce an exe. Falling back to script launch."
    }
}

if (-not $launchCommand) {
    $ahk = (Get-Command AutoHotkey -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
    if (-not $ahk) {
        $ahk = (Get-Command AutoHotkey64 -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
    }
    if (-not $ahk) {
        throw "AutoHotkey executable not found on PATH. Install AutoHotkey v2 and rerun this script."
    }
    $launchCommand = "`"$ahk`" `"$appPath`""
}

$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($shortcutPath)
$link.TargetPath = "powershell.exe"
$link.Arguments = "-NoProfile -WindowStyle Hidden -Command `"$launchCommand`""
$link.WorkingDirectory = $InstallDir
$link.Description = "ChatGPT Prompt Menu"
$link.Save()

if ($RunNow) {
    if ($launchCommand -like "*.exe*") {
        Start-Process $launchCommand
    } else {
        Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -WindowStyle Hidden -Command $launchCommand"
    }
}

Write-Host "Installed to $TargetDir"
Write-Host "Auto-start shortcut: $shortcutPath"
Write-Host "Prompt data directory: $DataDir"
Write-Host "Run now: $RunNow"

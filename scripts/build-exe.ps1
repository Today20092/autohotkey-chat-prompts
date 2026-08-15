param(
    [string]$OutPath = (Join-Path $PSScriptRoot "..\dist")
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$RepoRoot = Join-Path $PSScriptRoot ".." | Resolve-Path
$Source = Join-Path $RepoRoot "src\ChatGPTPrompts.ahk"
$Ahk2Exe = Get-Command ahk2exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source

if (-not $Ahk2Exe) {
    throw "Ahk2Exe was not found on PATH. Install AutoHotkey v2 first."
}

New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
$OutExe = Join-Path $OutPath "ChatGPTPrompts.exe"

& $Ahk2Exe /in "$Source" /out "$OutExe"

Write-Host "Compiled: $OutExe"

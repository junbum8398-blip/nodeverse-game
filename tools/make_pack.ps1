param(
    [string]$Version = ("content-" + (Get-Date -Format "yyyy.MM.dd")),
    [string]$GodotExe = "C:\Users\Playdata\Desktop\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $RepoRoot "build\packs"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$PackFile = "$Version.pck"
$PackPath = Join-Path $OutDir $PackFile

if (-not (Test-Path $GodotExe)) {
    $GodotExe = "godot"
}

Write-Host "[NODEVERSE] Exporting Content Pack: $PackPath" -ForegroundColor Cyan
& $GodotExe --headless --path $RepoRoot --export-pack "Content Pack" $PackPath

if (-not (Test-Path $PackPath)) {
    throw "Failed to export pack file: $PackPath"
}

$Hash = (Get-FileHash -Path $PackPath -Algorithm SHA256).Hash.ToLower()
$Size = (Get-Item $PackPath).Length

Write-Host "`n=== Content Pack Ready ===" -ForegroundColor Green
Write-Host "file      : $PackFile"
Write-Host "sha256    : $Hash"
Write-Host "size      : $Size"
Write-Host "min_build : 0.3.0"

#requires -Version 5.1

<#
.SYNOPSIS
    Builds ALIA - HPE Aruba License Inventory Audit as a Windows EXE.

.DESCRIPTION
    Production build script for the ALIA v3.1 application line.

    The builder:
      - Installs/imports PS2EXE when required.
      - Generates the ALIA application icon at build time.
      - Compiles the PowerShell 5.1 WinForms application as a 64-bit,
        GUI-only Windows executable.
      - Embeds DPI-aware application metadata for high-DPI displays.
      - Embeds Windows file metadata in the EXE.
      - Does not require a separate splash image because the splash screen
        is generated entirely by the ALIA application script.
      - Places build output under .\dist, which is excluded from Git.

    Run this script on Windows PowerShell 5.1 on a Windows machine.

.NOTES
    Developed by Prathamesh Hankare
    Application line: v3.1
    Current application version: v3.1.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
else {
    (Get-Location).Path
}

$sourceScript = Join-Path $scriptDirectory 'ALIA-v3.1-dark.ps1'
$outputDirectory = Join-Path $scriptDirectory 'dist'
$outputExe = Join-Path $outputDirectory 'ALIA-v3.1.exe'
$tempIcon = Join-Path $outputDirectory 'ALIA-build-icon.ico'

if (-not (Test-Path -LiteralPath $sourceScript)) {
    throw "Source script not found: $sourceScript"
}

function Ensure-PS2EXE {
    if (-not (Get-Module -ListAvailable -Name ps2exe)) {
        Write-Host 'PS2EXE module not found. Installing for the current user...' -ForegroundColor Yellow
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
    }

    Import-Module ps2exe -ErrorAction Stop
}

function New-ALIAIcon {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Add-Type -AssemblyName System.Drawing

    $bitmap = New-Object System.Drawing.Bitmap(256, 256)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $rect = New-Object System.Drawing.Rectangle(0, 0, 256, 256)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(15,23,42),
        [System.Drawing.Color]::FromArgb(30,41,59),
        35
    )
    $graphics.FillRectangle($bg, $rect)
    $bg.Dispose()

    $accentPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(45,212,191), 8)
    $bluePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(56,189,248), 5)

    $graphics.DrawLine($bluePen, 56, 128, 103, 84)
    $graphics.DrawLine($bluePen, 103, 84, 154, 124)
    $graphics.DrawLine($accentPen, 154, 124, 195, 79)

    $nodeBlue = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(56,189,248))
    $nodeTeal = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45,212,191))

    $graphics.FillEllipse($nodeBlue, 42, 114, 28, 28)
    $graphics.FillEllipse($nodeTeal, 89, 70, 28, 28)
    $graphics.FillEllipse($nodeBlue, 140, 110, 28, 28)
    $graphics.FillEllipse($nodeTeal, 181, 65, 28, 28)

    $font = New-Object System.Drawing.Font(
        'Segoe UI Semibold',
        42,
        [System.Drawing.FontStyle]::Bold
    )
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $graphics.DrawString('A', $font, $brush, 102, 146)

    $brush.Dispose()
    $font.Dispose()
    $nodeBlue.Dispose()
    $nodeTeal.Dispose()
    $accentPen.Dispose()
    $bluePen.Dispose()
    $graphics.Dispose()

    $iconHandle = $bitmap.GetHicon()
    try {
        $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
        $stream = New-Object System.IO.FileStream(
            $Path,
            [System.IO.FileMode]::Create
        )
        try {
            $icon.Save($stream)
        }
        finally {
            $stream.Dispose()
            $icon.Dispose()
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host ' ALIA - Aruba License Inventory Audit' -ForegroundColor Cyan
Write-Host ' Production EXE Build - v3.1.0' -ForegroundColor Cyan
Write-Host ' Developed by Prathamesh Hankare' -ForegroundColor DarkGray
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host ''

Ensure-PS2EXE

if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

if (Test-Path -LiteralPath $outputExe) {
    Remove-Item -LiteralPath $outputExe -Force
}

if (Test-Path -LiteralPath $tempIcon) {
    Remove-Item -LiteralPath $tempIcon -Force
}

Write-Host 'Generating embedded application icon...' -ForegroundColor Gray
New-ALIAIcon -Path $tempIcon

Write-Host 'Compiling ALIA...' -ForegroundColor Gray

$compileParameters = @{
    inputFile   = $sourceScript
    outputFile  = $outputExe
    noConsole   = $true
    STA         = $true
    x64         = $true
    DPIAware    = $true
    iconFile    = $tempIcon
    title       = 'HPE Aruba License Inventory Audit'
    description = 'HPE GreenLake + Aruba Central reconciliation and license audit application.'
    company     = 'Prathamesh Hankare'
    product     = 'ALIA - Aruba License Inventory Audit'
    copyright   = 'Copyright (c) 2026 Prathamesh Hankare'
    trademark   = 'ALIA'
    version     = '3.1.0.0'
}

Invoke-ps2exe @compileParameters

if (Test-Path -LiteralPath $tempIcon) {
    Remove-Item -LiteralPath $tempIcon -Force
}

if (-not (Test-Path -LiteralPath $outputExe)) {
    throw "EXE build failed. Output was not created: $outputExe"
}

$exeInfo = Get-Item -LiteralPath $outputExe

Write-Host ''
Write-Host 'Build completed successfully.' -ForegroundColor Green
Write-Host "EXE : $($exeInfo.FullName)" -ForegroundColor White
Write-Host "Size: $([Math]::Round($exeInfo.Length / 1MB, 2)) MB" -ForegroundColor White
Write-Host 'Build output is under .\dist and is excluded from Git.' -ForegroundColor White
Write-Host 'Logs will be written to the Logs directory next to the EXE.' -ForegroundColor White
Write-Host ''

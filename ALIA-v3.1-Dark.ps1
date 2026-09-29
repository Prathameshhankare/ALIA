#requires -Version 5.1

<#!
.SYNOPSIS
    ALIA v3.1 dark-mode launcher with embedded KPI icons.

.DESCRIPTION
    Builds a dark-mode ALIA v3.1 instance from the GitHub-tracked
    ALIA-v3.1.ps1 source. The audit/reconciliation engine is not changed.

    This script replaces the earlier marker-based launcher that could fail
    with "Could not locate the ALIA main-form launch point". It supports the
    known ShowDialog forms used by ALIA and uses exact/regex matching instead
    of PowerShell wildcard matching.

    KPI icons are drawn with System.Drawing at runtime; no external icon files
    are required.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

param(
    [string]$SourcePath = (Join-Path $PSScriptRoot 'ALIA-v3.1.ps1'),
    [switch]$KeepGeneratedScript
)

if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    throw "ALIA source script was not found: $SourcePath"
}

$source = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8

# ---------------------------------------------------------------------------
# Dark theme and embedded vector-style icons
# ---------------------------------------------------------------------------

$theme = @'
# ---------------------------------------------------------------------------
# ALIA v3.1 Dark Mode - visual layer only
# ---------------------------------------------------------------------------

$script:ALIA_DARK = $true

$script:DarkTheme = @{
    Window   = [System.Drawing.Color]::FromArgb(7,15,28)
    Panel    = [System.Drawing.Color]::FromArgb(15,25,39)
    Panel2   = [System.Drawing.Color]::FromArgb(17,30,46)
    Input    = [System.Drawing.Color]::FromArgb(10,20,34)
    Grid     = [System.Drawing.Color]::FromArgb(11,22,36)
    GridAlt  = [System.Drawing.Color]::FromArgb(14,27,43)
    Border   = [System.Drawing.Color]::FromArgb(38,61,86)
    Header   = [System.Drawing.Color]::FromArgb(20,35,54)
    Text     = [System.Drawing.Color]::FromArgb(226,232,240)
    Muted    = [System.Drawing.Color]::FromArgb(148,163,184)
    Accent   = [System.Drawing.Color]::FromArgb(0,210,145)
    Blue     = [System.Drawing.Color]::FromArgb(59,130,246)
    Cyan     = [System.Drawing.Color]::FromArgb(34,211,238)
    Purple   = [System.Drawing.Color]::FromArgb(168,85,247)
    Warning  = [System.Drawing.Color]::FromArgb(250,204,21)
    Critical = [System.Drawing.Color]::FromArgb(248,70,70)
    Healthy  = [System.Drawing.Color]::FromArgb(34,197,94)
    Selected = [System.Drawing.Color]::FromArgb(24,76,150)
}

function Set-ALIAControlTheme {
    param([System.Windows.Forms.Control]$Control)
    if ($null -eq $Control -or $Control.IsDisposed) { return }
    $t = $script:DarkTheme

    if ($Control -is [System.Windows.Forms.Form]) {
        $Control.BackColor = $t.Window
        $Control.ForeColor = $t.Text
    }
    elseif ($Control -is [System.Windows.Forms.DataGridView]) {
        $Control.BackgroundColor = $t.Grid
        $Control.GridColor = $t.Border
        $Control.EnableHeadersVisualStyles = $false
        $Control.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $Control.ColumnHeadersDefaultCellStyle.BackColor = $t.Header
        $Control.ColumnHeadersDefaultCellStyle.ForeColor = $t.Text
        $Control.ColumnHeadersDefaultCellStyle.SelectionBackColor = $t.Header
        $Control.ColumnHeadersDefaultCellStyle.SelectionForeColor = $t.Text
        $Control.DefaultCellStyle.BackColor = $t.Grid
        $Control.DefaultCellStyle.ForeColor = $t.Text
        $Control.DefaultCellStyle.SelectionBackColor = $t.Selected
        $Control.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
        $Control.AlternatingRowsDefaultCellStyle.BackColor = $t.GridAlt
        $Control.AlternatingRowsDefaultCellStyle.ForeColor = $t.Text
        $Control.RowHeadersDefaultCellStyle.BackColor = $t.Header
        $Control.RowHeadersDefaultCellStyle.ForeColor = $t.Muted
        $Control.RowHeadersVisible = $false
    }
    elseif ($Control -is [System.Windows.Forms.TextBoxBase]) {
        $Control.BackColor = $t.Input
        $Control.ForeColor = $t.Text
        $Control.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    }
    elseif ($Control -is [System.Windows.Forms.ComboBox]) {
        $Control.BackColor = $t.Input
        $Control.ForeColor = $t.Text
        $Control.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    }
    elseif ($Control -is [System.Windows.Forms.Button]) {
        $Control.BackColor = $t.Panel2
        $Control.ForeColor = $t.Text
        $Control.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $Control.FlatAppearance.BorderColor = $t.Border
        $Control.FlatAppearance.MouseOverBackColor = $t.Header
        $Control.FlatAppearance.MouseDownBackColor = $t.Selected
    }
    elseif ($Control -is [System.Windows.Forms.CheckBox] -or $Control -is [System.Windows.Forms.RadioButton]) {
        $Control.BackColor = $t.Panel
        $Control.ForeColor = $t.Text
    }
    elseif ($Control -is [System.Windows.Forms.GroupBox]) {
        $Control.BackColor = $t.Panel
        $Control.ForeColor = $t.Text
    }
    elseif ($Control -is [System.Windows.Forms.Label]) {
        if ($Control.ForeColor.ToArgb() -eq [System.Drawing.Color]::Black.ToArgb() -or
            $Control.ForeColor.ToArgb() -eq [System.Drawing.SystemColors]::ControlText.ToArgb()) {
            $Control.ForeColor = $t.Text
        }
        $Control.BackColor = [System.Drawing.Color]::Transparent
    }
    elseif ($Control -is [System.Windows.Forms.Panel] -or
            $Control -is [System.Windows.Forms.TableLayoutPanel] -or
            $Control -is [System.Windows.Forms.FlowLayoutPanel]) {
        $Control.BackColor = $t.Panel
        $Control.ForeColor = $t.Text
    }
    elseif ($Control -is [System.Windows.Forms.SplitContainer]) {
        $Control.BackColor = $t.Panel
        $Control.ForeColor = $t.Text
        try { $Control.Panel1.BackColor = $t.Panel } catch {}
        try { $Control.Panel2.BackColor = $t.Panel } catch {}
    }
    elseif ($Control -is [System.Windows.Forms.RichTextBox]) {
        $Control.BackColor = $t.Input
        $Control.ForeColor = $t.Text
    }
    elseif ($Control -is [System.Windows.Forms.ListView]) {
        $Control.BackColor = $t.Grid
        $Control.ForeColor = $t.Text
    }

    foreach ($child in @($Control.Controls)) {
        Set-ALIAControlTheme -Control $child
    }
}

function Find-ALIALabel {
    param([System.Windows.Forms.Control]$Root,[string]$Text)
    foreach ($control in @($Root.Controls)) {
        if ($control -is [System.Windows.Forms.Label] -and [string]$control.Text -eq $Text) {
            return $control
        }
        if ($control.Controls.Count -gt 0) {
            $found = Find-ALIALabel -Root $control -Text $Text
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Draw-ALIAIcon {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Rectangle]$Bounds,
        [ValidateSet('Inventory','Database','Monitor','License','Alert','Clock','Health')]
        [string]$Kind,
        [System.Drawing.Color]$Color
    )

    $pen = New-Object System.Drawing.Pen($Color, [Math]::Max(1,[int]($Bounds.Width * 0.08)))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $brush = New-Object System.Drawing.SolidBrush($Color)
    $x = $Bounds.X; $y = $Bounds.Y; $w = $Bounds.Width; $h = $Bounds.Height

    try {
        switch ($Kind) {
            'Inventory' {
                $Graphics.DrawRectangle($pen,$x+3,$y+3,$w-6,$h-6)
                $Graphics.DrawLine($pen,$x+9,$y+12,$x+$w-9,$y+12)
                $Graphics.DrawLine($pen,$x+9,$y+19,$x+$w-9,$y+19)
                $Graphics.DrawLine($pen,$x+9,$y+26,$x+$w-9,$y+26)
            }
            'Database' {
                $Graphics.DrawEllipse($pen,$x+3,$y+2,$w-6,9)
                $Graphics.DrawLine($pen,$x+3,$y+6,$x+3,$y+$h-7)
                $Graphics.DrawLine($pen,$x+$w-3,$y+6,$x+$w-3,$y+$h-7)
                $Graphics.DrawArc($pen,$x+3,$y+$h-12,$w-6,9,0,180)
                $Graphics.DrawArc($pen,$x+3,$y+10,$w-6,9,0,180)
            }
            'Monitor' {
                $Graphics.DrawRectangle($pen,$x+3,$y+3,$w-6,$h-10)
                $Graphics.DrawLine($pen,$x+$w/2,$y+$h-7,$x+$w/2,$y+$h-2)
                $Graphics.DrawLine($pen,$x+8,$y+$h-2,$x+$w-8,$y+$h-2)
            }
            'License' {
                $Graphics.DrawRectangle($pen,$x+4,$y+2,$w-8,$h-4)
                $Graphics.DrawLine($pen,$x+10,$y+10,$x+$w-10,$y+10)
                $Graphics.DrawLine($pen,$x+10,$y+17,$x+$w-13,$y+17)
                $Graphics.DrawLine($pen,$x+10,$y+24,$x+$w-17,$y+24)
                $Graphics.FillEllipse($brush,$x+$w-13,$y+$h-13,7,7)
            }
            'Alert' {
                $points = [System.Drawing.Point[]]@(
                    [System.Drawing.Point]::new($x+$w/2,$y+2),
                    [System.Drawing.Point]::new($x+$w-3,$y+$h-3),
                    [System.Drawing.Point]::new($x+3,$y+$h-3)
                )
                $Graphics.DrawPolygon($pen,$points)
                $Graphics.DrawLine($pen,$x+$w/2,$y+11,$x+$w/2,$y+20)
                $Graphics.FillEllipse($brush,$x+$w/2-1.5,$y+24,3,3)
            }
            'Clock' {
                $Graphics.DrawEllipse($pen,$x+3,$y+3,$w-6,$h-6)
                $Graphics.DrawLine($pen,$x+$w/2,$y+9,$x+$w/2,$y+$h/2)
                $Graphics.DrawLine($pen,$x+$w/2,$y+$h/2,$x+$w-9,$y+$h/2)
            }
            'Health' {
                $Graphics.DrawArc($pen,$x+3,$y+3,$w-6,$h-6,210,240)
                $Graphics.DrawLine($pen,$x+$w/2,$y+$h/2,$x+$w-8,$y+9)
                $Graphics.FillEllipse($brush,$x+$w/2-3,$y+$h/2-3,6,6)
            }
        }
    }
    finally {
        $pen.Dispose(); $brush.Dispose()
    }
}

function Add-ALIAIconBadge {
    param(
        [System.Windows.Forms.Label]$Label,
        [string]$Kind,
        [System.Drawing.Color]$Color
    )
    if ($null -eq $Label) { return }

    $host = New-Object System.Windows.Forms.Panel
    $host.Size = [System.Drawing.Size]::new(34,34)
    $host.Location = [System.Drawing.Point]::new(8,7)
    $host.BackColor = [System.Drawing.Color]::Transparent
    $host.Tag = 'ALIA_ICON'
    $host.Add_Paint({
        param($sender,$e)
        Draw-ALIAIcon -Graphics $e.Graphics -Bounds ([System.Drawing.Rectangle]::new(2,2,30,30)) -Kind $sender.TagKind -Color $sender.TagColor
    })
    $host | Add-Member -NotePropertyName TagKind -NotePropertyValue $Kind -Force
    $host | Add-Member -NotePropertyName TagColor -NotePropertyValue $Color -Force

    $parent = $Label.Parent
    if ($null -eq $parent) { return }
    $parent.Controls.Add($host)
    $host.BringToFront()

    $Label.Left = [Math]::Max($Label.Left,42)
    $Label.Tag = 'ALIA_ICON_LABEL'
}

function Add-ALIAIcons {
    param([System.Windows.Forms.Form]$Form)
    $items = @(
        @{Text='GreenLake Inventory'; Kind='Inventory'; Color=$script:DarkTheme.Blue},
        @{Text='Central Inventory'; Kind='Database'; Color=$script:DarkTheme.Purple},
        @{Text='Central Monitored'; Kind='Monitor'; Color=$script:DarkTheme.Cyan},
        @{Text='Licensed Devices'; Kind='License'; Color=$script:DarkTheme.Healthy},
        @{Text='Exceptions'; Kind='Alert'; Color=$script:DarkTheme.Critical},
        @{Text='Expired Licenses'; Kind='Clock'; Color=$script:DarkTheme.Warning},
        @{Text='AUDIT HEALTH'; Kind='Health'; Color=$script:DarkTheme.Critical}
    )

    foreach ($item in $items) {
        $label = Find-ALIALabel -Root $Form -Text $item.Text
        if ($null -ne $label) {
            $already = $false
            foreach ($c in @($label.Parent.Controls)) {
                if ($c.Tag -eq 'ALIA_ICON' -and $c.TagKind -eq $item.Kind) { $already=$true; break }
            }
            if (-not $already) { Add-ALIAIconBadge -Label $label -Kind $item.Kind -Color $item.Color }
            $label.ForeColor = $item.Color
        }
    }
}

function Apply-ALIAWindowTheme {
    foreach ($form in [System.Windows.Forms.Application]::OpenForms) {
        try {
            Set-ALIAControlTheme -Control $form
            Add-ALIAIcons -Form $form
        } catch {}
    }
}

Apply-ALIAWindowTheme
$script:DarkThemeTimer = New-Object System.Windows.Forms.Timer
$script:DarkThemeTimer.Interval = 300
$script:DarkThemeTimer.Add_Tick({ Apply-ALIAWindowTheme })
$script:DarkThemeTimer.Start()

'@

# ---------------------------------------------------------------------------
# Locate ALIA's main form launch point robustly.
# ---------------------------------------------------------------------------

$patterns = @(
    '(?m)^(?<indent>\s*)\[void\]\s*\$script:frm\.ShowDialog\(\)\s*$',
    '(?m)^(?<indent>\s*)\$script:frm\.ShowDialog\(\)\s*$',
    '(?m)^(?<indent>\s*)\[void\]\s*\$frm\.ShowDialog\(\)\s*$',
    '(?m)^(?<indent>\s*)\$frm\.ShowDialog\(\)\s*$'
)

$match = $null
foreach ($pattern in $patterns) {
    $candidate = [regex]::Match($source,$pattern)
    if ($candidate.Success) {
        $match = $candidate
        break
    }
}

if ($null -eq $match) {
    throw "Could not locate the ALIA main-form launch point. Supported forms: `$script:frm.ShowDialog(), `$frm.ShowDialog(), with or without [void]."
}

# Insert the dark layer immediately before ShowDialog().
$launchLine = $match.Value
$replacement = $theme + "`r`n" + $launchLine
$darkSource = $source.Remove($match.Index,$match.Length).Insert($match.Index,$replacement)

$outputPath = Join-Path $PSScriptRoot 'ALIA-v3.1-dark-generated.ps1'
Set-Content -LiteralPath $outputPath -Value $darkSource -Encoding UTF8

Write-Host "Generated dark ALIA script: $outputPath" -ForegroundColor Green
Write-Host 'Launching ALIA v3.1 dark mode...' -ForegroundColor Cyan

try {
    & $outputPath
}
finally {
    if (-not $KeepGeneratedScript) {
        try { Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue } catch {}
    }
}

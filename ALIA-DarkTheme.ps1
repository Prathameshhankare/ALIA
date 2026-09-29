# ALIA v3.1 Dark Mode launcher/patcher
# Reads the existing ALIA-v3.1.ps1 and injects the dark theme immediately
# before the main form is shown. The audit/reconciliation engine is untouched.

param(
    [string]$SourcePath = (Join-Path $PSScriptRoot 'ALIA-v3.1.ps1')
)

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "ALIA source script was not found: $SourcePath"
}

$source = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
$marker = '[void]$script:frm.ShowDialog()'

# Do not use -like here. The marker contains '[' and ']', which are wildcard
# character-class operators in PowerShell -like matching. Use an exact string
# search instead.
if (-not $source.Contains($marker)) {
    throw "Could not locate the ALIA main-form launch point in '$SourcePath'. Expected: $marker"
}

$theme = @'
# ---------------------------------------------------------------------------
# ALIA Dark Mode - visual layer only
# ---------------------------------------------------------------------------
$script:ALIA_DARK = $true

$script:DarkTheme = @{
    Window      = [System.Drawing.Color]::FromArgb(7,15,28)
    Panel       = [System.Drawing.Color]::FromArgb(15,25,39)
    Panel2      = [System.Drawing.Color]::FromArgb(17,30,46)
    Input       = [System.Drawing.Color]::FromArgb(10,20,34)
    Grid        = [System.Drawing.Color]::FromArgb(11,22,36)
    GridAlt     = [System.Drawing.Color]::FromArgb(14,27,43)
    Border      = [System.Drawing.Color]::FromArgb(38,61,86)
    Header      = [System.Drawing.Color]::FromArgb(20,35,54)
    Text        = [System.Drawing.Color]::FromArgb(226,232,240)
    Muted       = [System.Drawing.Color]::FromArgb(148,163,184)
    Accent      = [System.Drawing.Color]::FromArgb(0,210,145)
    Blue        = [System.Drawing.Color]::FromArgb(59,130,246)
    Cyan        = [System.Drawing.Color]::FromArgb(34,211,238)
    Purple      = [System.Drawing.Color]::FromArgb(168,85,247)
    Warning     = [System.Drawing.Color]::FromArgb(250,204,21)
    Critical    = [System.Drawing.Color]::FromArgb(248,70,70)
    Healthy     = [System.Drawing.Color]::FromArgb(34,197,94)
    Selected    = [System.Drawing.Color]::FromArgb(24,76,150)
}

function Set-ALIAControlTheme {
    param([System.Windows.Forms.Control]$Control)
    if ($null -eq $Control -or $Control.IsDisposed) { return }
    $t = $script:DarkTheme

    if ($Control -is [System.Windows.Forms.Form]) {
        $Control.BackColor = $t.Window; $Control.ForeColor = $t.Text
    }
    elseif ($Control -is [System.Windows.Forms.DataGridView]) {
        $Control.BackgroundColor = $t.Grid; $Control.GridColor = $t.Border
        $Control.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $Control.EnableHeadersVisualStyles = $false
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
        $Control.BackColor = $t.Input; $Control.ForeColor = $t.Text
        $Control.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    }
    elseif ($Control -is [System.Windows.Forms.ComboBox]) {
        $Control.BackColor = $t.Input; $Control.ForeColor = $t.Text
        $Control.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    }
    elseif ($Control -is [System.Windows.Forms.Button]) {
        $Control.BackColor = $t.Panel2; $Control.ForeColor = $t.Text
        $Control.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $Control.FlatAppearance.BorderColor = $t.Border
        $Control.FlatAppearance.MouseOverBackColor = $t.Header
        $Control.FlatAppearance.MouseDownBackColor = $t.Selected
    }
    elseif ($Control -is [System.Windows.Forms.CheckBox] -or $Control -is [System.Windows.Forms.RadioButton]) {
        $Control.BackColor = $t.Panel; $Control.ForeColor = $t.Text
    }
    elseif ($Control -is [System.Windows.Forms.GroupBox]) {
        $Control.BackColor = $t.Panel; $Control.ForeColor = $t.Text
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
            $Control -is [System.Windows.Forms.FlowLayoutPanel] -or
            $Control -is [System.Windows.Forms.SplitContainer]) {
        $Control.BackColor = $t.Panel; $Control.ForeColor = $t.Text
    }
    elseif ($Control -is [System.Windows.Forms.RichTextBox]) {
        $Control.BackColor = $t.Input; $Control.ForeColor = $t.Text
    }
    elseif ($Control -is [System.Windows.Forms.ListView]) {
        $Control.BackColor = $t.Grid; $Control.ForeColor = $t.Text
    }

    foreach ($child in @($Control.Controls)) { Set-ALIAControlTheme -Control $child }
}

function Add-ALIAIconToLabel {
    param([System.Windows.Forms.Control]$Root,[string]$Match,[string]$Glyph,[System.Drawing.Color]$Color)
    foreach ($control in @($Root.Controls)) {
        if ($control -is [System.Windows.Forms.Label]) {
            $text = [string]$control.Text
            if (($text -eq $Match -or $text -like "$Match*") -and $text -notmatch '^[▣▤▥▦⚠◷]') {
                $control.Text = "$Glyph  $text"; $control.ForeColor = $Color
            }
        }
        if ($control.Controls.Count -gt 0) { Add-ALIAIconToLabel -Root $control -Match $Match -Glyph $Glyph -Color $Color }
    }
}

function Invoke-ALIAIconPass {
    param([System.Windows.Forms.Form]$Form)
    try {
        Add-ALIAIconToLabel $Form 'GreenLake Inventory' '▣' $script:DarkTheme.Blue
        Add-ALIAIconToLabel $Form 'Central Inventory' '▤' $script:DarkTheme.Purple
        Add-ALIAIconToLabel $Form 'Central Monitored' '▥' $script:DarkTheme.Cyan
        Add-ALIAIconToLabel $Form 'Licensed Devices' '▦' $script:DarkTheme.Healthy
        Add-ALIAIconToLabel $Form 'Exceptions' '⚠' $script:DarkTheme.Critical
        Add-ALIAIconToLabel $Form 'Expired Licenses' '◷' $script:DarkTheme.Warning
        Add-ALIAIconToLabel $Form 'AUDIT HEALTH' '⚠' $script:DarkTheme.Critical
    } catch {}
}

function Apply-ALIAWindowTheme {
    foreach ($form in [System.Windows.Forms.Application]::OpenForms) {
        try { Set-ALIAControlTheme -Control $form; Invoke-ALIAIconPass -Form $form } catch {}
    }
}

Apply-ALIAWindowTheme
$script:DarkThemeTimer = New-Object System.Windows.Forms.Timer
$script:DarkThemeTimer.Interval = 300
$script:DarkThemeTimer.Add_Tick({ Apply-ALIAWindowTheme })
$script:DarkThemeTimer.Start()

'@

$replacement = $theme + "`r`n$marker"
$darkSource = $source.Replace($marker, $replacement)
$outputPath = Join-Path (Split-Path -Parent $SourcePath) 'ALIA-v3.1-dark.ps1'
Set-Content -LiteralPath $outputPath -Value $darkSource -Encoding UTF8
Write-Host "Created: $outputPath" -ForegroundColor Green

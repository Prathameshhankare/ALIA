#requires -Version 5.1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sourcePath = Join-Path $repoRoot 'ALIA-v3.2.ps1'
$tokens = $null
$parseErrors = $null
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $sourcePath,
    [ref]$tokens,
    [ref]$parseErrors
)

if ($parseErrors.Count -gt 0) {
    $parseErrors | Format-List | Out-String | Write-Error
}

$functionNames = @(
    'Convert-ALIAValue',
    'Position-ActionPanel',
    'Position-HealthCard',
    'Position-KpiCard',
    'Position-DetailHeader'
)

foreach ($name in $functionNames) {
    $functionAst = $sourceAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $name
    }, $true)

    if ($null -eq $functionAst) {
        throw "Missing responsive layout function: $name"
    }

    Invoke-Expression $functionAst.Extent.Text
}

function Assert-ControlBounds {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($Control.Width -le 0 -or $Control.Height -le 0) {
        throw "$Name has invalid bounds: $($Control.Bounds)."
    }
}

$actions = New-Object System.Windows.Forms.Panel
$runPanel = New-Object System.Windows.Forms.Panel
$runHint = New-Object System.Windows.Forms.Label
$secondary = New-Object System.Windows.Forms.Panel
[void]$actions.Controls.Add($runPanel)
[void]$actions.Controls.Add($runHint)
[void]$actions.Controls.Add($secondary)

$healthCard = New-Object System.Windows.Forms.Panel
$healthTitleIconHost = New-Object System.Windows.Forms.Panel
$healthHeadlineIconHost = New-Object System.Windows.Forms.Panel
$healthTitle = New-Object System.Windows.Forms.Label
$script:healthHeadline = New-Object System.Windows.Forms.Label
$healthStats = New-Object System.Windows.Forms.Panel

$kpi = [pscustomobject]@{
    Panel   = (New-Object System.Windows.Forms.Panel)
    Icon    = (New-Object System.Windows.Forms.Label)
    Caption = (New-Object System.Windows.Forms.Label)
    Value   = (New-Object System.Windows.Forms.Label)
    Trend   = (New-Object System.Windows.Forms.Label)
}

$detailHeader = New-Object System.Windows.Forms.Panel
$script:detailTitle = New-Object System.Windows.Forms.Label
$script:detailStatus = New-Object System.Windows.Forms.Label

foreach ($scale in @(1.0, 1.25, 1.5, 2.0)) {
    $script:DpiScale = $scale

    $actions.ClientSize = [System.Drawing.Size]::new(420, 220)
    Position-ActionPanel
    Assert-ControlBounds $runPanel 'Run panel'
    Assert-ControlBounds $runHint 'Run hint'
    Assert-ControlBounds $secondary 'Secondary actions panel'

    $healthCard.ClientSize = [System.Drawing.Size]::new(420, 160)
    Position-HealthCard
    Assert-ControlBounds $healthTitleIconHost 'Health title icon'
    Assert-ControlBounds $healthHeadlineIconHost 'Health headline icon'
    Assert-ControlBounds $healthTitle 'Health title'
    Assert-ControlBounds $script:healthHeadline 'Health headline'
    Assert-ControlBounds $healthStats 'Health metrics'

    $kpi.Panel.ClientSize = [System.Drawing.Size]::new(210, 96)
    Position-KpiCard -Kpi $kpi
    Assert-ControlBounds $kpi.Icon 'KPI icon'
    Assert-ControlBounds $kpi.Caption 'KPI caption'
    Assert-ControlBounds $kpi.Value 'KPI value'
    Assert-ControlBounds $kpi.Trend 'KPI trend'

    $detailHeader.ClientSize = [System.Drawing.Size]::new(280, 80)
    Position-DetailHeader
    Assert-ControlBounds $script:detailTitle 'Device detail title'
    Assert-ControlBounds $script:detailStatus 'Device detail status'
}

Write-Host 'Responsive layout checks passed at 100%, 125%, 150%, and 200% DPI scales.'

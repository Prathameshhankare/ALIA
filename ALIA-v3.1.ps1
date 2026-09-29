#requires -Version 5.1

<#
.SYNOPSIS
    ALIA - HPE Aruba License Inventory Audit
    HPE GreenLake + Aruba Central Reconciliation
    Developed by Prathamesh Hankare

.VERSION
    3.1

.DESCRIPTION
    Enterprise WinForms application that:
      - Tests HPE GreenLake and Aruba Central connectivity with one button.
      - Retrieves HPE GreenLake device inventory.
      - Retrieves Aruba Central device inventory and monitored devices.
      - Matches devices primarily by serial number and secondarily by MAC address.
      - Reconciles GreenLake licensing with Aruba Central inventory and monitoring state.
      - Identifies licensing and monitoring exceptions through clickable dashboard tiles.
      - Displays device-type counts for Access Points, Switches, Gateways and Other.
      - Provides detailed audit logging, progress reporting, search and CSV export.

    Compatibility:
      Windows PowerShell 5.1 / PowerShell ISE

.SECURITY
    Client IDs and Client Secrets are entered at runtime.
    Credentials are not written to the audit log or exported to CSV.
    GreenLake and Aruba Central endpoints are fixed in the application.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Data

# ---------------------------------------------------------------------------
# Embedded startup splash
# ---------------------------------------------------------------------------

$script:StartupSplash = $null

function Show-StartupSplash {
    $splash = New-Object System.Windows.Forms.Form
    $splash.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $splash.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $splash.ClientSize = [System.Drawing.Size]::new(620, 340)
    $splash.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $splash.AutoScaleDimensions = [System.Drawing.SizeF]::new(96, 96)
    $splash.ShowInTaskbar = $false
    $splash.TopMost = $true
    # DoubleBuffered is intentionally not set here.
    # In Windows PowerShell 5.1 it is a protected WinForms property and should
    # not be assigned directly from PowerShell. The splash renders cleanly
    # without modifying it.
    $splash.BackColor = [System.Drawing.Color]::FromArgb(15,23,42)

    $splash.Add_Paint({
        param($sender, $paintArgs)
        $graphics = $paintArgs.Graphics
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

        # Render the splash proportionally so it remains visually consistent
        # across different DPI settings and display resolutions.
        $scaleX = $sender.ClientSize.Width / 620.0
        $scaleY = $sender.ClientSize.Height / 340.0
        $s = [Math]::Min($scaleX, $scaleY)
        if ($s -le 0) { $s = 1.0 }
        $ox = ($sender.ClientSize.Width - (620 * $s)) / 2.0
        $oy = ($sender.ClientSize.Height - (340 * $s)) / 2.0

        function S([double]$n) { return [int][Math]::Round($n * $s) }
        function SX([double]$n) { return [int][Math]::Round($ox + ($n * $s)) }
        function SY([double]$n) { return [int][Math]::Round($oy + ($n * $s)) }
        function SR([double]$x,[double]$y,[double]$w,[double]$h) {
            return [System.Drawing.Rectangle]::new((SX $x),(SY $y),(S $w),(S $h))
        }


        $rect = [System.Drawing.Rectangle]::new(0, 0, $sender.ClientSize.Width, $sender.ClientSize.Height)
        $topColor = [System.Drawing.Color]::FromArgb(15,23,42)
        $bottomColor = [System.Drawing.Color]::FromArgb(30,41,59)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect, $topColor, $bottomColor, 35
        )
        $graphics.FillRectangle($brush, $rect)
        $brush.Dispose()

        # Accent panel
        $graphics.FillRectangle(
            [System.Drawing.Brushes]::White,
            (SR 36 48 6 190)
        )

        # Stylized ALIA network mark - generated entirely in code.
        $nodeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(56,189,248))
        $nodeBrush2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45,212,191))
        $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100,116,139), [Math]::Max(1, [int][Math]::Round(2 * $s)))
        $graphics.DrawLine($linePen, (SX 94), (SY 83), (SX 138), (SY 58))
        $graphics.DrawLine($linePen, (SX 138), (SY 58), (SX 177), (SY 88))
        $graphics.DrawLine($linePen, (SX 94), (SY 83), (SX 127), (SY 122))
        $graphics.DrawLine($linePen, (SX 177), (SY 88), (SX 159), (SY 129))
        $graphics.FillEllipse($nodeBrush, (SR 85 74 18 18))
        $graphics.FillEllipse($nodeBrush2, (SR 129 49 18 18))
        $graphics.FillEllipse($nodeBrush, (SR 168 79 18 18))
        $graphics.FillEllipse($nodeBrush2, (SR 118 113 18 18))
        $graphics.FillEllipse($nodeBrush, (SR 150 120 18 18))
        $linePen.Dispose()
        $nodeBrush.Dispose()
        $nodeBrush2.Dispose()

        $brandFont = New-Object System.Drawing.Font('Segoe UI Semibold', [Math]::Max(18, [int][Math]::Round(32 * $s)))
        $titleFont = New-Object System.Drawing.Font('Segoe UI Semibold', [Math]::Max(13, [int][Math]::Round(20 * $s)))
        $bodyFont = New-Object System.Drawing.Font('Segoe UI', [Math]::Max(8, [Math]::Round(10.5 * $s,1)))
        $smallFont = New-Object System.Drawing.Font('Segoe UI', [Math]::Max(7, [Math]::Round(9 * $s,1)))

        $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $muted = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148,163,184))
        $accent = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45,212,191))

        $graphics.DrawString('ALIA', $brandFont, $white, (SX 215), (SY 62))
        $graphics.DrawString('Aruba License Inventory Audit', $titleFont, $white, (SX 215), (SY 112))
        $graphics.DrawString('HPE GreenLake + Aruba Central reconciliation', $bodyFont, $muted, (SX 216), (SY 153))
        $graphics.DrawString('Inventory  •  Licensing  •  Monitoring  •  Audit', $smallFont, $accent, (SX 216), (SY 182))
        $graphics.DrawString('Developed by Prathamesh Hankare', $smallFont, $muted, (SX 216), (SY 246))
        $graphics.DrawString('Version 3.1', $smallFont, $muted, (SX 216), (SY 268))

        $progressPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(51,65,85), [Math]::Max(1, [int][Math]::Round(1 * $s)))
        $graphics.DrawRectangle($progressPen, (SX 216), (SY 296), (S 330), (S 5))
        $progressPen.Dispose()
        $graphics.FillRectangle($accent, (SR 216 296 82 5))

        $white.Dispose()
        $muted.Dispose()
        $accent.Dispose()
        $brandFont.Dispose()
        $titleFont.Dispose()
        $bodyFont.Dispose()
        $smallFont.Dispose()
    })

    $splash.Show()
    [System.Windows.Forms.Application]::DoEvents()
    # TEMPORARY: keep the splash visible for 5 seconds for design/resolution review.
    # Reduce to ~250 ms for the final production splash.
    Start-Sleep -Milliseconds 250
    [System.Windows.Forms.Application]::DoEvents()
    return $splash
}

function Close-StartupSplash {
    try {
        if ($null -ne $script:StartupSplash -and -not $script:StartupSplash.IsDisposed) {
            $script:StartupSplash.Close()
            $script:StartupSplash.Dispose()
        }
    } catch {}
    $script:StartupSplash = $null
}

$script:StartupSplash = Show-StartupSplash

# ---------------------------------------------------------------------------
# Application configuration
# ---------------------------------------------------------------------------

$script:AppName = 'HPE Aruba License Inventory Audit'
$script:AppVersion = 'v3.1.0'

# HPE GreenLake
$script:GreenLakeBaseUrl = 'https://global.api.greenlake.hpe.com'
$script:GreenLakeTokenUrl = "$script:GreenLakeBaseUrl/authorization/v2/oauth2/95dc91947ab811ec958f52b1e61a20e5/token"
$script:GreenLakeDeviceApiUrl = "$script:GreenLakeBaseUrl/devices/v1/devices"

# Aruba Central / HPE Aruba Networking New Central
$script:ArubaCentralBaseUrl = 'https://de1.api.central.arubanetworks.com'
$script:ArubaCentralTokenUrl = 'https://sso.common.cloud.hpe.com/as/token.oauth2'
$script:ArubaCentralInventoryApiUrl = "$script:ArubaCentralBaseUrl/network-monitoring/v1/device-inventory"
$script:ArubaCentralDevicesApiUrl = "$script:ArubaCentralBaseUrl/network-monitoring/v1/devices"

$script:PageSize = 1000
$script:RequestTimeoutSec = 60
$script:RetryCount = 3

# ---------------------------------------------------------------------------
# Application state
# ---------------------------------------------------------------------------

$script:GreenLakeInventory = @()
$script:ArubaInventory = @()
$script:ArubaMonitoredInventory = @()
$script:AuditResults = @()
$script:CentralNotMonitoredCache = $null
$script:GLUnlicensedCentralMonitoredCache = $null
$script:LicensedNotInMonitoredCache = $null
$script:CurrentView = 'Audit'
$script:CurrentViewTitle = 'All Audit Results'

$script:AuditStartTime = $null
$script:LogFile = $null
$script:Busy = $false
$script:OperationMode = $null

# Dedicated runspace state
$script:WorkerPowerShell = $null
$script:WorkerRunspace = $null
$script:WorkerAsyncResult = $null
$script:WorkerQueue = $null
$script:WorkerTimer = $null

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

function Get-ApplicationDirectory {
    if (-not [string]::IsNullOrWhiteSpace($env:ALIA_EXE_DIR)) {
        try {
            if (Test-Path -LiteralPath $env:ALIA_EXE_DIR) {
                return [System.IO.Path]::GetFullPath($env:ALIA_EXE_DIR)
            }
        } catch {}
    }

    try {
        $mainModulePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $mainModuleName = [System.IO.Path]::GetFileName($mainModulePath)
        if (-not [string]::IsNullOrWhiteSpace($mainModulePath) -and
            $mainModuleName -notmatch '^powershell(_ise)?\.exe$') {
            return [System.IO.Path]::GetDirectoryName($mainModulePath)
        }
    } catch {}

    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }

    return (Get-Location).Path
}

function Initialize-Logging {
    $baseDirectory = Get-ApplicationDirectory
    $logDirectory = Join-Path -Path $baseDirectory -ChildPath 'Logs'

    if (-not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:LogFile = Join-Path $logDirectory "ALIA_$timestamp.log"

    New-Item -ItemType File -Path $script:LogFile -Force | Out-Null
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR','DEBUG')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $line = "[$timestamp] [$Level] $Message"

    try {
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
    }
    catch {}

    try {
        if ($null -ne $script:txtLog -and -not $script:txtLog.IsDisposed) {
            $start = $script:txtLog.TextLength
            $script:txtLog.AppendText($line + [Environment]::NewLine)

            switch ($Level) {
                'SUCCESS' { $color = [System.Drawing.Color]::FromArgb(22,163,74) }
                'WARNING' { $color = [System.Drawing.Color]::FromArgb(202,138,4) }
                'ERROR'   { $color = [System.Drawing.Color]::FromArgb(220,38,38) }
                'DEBUG'   { $color = [System.Drawing.Color]::FromArgb(100,116,139) }
                default   { $color = [System.Drawing.Color]::FromArgb(51,65,85) }
            }

            $script:txtLog.Select($start, $line.Length)
            $script:txtLog.SelectionColor = $color
            $script:txtLog.Select($script:txtLog.TextLength, 0)
            $script:txtLog.ScrollToCaret()
        }
    }
    catch {}
}

# ---------------------------------------------------------------------------
# Error / status helpers
# ---------------------------------------------------------------------------

function Get-SafeErrorMessage {
    param([Parameter(Mandatory)]$ErrorObject)

    try {
        if ($null -eq $ErrorObject) {
            return 'Unknown error.'
        }

        if ($ErrorObject -is [System.Exception]) {
            return $ErrorObject.Message
        }

        $messageProperty = $ErrorObject.PSObject.Properties['Message']

        if ($null -ne $messageProperty -and
            -not [string]::IsNullOrWhiteSpace([string]$messageProperty.Value)) {
            return [string]$messageProperty.Value
        }

        return [string]$ErrorObject
    }
    catch {
        return 'An unexpected error occurred.'
    }
}

function Show-ErrorDialog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = 'ALIA Error'
    )

    [System.Windows.Forms.MessageBox]::Show(
        $script:frm,
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Set-Status {
    param(
        [Parameter(Mandatory)][string]$Text,
        [ValidateSet('Ready','Running','Success','Warning','Error')]
        [string]$State = 'Ready'
    )

    $script:lblStatus.Text = $Text

    switch ($State) {
        'Running' {
            $script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(37,99,235)
            $script:statusIndicator.ForeColor = [System.Drawing.Color]::FromArgb(37,99,235)
        }
        'Success' {
            $script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(22,163,74)
            $script:statusIndicator.ForeColor = [System.Drawing.Color]::FromArgb(22,163,74)
        }
        'Warning' {
            $script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(202,138,4)
            $script:statusIndicator.ForeColor = [System.Drawing.Color]::FromArgb(202,138,4)
        }
        'Error' {
            $script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(220,38,38)
            $script:statusIndicator.ForeColor = [System.Drawing.Color]::FromArgb(220,38,38)
        }
        default {
            $script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)
            $script:statusIndicator.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
        }
    }
}

function Update-Progress {
    param(
        [int]$Percent,
        [Parameter(Mandatory)][string]$Text
    )

    $Percent = [Math]::Max(0, [Math]::Min(100, $Percent))
    $script:progressBar.Value = $Percent
    $script:lblProgress.Text = $Text
    try { $progressTip.SetToolTip($script:lblProgress, $Text) } catch {}
    if ($null -ne $script:lblProgressPercent) {
        $script:lblProgressPercent.Text = if ($script:OperationMode -eq 'RunAudit') { "$Percent%" } else { '' }
    }
    $script:progressBar.Visible = ($script:OperationMode -eq 'RunAudit')
    $script:progressBar.Refresh()
    $progressPanel.Refresh()
}

function Set-ConnectionIndicator {
    param(
        [ValidateSet('GreenLake','ArubaCentral')]
        [string]$Platform,

        [ValidateSet('Unknown','Testing','Connected','Failed')]
        [string]$State,

        [string]$Message
    )

    if ($Platform -eq 'GreenLake') {
        $label = $script:lblGreenLakeConnection
    }
    else {
        $label = $script:lblArubaConnection
    }

    $label.Text = $Message

    switch ($State) {
        'Connected' {
            $label.ForeColor = [System.Drawing.Color]::FromArgb(22,163,74)
        }
        'Failed' {
            $label.ForeColor = [System.Drawing.Color]::FromArgb(220,38,38)
        }
        'Testing' {
            $label.ForeColor = [System.Drawing.Color]::FromArgb(37,99,235)
        }
        default {
            $label.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
        }
    }
}

function Set-BusyState {
    param([bool]$Busy)

    $script:Busy = $Busy

    $script:btnTestConnections.Enabled = -not $Busy
    $script:btnRunAudit.Enabled = -not $Busy
    $script:btnExport.Enabled = (-not $Busy) -and ($script:AuditResults.Count -gt 0)
    $script:btnClear.Enabled = -not $Busy

    $script:txtGLClientId.Enabled = -not $Busy
    $script:txtGLClientSecret.Enabled = -not $Busy
    $script:txtArubaClientId.Enabled = -not $Busy
    $script:txtArubaClientSecret.Enabled = -not $Busy

    $script:frm.Cursor = if ($Busy) {
        [System.Windows.Forms.Cursors]::WaitCursor
    }
    else {
        [System.Windows.Forms.Cursors]::Default
    }
}

# ---------------------------------------------------------------------------
# Normalization helpers - used by the GUI after worker output
# ---------------------------------------------------------------------------

function Normalize-Serial {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return ($Value.Trim().ToUpperInvariant() -replace '[^A-Z0-9]', '')
}

function Normalize-Mac {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return ($Value.Trim().ToUpperInvariant() -replace '[^A-F0-9]', '')
}

function Get-NormalizedDeviceType {
    param(
        [string]$DeviceType,
        [string]$Model,
        [string]$DeviceName
    )

    $value = "$DeviceType $Model $DeviceName".ToUpperInvariant()

    if ($value -match '\b(IAP|AP|ACCESS[ _-]?POINT|AP-[0-9])\b') {
        return 'Access Point'
    }

    if ($value -match '\b(SWITCH|CX[0-9]|2930|3810|5400|6100|6200|6300|6400|8320|8360)\b') {
        return 'Switch'
    }

    if ($value -match '\b(GATEWAY|GW|7000|9000|72XX|72[0-9]{2}|91[0-9]{2})\b') {
        return 'Gateway'
    }

    return 'Other'
}

# ---------------------------------------------------------------------------
# Centralized comparison engine
# ---------------------------------------------------------------------------


function Convert-ToBooleanString {
    param($Value)

    if ($null -eq $Value) { return '' }

    $text = ([string]$Value).Trim().ToUpperInvariant()

    switch ($text) {
        'TRUE'  { return 'Yes' }
        'YES'   { return 'Yes' }
        '1'     { return 'Yes' }
        'FALSE' { return 'No' }
        'NO'    { return 'No' }
        '0'     { return 'No' }
        default { return $text }
    }
}

function Get-CentralHealthState {
    param([string]$Status)

    if ([string]::IsNullOrWhiteSpace($Status)) { return 'Unknown' }

    $text = $Status.Trim().ToUpperInvariant()

    if ($text -match 'UP|ONLINE|CONNECTED|GOOD|OK|ACTIVE') { return 'Online' }
    if ($text -match 'DOWN|OFFLINE|DISCONNECTED|UNREACHABLE|CRITICAL|FAILED|ERROR') { return 'Offline' }

    return 'Unknown'
}

function Build-AuditResults {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$GreenLake,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ArubaInventory,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ArubaMonitored
    )

    $inventoryBySerial = @{}
    $inventoryByMac = @{}
    $monitoredBySerial = @{}
    $monitoredByMac = @{}

    foreach ($device in $ArubaInventory) {
        $serial = Normalize-Serial -Value $device.SerialNumber
        $mac = Normalize-Mac -Value $device.MACAddress

        if ($serial -and -not $inventoryBySerial.ContainsKey($serial)) {
            $inventoryBySerial[$serial] = $device
        }

        if ($mac -and -not $inventoryByMac.ContainsKey($mac)) {
            $inventoryByMac[$mac] = $device
        }
    }

    foreach ($device in $ArubaMonitored) {
        $serial = Normalize-Serial -Value $device.SerialNumber
        $mac = Normalize-Mac -Value $device.MACAddress

        if ($serial -and -not $monitoredBySerial.ContainsKey($serial)) {
            $monitoredBySerial[$serial] = $device
        }

        if ($mac -and -not $monitoredByMac.ContainsKey($mac)) {
            $monitoredByMac[$mac] = $device
        }
    }

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($gl in $GreenLake) {
        $glSerial = Normalize-Serial -Value $gl.SerialNumber
        $glMac = Normalize-Mac -Value $gl.MACAddress

        $inventoryMatch = $null
        $inventoryMatchMethod = 'Not Found'

        if ($glSerial -and $inventoryBySerial.ContainsKey($glSerial)) {
            $inventoryMatch = $inventoryBySerial[$glSerial]
            $inventoryMatchMethod = 'Serial Number'
        }
        elseif ($glMac -and $inventoryByMac.ContainsKey($glMac)) {
            $inventoryMatch = $inventoryByMac[$glMac]
            $inventoryMatchMethod = 'MAC Address'
        }

        $monitoringMatch = $null
        $monitoringMatchMethod = 'Not Found'

        if ($glSerial -and $monitoredBySerial.ContainsKey($glSerial)) {
            $monitoringMatch = $monitoredBySerial[$glSerial]
            $monitoringMatchMethod = 'Serial Number'
        }
        elseif ($glMac -and $monitoredByMac.ContainsKey($glMac)) {
            $monitoringMatch = $monitoredByMac[$glMac]
            $monitoringMatchMethod = 'MAC Address'
        }

        $inInventory = $null -ne $inventoryMatch
        $inMonitored = $null -ne $monitoringMatch

        $provisioned = if ($inventoryMatch) {
            Convert-ToBooleanString $inventoryMatch.IsProvisioned
        } else { '' }

        $status = if ($monitoringMatch) { [string]$monitoringMatch.Status } else { '' }
        $health = Get-CentralHealthState -Status $status
        $licensed = -not [string]::IsNullOrWhiteSpace([string]$gl.LicenseTier)

        if ($licensed) {
            if (-not $inInventory) {
                $auditStatus = 'LICENSED - NOT IN CENTRAL INVENTORY'
                $auditReason = 'Licensed in GreenLake but serial/MAC was not found in Aruba Central inventory.'
            }
            elseif ($provisioned -eq 'No') {
                $auditStatus = 'LICENSED - IN INVENTORY - NOT PROVISIONED'
                $auditReason = 'Device is present in Aruba Central inventory but is not provisioned.'
            }
            elseif (-not $inMonitored) {
                $auditStatus = 'LICENSED - PROVISIONED - NOT MONITORED'
                $auditReason = 'Device is provisioned in inventory but is not present in Aruba Central monitored-device list.'
            }
            elseif ($health -eq 'Offline') {
                $auditStatus = 'LICENSED - MONITORED - OFFLINE'
                $auditReason = "Device is monitored but reported status '$status'."
            }
            elseif ($health -eq 'Online') {
                $auditStatus = 'LICENSED - MONITORED - ONLINE'
                $auditReason = 'Licensed in GreenLake and actively monitored in Aruba Central.'
            }
            else {
                $auditStatus = 'LICENSED - MONITORED - STATUS UNKNOWN'
                $auditReason = 'Device is monitored, but Aruba Central returned an unrecognized or blank status.'
            }
        }
        else {
            if ($inInventory) {
                $auditStatus = 'UNLICENSED - IN CENTRAL INVENTORY'
                $auditReason = 'Device is in Aruba Central inventory but no GreenLake license tier was found.'
            }
            else {
                $auditStatus = 'UNLICENSED - NOT IN CENTRAL'
                $auditReason = 'Device has no GreenLake license and is not in Aruba Central inventory.'
            }
        }

        $results.Add([PSCustomObject]@{
            SerialNumber = [string]$gl.SerialNumber
            MACAddress = [string]$gl.MACAddress
            GreenLakeDeviceType = [string]$gl.NormalizedDeviceType
            Model = [string]$gl.Model
            PartNumber = [string]$gl.PartNumber
            DeviceName = [string]$gl.DeviceName
            Region = [string]$gl.Region
            Category = [string]$gl.Category
            Ownership = [string]$gl.Ownership
            LicenseTier = [string]$gl.LicenseTier
            LicenseStart = [string]$gl.LicenseStart
            LicenseEnd = [string]$gl.LicenseEnd
            SubscriptionCount = [int]$gl.SubscriptionCount

            ArubaInventoryPresent = if ($inInventory) { 'Yes' } else { 'No' }
            ArubaProvisioned = $provisioned
            ArubaMonitoredPresent = if ($inMonitored) { 'Yes' } else { 'No' }
            ArubaStatus = $status
            ArubaHealth = $health

            ArubaInventorySerialNumber = if ($inventoryMatch) { [string]$inventoryMatch.SerialNumber } else { '' }
            ArubaInventoryMACAddress = if ($inventoryMatch) { [string]$inventoryMatch.MACAddress } else { '' }
            ArubaInventoryDeviceType = if ($inventoryMatch) { [string]$inventoryMatch.NormalizedDeviceType } else { '' }
            ArubaInventoryDeviceName = if ($inventoryMatch) { [string]$inventoryMatch.DeviceName } else { '' }
            ArubaInventorySiteName = if ($inventoryMatch) { [string]$inventoryMatch.SiteName } else { '' }
            ArubaInventoryDeviceGroup = if ($inventoryMatch) { [string]$inventoryMatch.DeviceGroupName } else { '' }
            ArubaInventoryDeployment = if ($inventoryMatch) { [string]$inventoryMatch.Deployment } else { '' }
            ArubaInventoryFunction = if ($inventoryMatch) { [string]$inventoryMatch.DeviceFunction } else { '' }

            ArubaMonitoredSerialNumber = if ($monitoringMatch) { [string]$monitoringMatch.SerialNumber } else { '' }
            ArubaMonitoredMACAddress = if ($monitoringMatch) { [string]$monitoringMatch.MACAddress } else { '' }
            ArubaMonitoredDeviceName = if ($monitoringMatch) { [string]$monitoringMatch.DeviceName } else { '' }
            ArubaMonitoredSiteName = if ($monitoringMatch) { [string]$monitoringMatch.SiteName } else { '' }
            ArubaMonitoredFirmware = if ($monitoringMatch) { [string]$monitoringMatch.FirmwareVersion } else { '' }

            InventoryMatchMethod = $inventoryMatchMethod
            MonitoringMatchMethod = $monitoringMatchMethod

            AuditStatus = $auditStatus
            AuditReason = $auditReason
        })
    }

    return $results.ToArray()
}

# ---------------------------------------------------------------------------
# Runspace worker
# ---------------------------------------------------------------------------

$script:WorkerScript = @'
param(
    [ValidateSet("TestConnections","RunAudit")]
    [string]$Mode,

    [string]$GLTokenUrl,
    [string]$GLDeviceApiUrl,
    [string]$GLClientId,
    [string]$GLClientSecret,

    [string]$ArubaTokenUrl,
    [string]$ArubaInventoryApiUrl,
    [string]$ArubaDevicesApiUrl,
    [string]$ArubaClientId,
    [string]$ArubaClientSecret,

    [int]$PageSize,
    [int]$RequestTimeoutSec,
    [int]$RetryCount,

    [Parameter(Mandatory)]
    [System.Collections.Concurrent.ConcurrentQueue[object]]$Queue
)

$ErrorActionPreference = 'Stop'

function Write-WorkerRecord {
    param(
        [string]$Type,
        [string]$Level,
        [string]$Message,
        [int]$Percent = 0,
        [object]$Data = $null
    )

    [void]$Queue.Enqueue([PSCustomObject]@{
        RecordType = $Type
        Level      = $Level
        Message    = $Message
        Percent    = $Percent
        Data       = $Data
    })
}

function Get-SafeMessage {
    param($ErrorObject)

    try {
        if ($ErrorObject -is [System.Exception]) {
            return $ErrorObject.Message
        }

        $p = $ErrorObject.PSObject.Properties['Message']

        if ($p -and $p.Value) {
            return [string]$p.Value
        }

        return [string]$ErrorObject
    }
    catch {
        return 'Unknown error.'
    }
}

function Get-Token {
    param(
        [string]$Platform,
        [string]$TokenUrl,
        [string]$ClientId,
        [string]$ClientSecret
    )

    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        throw "$Platform Client ID is required."
    }

    if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
        throw "$Platform Client Secret is required."
    }

    Write-WorkerRecord 'Log' 'INFO' "Requesting $Platform OAuth2 access token." 0

    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
    }

    $headers = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
        'Accept' = 'application/json'
    }

    try {
        $response = Invoke-RestMethod `
            -Uri $TokenUrl `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -TimeoutSec $RequestTimeoutSec `
            -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace([string]$response.access_token)) {
            throw "$Platform did not return an access_token."
        }

        Write-WorkerRecord 'Log' 'SUCCESS' "$Platform access token generated successfully." 0

        return [string]$response.access_token
    }
    catch {
        throw "$Platform authentication failed: $($_.Exception.Message)"
    }
}

function Invoke-ApiGet {
    param(
        [string]$Platform,
        [string]$Uri,
        [hashtable]$Headers,
        [int]$Attempt = 1
    )

    $requestUri = $Uri.Trim()
    $parsed = $null

    if (-not [System.Uri]::TryCreate(
        $requestUri,
        [System.UriKind]::Absolute,
        [ref]$parsed
    )) {
        throw "Invalid $Platform API URI: [$requestUri]"
    }

    try {
        Write-WorkerRecord 'Log' 'DEBUG' "$Platform GET: $($parsed.AbsoluteUri)" 0

        return Invoke-RestMethod `
            -Uri $parsed.AbsoluteUri `
            -Method GET `
            -Headers $Headers `
            -TimeoutSec $RequestTimeoutSec `
            -ErrorAction Stop
    }
    catch {
        $message = $_.Exception.Message

        if ($Attempt -lt $RetryCount) {
            $wait = [int][Math]::Pow(2, $Attempt)

            Write-WorkerRecord 'Log' 'WARNING' `
                "$Platform API request failed (attempt $Attempt/$RetryCount). Retrying in $wait second(s). Error: $message" 0

            Start-Sleep -Seconds $wait

            return Invoke-ApiGet `
                -Platform $Platform `
                -Uri $requestUri `
                -Headers $Headers `
                -Attempt ($Attempt + 1)
        }

        throw
    }
}

function Get-PropertyValue {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return ''
    }

    $property = $Object.PSObject.Properties[$Name]

    if ($null -eq $property -or $null -eq $property.Value) {
        return ''
    }

    return [string]$property.Value
}

function Get-NormalizedType {
    param(
        [string]$DeviceType,
        [string]$Model,
        [string]$DeviceName
    )

    $value = "$DeviceType $Model $DeviceName".ToUpperInvariant()

    if ($value -match '\b(IAP|AP|ACCESS[ _-]?POINT|AP-[0-9])\b') {
        return 'Access Point'
    }

    if ($value -match '\b(SWITCH|CX[0-9]|2930|3810|5400|6100|6200|6300|6400|8320|8360)\b') {
        return 'Switch'
    }

    if ($value -match '\b(GATEWAY|GW|7000|9000|72[0-9]{2}|91[0-9]{2})\b') {
        return 'Gateway'
    }

    return 'Other'
}

function Get-GreenLakeInventory {
    param([string]$AccessToken)

    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Accept' = 'application/json'
    }

    $baseUri = $null

    if (-not [System.Uri]::TryCreate(
        $GLDeviceApiUrl.Trim(),
        [System.UriKind]::Absolute,
        [ref]$baseUri
    )) {
        throw "Invalid HPE GreenLake device API URL."
    }

    $offset = 0
    $total = 0
    $all = New-Object System.Collections.Generic.List[object]

    Write-WorkerRecord 'Log' 'INFO' "Starting HPE GreenLake inventory collection. Page size=$PageSize." 0

    do {
        $builder = [System.UriBuilder]::new($baseUri.AbsoluteUri)
        $builder.Query = "limit=$PageSize&offset=$offset"
        $uri = $builder.Uri.AbsoluteUri

        Write-WorkerRecord 'Log' 'INFO' "Requesting GreenLake devices: offset=$offset, limit=$PageSize." 0

        $response = Invoke-ApiGet `
            -Platform 'GreenLake' `
            -Uri $uri `
            -Headers $headers

        if ($null -eq $response) {
            throw "GreenLake returned an empty response at offset $offset."
        }

        $items = @($response.items)

        if ($null -ne $response.total) {
            $total = [int]$response.total
        }

        if ($items.Count -eq 0) {
            break
        }

        foreach ($device in $items) {
            $subscriptionCount = 0
            $licenseId = ''
            $licenseKey = ''
            $licenseTier = ''
            $licenseStart = ''
            $licenseEnd = ''

            if ($null -ne $device.subscription) {
                $subscriptions = @($device.subscription)
                $subscriptionCount = $subscriptions.Count

                if ($subscriptionCount -gt 0) {
                    $sub = $subscriptions[0]

                    $licenseId = Get-PropertyValue $sub 'id'
                    $licenseKey = Get-PropertyValue $sub 'key'
                    $licenseTier = Get-PropertyValue $sub 'tier'
                    $licenseStart = Get-PropertyValue $sub 'startTime'
                    $licenseEnd = Get-PropertyValue $sub 'endTime'
                }
            }

            $rawType = Get-PropertyValue $device 'deviceType'
            $model = Get-PropertyValue $device 'model'
            $deviceName = Get-PropertyValue $device 'deviceName'

            $all.Add([PSCustomObject]@{
                Platform = 'GreenLake'
                GreenLakeId = Get-PropertyValue $device 'id'
                SerialNumber = Get-PropertyValue $device 'serialNumber'
                MACAddress = Get-PropertyValue $device 'macAddress'
                DeviceType = $rawType
                NormalizedDeviceType = Get-NormalizedType $rawType $model $deviceName
                Model = $model
                PartNumber = Get-PropertyValue $device 'partNumber'
                Make = Get-PropertyValue $device 'make'
                DeviceName = $deviceName
                Region = Get-PropertyValue $device 'region'
                Category = Get-PropertyValue $device 'category'
                Ownership = Get-PropertyValue $device 'ownership'
                Source = Get-PropertyValue $device 'source'
                Archived = Get-PropertyValue $device 'archived'
                LicenseId = $licenseId
                LicenseKey = $licenseKey
                LicenseTier = $licenseTier
                LicenseStart = $licenseStart
                LicenseEnd = $licenseEnd
                SubscriptionCount = $subscriptionCount
            })
        }

        $current = $all.Count

        if ($total -gt 0) {
            $percent = 15 + [int](($current / $total) * 30)
            $percent = [Math]::Min(45, $percent)
            Write-WorkerRecord 'Progress' 'INFO' "GreenLake: retrieved $current of $total devices." $percent
        }
        else {
            Write-WorkerRecord 'Progress' 'INFO' "GreenLake: retrieved $current devices." 30
        }

        Write-WorkerRecord 'Log' 'SUCCESS' "GreenLake page retrieved: $($items.Count) device(s)." 0

        $offset += $PageSize

        if ($total -gt 0 -and $offset -ge $total) {
            break
        }

        if ($items.Count -lt $PageSize -and $total -eq 0) {
            break
        }

    } while ($true)

    if ($all.Count -eq 0) {
        throw 'HPE GreenLake returned zero devices.'
    }

    return $all.ToArray()
}


function Get-ArubaCursorInventory {
    param(
        [string]$AccessToken,
        [string]$ApiUrl,
        [string]$DatasetName,
        [int]$ProgressStart,
        [int]$ProgressEnd
    )

    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Accept' = 'application/json'
        'Content-Type' = 'application/json'
    }

    $next = ''
    $page = 0
    $all = New-Object System.Collections.Generic.List[object]

    Write-WorkerRecord 'Log' 'INFO' "Starting Aruba Central $DatasetName collection." 0

    do {
        $page++
        $builder = [System.UriBuilder]::new($ApiUrl)

        if ([string]::IsNullOrWhiteSpace($next)) {
            $builder.Query = "limit=$PageSize"
        }
        else {
            $builder.Query = "limit=$PageSize&next=$([System.Uri]::EscapeDataString($next))"
        }

        $uri = $builder.Uri.AbsoluteUri

        Write-WorkerRecord 'Log' 'INFO' "Requesting Aruba Central $DatasetName page $page." 0

        $response = Invoke-ApiGet `
            -Platform 'Aruba Central' `
            -Uri $uri `
            -Headers $headers

        if ($null -eq $response) {
            throw "Aruba Central returned an empty $DatasetName response."
        }

        $items = @($response.items)

        if ($items.Count -eq 0) {
            Write-WorkerRecord 'Log' 'WARNING' "No devices returned on Aruba Central $DatasetName page $page." 0
            break
        }

        foreach ($device in $items) {
            $rawType = Get-PropertyValue $device 'deviceType'
            $model = Get-PropertyValue $device 'model'
            $deviceName = Get-PropertyValue $device 'deviceName'

            $all.Add([PSCustomObject]@{
                Platform = 'Aruba Central'
                Dataset = $DatasetName
                SerialNumber = Get-PropertyValue $device 'serialNumber'
                MACAddress = Get-PropertyValue $device 'macAddress'
                DeviceType = $rawType
                NormalizedDeviceType = Get-NormalizedType $rawType $model $deviceName
                Model = $model
                PartNumber = Get-PropertyValue $device 'partNumber'
                Make = Get-PropertyValue $device 'make'
                DeviceName = $deviceName
                SiteId = Get-PropertyValue $device 'siteId'
                SiteName = Get-PropertyValue $device 'siteName'
                Status = Get-PropertyValue $device 'status'
                FirmwareVersion = Get-PropertyValue $device 'firmwareVersion'
                IsProvisioned = Get-PropertyValue $device 'isProvisioned'
                DeviceGroupName = Get-PropertyValue $device 'deviceGroupName'
                DeviceFunction = Get-PropertyValue $device 'deviceFunction'
                Deployment = Get-PropertyValue $device 'deployment'
                DeviceIp = Get-PropertyValue $device 'ipv4'
                ClusterName = Get-PropertyValue $device 'clusterName'
            })
        }

        $current = $all.Count
        $reportedTotal = 0
        if ($null -ne $response.total) {
            try { $reportedTotal = [int]$response.total } catch { $reportedTotal = 0 }
        }

        if ($reportedTotal -gt 0) {
            $percent = $ProgressStart + [int](($current / $reportedTotal) * ($ProgressEnd - $ProgressStart))
        }
        else {
            $percent = [Math]::Min($ProgressEnd, $ProgressStart + ($page * 3))
        }

        Write-WorkerRecord 'Progress' 'INFO' "Aruba Central ${DatasetName}: retrieved $current device(s)." $percent
        Write-WorkerRecord 'Log' 'SUCCESS' "Aruba Central $DatasetName page $page retrieved: $($items.Count) device(s)." 0

        $next = Get-PropertyValue $response 'next'
        if ([string]::IsNullOrWhiteSpace($next)) { break }

    } while ($true)

    Write-WorkerRecord 'Log' 'SUCCESS' "Aruba Central $DatasetName collection complete. Total devices=$($all.Count)." 0
    return $all.ToArray()
}

function Get-ArubaCentralInventory {
    param([string]$AccessToken)

    return Get-ArubaCursorInventory `
        -AccessToken $AccessToken `
        -ApiUrl $ArubaInventoryApiUrl `
        -DatasetName 'inventory' `
        -ProgressStart 45 `
        -ProgressEnd 62
}

function Get-ArubaCentralMonitoredDevices {
    param([string]$AccessToken)

    return Get-ArubaCursorInventory `
        -AccessToken $AccessToken `
        -ApiUrl $ArubaDevicesApiUrl `
        -DatasetName 'monitored devices' `
        -ProgressStart 62 `
        -ProgressEnd 78
}

function Test-ApiAccess {
    param(
        [string]$Platform,
        [string]$Uri,
        [hashtable]$Headers
    )

    $response = Invoke-ApiGet `
        -Platform $Platform `
        -Uri $Uri `
        -Headers $Headers `
        -Attempt 1

    if ($null -eq $response) {
        throw "$Platform API returned an empty response."
    }

    return $true
}

function Test-Connections {
    $result = [ordered]@{
        GreenLake = [ordered]@{
            Success = $false
            Message = ''
        }
        ArubaCentral = [ordered]@{
            Success = $false
            Message = ''
        }
    }

    try {
        Write-WorkerRecord 'Log' 'INFO' 'Testing HPE GreenLake connection...' 0

        $glToken = Get-Token `
            -Platform 'HPE GreenLake' `
            -TokenUrl $GLTokenUrl `
            -ClientId $GLClientId `
            -ClientSecret $GLClientSecret

        $glHeaders = @{
            'Authorization' = "Bearer $glToken"
            'Accept' = 'application/json'
        }

        $glBuilder = [System.UriBuilder]::new($GLDeviceApiUrl)
        $glBuilder.Query = 'limit=1&offset=0'

        Test-ApiAccess `
            -Platform 'GreenLake' `
            -Uri $glBuilder.Uri.AbsoluteUri `
            -Headers $glHeaders | Out-Null

        $result.GreenLake.Success = $true
        $result.GreenLake.Message = 'Connected'
        Write-WorkerRecord 'Log' 'SUCCESS' 'HPE GreenLake authentication and API access successful.' 0
    }
    catch {
        $result.GreenLake.Message = Get-SafeMessage $_
        Write-WorkerRecord 'Log' 'ERROR' "HPE GreenLake connection failed: $($result.GreenLake.Message)" 0
    }

    try {
        Write-WorkerRecord 'Log' 'INFO' 'Testing Aruba Central connection...' 0

        $arubaToken = Get-Token `
            -Platform 'Aruba Central' `
            -TokenUrl $ArubaTokenUrl `
            -ClientId $ArubaClientId `
            -ClientSecret $ArubaClientSecret

        $arubaHeaders = @{
            'Authorization' = "Bearer $arubaToken"
            'Accept' = 'application/json'
            'Content-Type' = 'application/json'
        }

        $invBuilder = [System.UriBuilder]::new($ArubaInventoryApiUrl)
        $invBuilder.Query = 'limit=1'

        Test-ApiAccess `
            -Platform 'Aruba Central Inventory' `
            -Uri $invBuilder.Uri.AbsoluteUri `
            -Headers $arubaHeaders | Out-Null

        $monBuilder = [System.UriBuilder]::new($ArubaDevicesApiUrl)
        $monBuilder.Query = 'limit=1'

        Test-ApiAccess `
            -Platform 'Aruba Central Monitored Devices' `
            -Uri $monBuilder.Uri.AbsoluteUri `
            -Headers $arubaHeaders | Out-Null

        $result.ArubaCentral.Success = $true
        $result.ArubaCentral.Message = 'Connected - both APIs accessible'
        Write-WorkerRecord 'Log' 'SUCCESS' 'Aruba Central authentication, inventory API and monitored-device API access successful.' 0
    }
    catch {
        $result.ArubaCentral.Message = Get-SafeMessage $_
        Write-WorkerRecord 'Log' 'ERROR' "Aruba Central connection failed: $($result.ArubaCentral.Message)" 0
    }

    Write-WorkerRecord 'Result' 'SUCCESS' 'Connection test completed.' 0 $result
}

try {
    if ($Mode -eq 'TestConnections') {
        Test-Connections
        return
    }

    if ($Mode -eq 'RunAudit') {
        if ([string]::IsNullOrWhiteSpace($GLClientId) -or
            [string]::IsNullOrWhiteSpace($GLClientSecret) -or
            [string]::IsNullOrWhiteSpace($ArubaClientId) -or
            [string]::IsNullOrWhiteSpace($ArubaClientSecret)) {
            throw 'Both HPE GreenLake and Aruba Central Client ID/Client Secret pairs are required.'
        }

        Write-WorkerRecord 'Progress' 'INFO' 'Starting license audit...' 0

        Write-WorkerRecord 'Log' 'INFO' 'Authenticating to HPE GreenLake...' 0
        $glToken = Get-Token `
            -Platform 'HPE GreenLake' `
            -TokenUrl $GLTokenUrl `
            -ClientId $GLClientId `
            -ClientSecret $GLClientSecret

        Write-WorkerRecord 'Progress' 'INFO' 'HPE GreenLake authentication successful.' 10

        Write-WorkerRecord 'Log' 'INFO' 'Authenticating to Aruba Central...' 0
        $arubaToken = Get-Token `
            -Platform 'Aruba Central' `
            -TokenUrl $ArubaTokenUrl `
            -ClientId $ArubaClientId `
            -ClientSecret $ArubaClientSecret

        Write-WorkerRecord 'Progress' 'INFO' 'Aruba Central authentication successful.' 15

        $greenLake = Get-GreenLakeInventory -AccessToken $glToken
        Write-WorkerRecord 'Progress' 'INFO' "HPE GreenLake inventory complete: $($greenLake.Count) devices." 45
        Write-WorkerRecord 'Log' 'SUCCESS' "GreenLake inventory returned to the audit workflow: $($greenLake.Count) normalized device(s)." 0

        Write-WorkerRecord 'Log' 'INFO' 'Starting Aruba Central inventory retrieval...' 0
        $arubaInventory = Get-ArubaCentralInventory -AccessToken $arubaToken
        Write-WorkerRecord 'Progress' 'INFO' "Aruba Central inventory complete: $($arubaInventory.Count) devices." 62

        Write-WorkerRecord 'Log' 'INFO' 'Starting Aruba Central monitored-device retrieval...' 0
        $arubaMonitored = Get-ArubaCentralMonitoredDevices -AccessToken $arubaToken
        Write-WorkerRecord 'Progress' 'INFO' "Aruba Central monitored devices complete: $($arubaMonitored.Count) devices." 78

        Write-WorkerRecord 'Log' 'INFO' 'Device inventories collected. Returning normalized data to GUI for reconciliation.' 0
        Write-WorkerRecord 'Log' 'DEBUG' "Result packaging: GreenLake=$($greenLake.Count); ArubaInventory=$($arubaInventory.Count); ArubaMonitored=$($arubaMonitored.Count)." 0

        Write-WorkerRecord 'Result' 'SUCCESS' 'Audit inventory collection completed.' 92 @{
            GreenLake = @($greenLake)
            ArubaInventory = @($arubaInventory)
            ArubaMonitored = @($arubaMonitored)
        }

        Write-WorkerRecord 'Progress' 'SUCCESS' 'Inventory collection completed. Building audit results...' 92
    }
}
catch {
    Write-WorkerRecord 'Result' 'ERROR' (Get-SafeMessage $_) 0 $null
}
'@

function Start-OperationRunspace {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('TestConnections','RunAudit')]
        [string]$Mode,

        [string]$GLClientId,
        [string]$GLClientSecret,
        [string]$ArubaClientId,
        [string]$ArubaClientSecret
    )

    if ($script:WorkerPowerShell -or $script:WorkerRunspace) {
        throw 'An operation is already running.'
    }

    $script:WorkerQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
    $script:WorkerFinalResult = $null
    $script:OperationMode = $Mode

    $script:WorkerRunspace = [RunspaceFactory]::CreateRunspace()
    $script:WorkerRunspace.ApartmentState = [System.Threading.ApartmentState]::MTA
    $script:WorkerRunspace.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $script:WorkerRunspace.Open()

    $script:WorkerPowerShell = [PowerShell]::Create()
    $script:WorkerPowerShell.Runspace = $script:WorkerRunspace

    [void]$script:WorkerPowerShell.AddScript($script:WorkerScript)

    [void]$script:WorkerPowerShell.AddArgument($Mode)

    [void]$script:WorkerPowerShell.AddArgument($script:GreenLakeTokenUrl)
    [void]$script:WorkerPowerShell.AddArgument($script:GreenLakeDeviceApiUrl)
    [void]$script:WorkerPowerShell.AddArgument($GLClientId)
    [void]$script:WorkerPowerShell.AddArgument($GLClientSecret)

    [void]$script:WorkerPowerShell.AddArgument($script:ArubaCentralTokenUrl)
    [void]$script:WorkerPowerShell.AddArgument($script:ArubaCentralInventoryApiUrl)
    [void]$script:WorkerPowerShell.AddArgument($script:ArubaCentralDevicesApiUrl)
    [void]$script:WorkerPowerShell.AddArgument($ArubaClientId)
    [void]$script:WorkerPowerShell.AddArgument($ArubaClientSecret)

    [void]$script:WorkerPowerShell.AddArgument($script:PageSize)
    [void]$script:WorkerPowerShell.AddArgument($script:RequestTimeoutSec)
    [void]$script:WorkerPowerShell.AddArgument($script:RetryCount)
    [void]$script:WorkerPowerShell.AddArgument($script:WorkerQueue)

    $script:WorkerAsyncResult = $script:WorkerPowerShell.BeginInvoke()
}

function Stop-OperationRunspace {
    try {
        if ($script:WorkerPowerShell) {
            try { $script:WorkerPowerShell.Stop() } catch {}
            try { $script:WorkerPowerShell.Dispose() } catch {}
        }

        if ($script:WorkerRunspace) {
            try { $script:WorkerRunspace.Close() } catch {}
            try { $script:WorkerRunspace.Dispose() } catch {}
        }
    }
    catch {}

    $script:WorkerPowerShell = $null
    $script:WorkerRunspace = $null
    $script:WorkerAsyncResult = $null
    $script:WorkerQueue = $null
    $script:WorkerFinalResult = $null
    $script:OperationMode = $null
}

function Apply-ConnectionResult {
    param([hashtable]$Result)

    $glSuccess = [bool]$Result.GreenLake.Success
    $arubaSuccess = [bool]$Result.ArubaCentral.Success

    if ($glSuccess) {
        Set-ConnectionIndicator -Platform GreenLake -State Connected -Message 'Connected'
    }
    else {
        Set-ConnectionIndicator -Platform GreenLake -State Failed -Message 'Failed'
    }

    if ($arubaSuccess) {
        Set-ConnectionIndicator -Platform ArubaCentral -State Connected -Message 'Connected'
    }
    else {
        Set-ConnectionIndicator -Platform ArubaCentral -State Failed -Message 'Failed'
    }

    if ($glSuccess -and $arubaSuccess) {
        Set-Status 'Both platforms connected successfully.' 'Success'
        $overall = 'SUCCESS'
    }
    elseif ($glSuccess -or $arubaSuccess) {
        Set-Status 'Connection test completed with partial success.' 'Warning'
        $overall = 'PARTIAL FAILURE'
    }
    else {
        Set-Status 'Both platform connection tests failed.' 'Error'
        $overall = 'FAILURE'
    }

    $message = @(
        'Connection Test Result'
        '======================'
        ''
        "HPE GreenLake     : $(if ($glSuccess) { 'CONNECTED' } else { 'FAILED' })"
        $(if (-not $glSuccess) { "Reason: $($Result.GreenLake.Message)" } else { '' })
        ''
        "Aruba Central     : $(if ($arubaSuccess) { 'CONNECTED' } else { 'FAILED' })"
        $(if (-not $arubaSuccess) { "Reason: $($Result.ArubaCentral.Message)" } else { '' })
        ''
        "Overall Result    : $overall"
    ) -join [Environment]::NewLine

    $messageIcon = [System.Windows.Forms.MessageBoxIcon]::Error

    if ($glSuccess -and $arubaSuccess) {
        $messageIcon = [System.Windows.Forms.MessageBoxIcon]::Information
    }
    elseif ($glSuccess -or $arubaSuccess) {
        $messageIcon = [System.Windows.Forms.MessageBoxIcon]::Warning
    }

    [System.Windows.Forms.MessageBox]::Show(
        $script:frm,
        $message,
        'Connection Test Result',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $messageIcon
    ) | Out-Null
}

# ---------------------------------------------------------------------------
# View / grid helpers
# ---------------------------------------------------------------------------

function New-DataTableFromObjects {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items,
        [Parameter(Mandatory)][string[]]$Properties
    )

    $table = New-Object System.Data.DataTable

    foreach ($property in $Properties) {
        $null = $table.Columns.Add($property)
    }

    foreach ($item in $Items) {
        $row = $table.NewRow()

        foreach ($property in $Properties) {
            $value = $item.PSObject.Properties[$property]

            if ($null -eq $value -or $null -eq $value.Value) {
                $row[$property] = ''
            }
            else {
                $row[$property] = [string]$value.Value
            }
        }

        $null = $table.Rows.Add($row)
    }

    # Return the DataTable as a single object. PowerShell 5.1 can otherwise
    # enumerate DataTable rows when a function returns it.
    return ,$table
}

function Get-CentralInventoryNotMonitored {
    if ($null -ne $script:CentralNotMonitoredCache) {
        return @($script:CentralNotMonitoredCache)
    }

    $monitoredBySerial = @{}
    $monitoredByMac = @{}

    foreach ($device in @($script:ArubaMonitoredInventory)) {
        $serial = Normalize-Serial -Value $device.SerialNumber
        $mac = Normalize-Mac -Value $device.MACAddress

        if ($serial -and -not $monitoredBySerial.ContainsKey($serial)) {
            $monitoredBySerial[$serial] = $device
        }

        if ($mac -and -not $monitoredByMac.ContainsKey($mac)) {
            $monitoredByMac[$mac] = $device
        }
    }

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($device in @($script:ArubaInventory)) {
        $serial = Normalize-Serial -Value $device.SerialNumber
        $mac = Normalize-Mac -Value $device.MACAddress
        $monitoredMatch = $false

        if ($serial -and $monitoredBySerial.ContainsKey($serial)) {
            $monitoredMatch = $true
        }
        elseif ($mac -and $monitoredByMac.ContainsKey($mac)) {
            $monitoredMatch = $true
        }

        if (-not $monitoredMatch) {
            $results.Add($device)
        }
    }

    return $results.ToArray()
}

function Get-GLUnlicensedCentralMonitored {
    # Returns Aruba Central monitored devices that do not have a matching
    # licensed device in HPE GreenLake. Matching is Serial first, MAC second.
    # The result is cached after the audit so repeated tile clicks are instant.
    if ($null -ne $script:GLUnlicensedCentralMonitoredCache) {
        return @($script:GLUnlicensedCentralMonitoredCache)
    }

    $licensedBySerial = @{}
    $licensedByMac = @{}
    $greenLakeBySerial = @{}
    $greenLakeByMac = @{}

    foreach ($device in @($script:AuditResults)) {
        $serial = Normalize-Serial -Value $device.SerialNumber
        $mac = Normalize-Mac -Value $device.MACAddress

        if ($serial -and -not $greenLakeBySerial.ContainsKey($serial)) {
            $greenLakeBySerial[$serial] = $device
        }

        if ($mac -and -not $greenLakeByMac.ContainsKey($mac)) {
            $greenLakeByMac[$mac] = $device
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$device.LicenseTier)) {
            if ($serial -and -not $licensedBySerial.ContainsKey($serial)) {
                $licensedBySerial[$serial] = $device
            }

            if ($mac -and -not $licensedByMac.ContainsKey($mac)) {
                $licensedByMac[$mac] = $device
            }
        }
    }

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($device in @($script:ArubaMonitoredInventory)) {
        $serial = Normalize-Serial -Value $device.SerialNumber
        $mac = Normalize-Mac -Value $device.MACAddress
        $licensedMatch = $false
        $greenLakeState = 'Not Found in GreenLake'

        if ($serial -and $licensedBySerial.ContainsKey($serial)) {
            $licensedMatch = $true
            $greenLakeState = 'Licensed'
        }
        elseif ($mac -and $licensedByMac.ContainsKey($mac)) {
            $licensedMatch = $true
            $greenLakeState = 'Licensed'
        }
        elseif (($serial -and $greenLakeBySerial.ContainsKey($serial)) -or
                ($mac -and $greenLakeByMac.ContainsKey($mac))) {
            $greenLakeState = 'Unlicensed in GreenLake'
        }

        if (-not $licensedMatch) {
            $results.Add([PSCustomObject]@{
                SerialNumber = $device.SerialNumber
                MACAddress = $device.MACAddress
                NormalizedDeviceType = $device.NormalizedDeviceType
                Model = $device.Model
                DeviceName = $device.DeviceName
                SiteName = $device.SiteName
                Status = $device.Status
                FirmwareVersion = $device.FirmwareVersion
                DeviceGroupName = $device.DeviceGroupName
                DeviceFunction = $device.DeviceFunction
                Deployment = $device.Deployment
                DeviceIp = $device.DeviceIp
                ClusterName = $device.ClusterName
                GreenLakeLicenseStatus = $greenLakeState
            })
        }
    }

    return $results.ToArray()
}

function Get-ViewObjects {
    param([string]$View)

    switch ($View) {
        'GreenLake' { return @($script:GreenLakeInventory) }
        'ArubaInventory' { return @($script:ArubaInventory) }
        'CentralNotMonitored' { return @(Get-CentralInventoryNotMonitored) }
        'GLUnlicensedCentralMonitored' { return @(Get-GLUnlicensedCentralMonitored) }
        'ArubaMonitored' { return @($script:ArubaMonitoredInventory) }
        'Licensed' { return @($script:AuditResults | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LicenseTier) }) }
        'Unlicensed' { return @($script:AuditResults | Where-Object { [string]::IsNullOrWhiteSpace($_.LicenseTier) }) }
        'NotInInventory' { return @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - NOT IN CENTRAL INVENTORY' }) }
        'NotProvisioned' { return @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - IN INVENTORY - NOT PROVISIONED' }) }
        'NotMonitored' { return @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - PROVISIONED - NOT MONITORED' }) }
        'LicensedNotInMonitored' {
            if ($null -ne $script:LicensedNotInMonitoredCache) {
                return @($script:LicensedNotInMonitoredCache)
            }
            return @($script:AuditResults | Where-Object {
                (-not [string]::IsNullOrWhiteSpace([string]$_.LicenseTier)) -and
                ([string]$_.ArubaMonitoredPresent -eq 'No')
            })
        }
        'LicensedOnline' { return @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - MONITORED - ONLINE' }) }
        'LicensedOffline' { return @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - MONITORED - OFFLINE' }) }
        'AccessPoint' { return @($script:AuditResults | Where-Object { $_.GreenLakeDeviceType -eq 'Access Point' }) }
        'Switch' { return @($script:AuditResults | Where-Object { $_.GreenLakeDeviceType -eq 'Switch' }) }
        'Gateway' { return @($script:AuditResults | Where-Object { $_.GreenLakeDeviceType -eq 'Gateway' }) }
        'Expired' {
            return @($script:AuditResults | Where-Object {
                if ([string]::IsNullOrWhiteSpace($_.LicenseEnd)) { return $false }
                try { ([datetime]$_.LicenseEnd) -lt (Get-Date) } catch { return $false }
            })
        }
        default { return @($script:AuditResults) }
    }
}

function Get-ViewProperties {
    param(
        [Parameter(Mandatory)]
        [string]$View
    )

    switch ($View) {
        'GreenLake' {
            return @(
                'SerialNumber','MACAddress','NormalizedDeviceType','Model','PartNumber',
                'DeviceName','Region','Category','Ownership','LicenseTier',
                'LicenseStart','LicenseEnd','SubscriptionCount'
            )
        }

        'ArubaInventory' {
            return @(
                'SerialNumber','MACAddress','NormalizedDeviceType','Model',
                'DeviceName','SiteName','IsProvisioned','DeviceGroupName',
                'DeviceFunction','Deployment','DeviceIp','ClusterName'
            )
        }

        'CentralNotMonitored' {
            return @(
                'SerialNumber','MACAddress','NormalizedDeviceType','Model',
                'DeviceName','SiteName','IsProvisioned','DeviceGroupName',
                'DeviceFunction','Deployment','DeviceIp','ClusterName'
            )
        }

        'GLUnlicensedCentralMonitored' {
            return @(
                'SerialNumber','MACAddress','NormalizedDeviceType','Model',
                'DeviceName','SiteName','Status','FirmwareVersion',
                'GreenLakeLicenseStatus','DeviceGroupName','DeviceFunction',
                'Deployment','DeviceIp','ClusterName'
            )
        }

        'ArubaMonitored' {
            return @(
                'SerialNumber','MACAddress','NormalizedDeviceType','Model',
                'DeviceName','SiteName','Status','FirmwareVersion',
                'DeviceGroupName','DeviceFunction','Deployment','DeviceIp','ClusterName'
            )
        }

        default {
            return @(
                'SerialNumber','MACAddress','GreenLakeDeviceType','Model','DeviceName',
                'LicenseTier','LicenseStart','LicenseEnd',
                'ArubaInventoryPresent','ArubaProvisioned','ArubaMonitoredPresent',
                'ArubaStatus','ArubaHealth',
                'ArubaInventoryDeviceName','ArubaInventorySiteName',
                'ArubaMonitoredDeviceName','ArubaMonitoredSiteName',
                'InventoryMatchMethod','MonitoringMatchMethod',
                'AuditStatus','AuditReason'
            )
        }
    }
}

function Show-View {
    param(
        [Parameter(Mandatory)][string]$View,
        [string]$Title
    )

    if ($script:SearchTimer) {
        $script:SearchTimer.Stop()
    }

    if ($script:txtSearch -and $script:txtSearch.Text.Trim().Length -gt 0) {
        $script:txtSearch.Text = ''
    }

    $script:CurrentView = $View
    $script:CurrentViewTitle = if ($Title) { $Title } else { $View }
    if ($script:lblViewTitle) {
        $script:lblViewTitle.Text = $script:CurrentViewTitle
    }
    try { Position-ViewHeader } catch {}

    if ($View -eq 'Issues') {
        $objects = @($script:AuditResults | Where-Object { (Get-AuditHealth -Status ([string]$_.AuditStatus) -LicenseEnd ([string]$_.LicenseEnd)) -ne 'Healthy' })
    }
    else {
        $objects = @(Get-ViewObjects -View $View)
    }

    $properties = @(Get-ViewProperties -View $View)
    if ($View -eq 'Issues') {
        $properties = @(
            'SerialNumber','MACAddress','GreenLakeDeviceType','Model','DeviceName',
            'LicenseTier','LicenseEnd','ArubaInventoryPresent','ArubaProvisioned',
            'ArubaMonitoredPresent','ArubaStatus','ArubaHealth','AuditStatus','AuditReason'
        )
    }

    $table = New-DataTableFromObjects -Items $objects -Properties $properties

    $script:grid.SuspendLayout()
    try {
        $script:grid.DataSource = $null
        $script:grid.Columns.Clear()
        $script:grid.AutoGenerateColumns = $true
        $script:grid.DataSource = $table

        foreach ($column in $script:grid.Columns) {
            $column.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::Automatic
        }

        if ($script:grid.Columns.Contains('SerialNumber')) {
            $script:grid.Columns['SerialNumber'].Frozen = $true
        }
        if ($script:grid.Columns.Contains('MACAddress')) {
            $script:grid.Columns['MACAddress'].Frozen = $true
        }

        foreach ($row in $script:grid.Rows) {
            if ($script:grid.Columns.Contains('AuditStatus')) {
                $licenseEndValue = if ($script:grid.Columns.Contains('LicenseEnd')) {
                    [string]$row.Cells['LicenseEnd'].Value
                } else { '' }
                $health = Get-AuditHealth -Status ([string]$row.Cells['AuditStatus'].Value) -LicenseEnd $licenseEndValue
                switch ($health) {
                    'Critical' { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(254,242,242) }
                    'Warning'  { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(255,251,235) }
                    default    { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::White }
                }
            }
        }
    }
    finally {
        $script:grid.ResumeLayout()
    }

    if ($script:lblRecordCount) {
        $script:lblRecordCount.Text = "Records: $($objects.Count)"
    }
    if ($script:lblViewBadge) {
        $script:lblViewBadge.Text = if ($objects.Count -gt 0) { $script:CurrentViewTitle } else { 'No matching records' }
    }

    Write-AuditLog DEBUG "View '$script:CurrentViewTitle' loaded with $($objects.Count) record(s)."
    try { Update-DetailPanelFromSelection } catch {}
}

# ---------------------------------------------------------------------------
# Dashboard# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

function New-DashboardTile {
    param(
        [string]$Caption,
        [string]$View,
        [System.Drawing.Color]$Accent,
        [System.Windows.Forms.FlowLayoutPanel]$Parent
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.BackColor = [System.Drawing.Color]::White
    $panel.BorderStyle = 'FixedSingle'
    $panel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $panel.Tag = $View

    $panel.Size = [System.Drawing.Size]::new(235, 68)
    $panel.Margin = [System.Windows.Forms.Padding]::new(0, 2, 8, 2)

    $accentPanel = New-Object System.Windows.Forms.Panel
    $accentPanel.Dock = 'Left'
    $accentPanel.Width = 5
    $accentPanel.BackColor = $Accent
    $accentPanel.Cursor = $panel.Cursor
    $accentPanel.Tag = $View
    [void]$panel.Controls.Add($accentPanel)

    $captionLabel = New-Object System.Windows.Forms.Label
    $captionLabel.Text = $Caption
    $captionLabel.AutoSize = $false
    $captionLabel.Height = 22
    $captionLabel.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
    $captionLabel.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
    $captionLabel.Location = [System.Drawing.Point]::new(16, 7)
    $captionLabel.Anchor = 'Top,Left,Right'
    $captionLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $captionLabel.AutoEllipsis = $true
    $captionLabel.Cursor = $panel.Cursor
    $captionLabel.Tag = $View
    [void]$panel.Controls.Add($captionLabel)

    $valueLabel = New-Object System.Windows.Forms.Label
    $valueLabel.Text = '0'
    $valueLabel.AutoSize = $true
    $valueLabel.Font = $fontMetric
    $valueLabel.ForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
    $valueLabel.Location = [System.Drawing.Point]::new(16, 30)
    $valueLabel.Anchor = 'Top,Left'
    $valueLabel.Cursor = $panel.Cursor
    $valueLabel.Tag = $View
    [void]$panel.Controls.Add($valueLabel)

    $subLabel = New-Object System.Windows.Forms.Label
    $subLabel.Text = ''
    $subLabel.AutoSize = $false
    $subLabel.Height = 18
    $subLabel.Anchor = 'Left,Bottom,Right'
    $subLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $subLabel.Font = [System.Drawing.Font]::new('Segoe UI', 7.5)
    $subLabel.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
    $subLabel.Location = [System.Drawing.Point]::new(10, 53)
    $subLabel.Size = [System.Drawing.Size]::new(215, 12)
    $subLabel.Cursor = $panel.Cursor
    $subLabel.Tag = $View
    [void]$panel.Controls.Add($subLabel)

    $click = {
        param($sender, $eventArgs)
        $selectedView = [string]$sender.Tag

        $titleMap = @{
            GreenLake = 'HPE GreenLake Inventory'
            ArubaInventory = 'Aruba Central Inventory'
            CentralNotMonitored = 'Aruba Central Inventory - Not Monitored Devices'
            GLUnlicensedCentralMonitored = 'GL Unlicensed - Monitored'
            ArubaMonitored = 'Aruba Central Monitored Devices'
            Licensed = 'GreenLake Licensed Devices'
            Unlicensed = 'GreenLake Devices Without License'
            NotProvisioned = 'Licensed Devices Not Provisioned'
            LicensedNotInMonitored = 'Licensed Devices Not in Aruba Central Monitored List'
            AccessPoint = 'Access Point Audit Results'
            Switch = 'Switch Audit Results'
            Gateway = 'Gateway Audit Results'
            Expired = 'Expired License Results'
        }

        Show-View -View $selectedView -Title $titleMap[$selectedView]
    }

    $panel.add_Click($click)
    $accentPanel.add_Click($click)
    $captionLabel.add_Click($click)
    $valueLabel.add_Click($click)
    $subLabel.add_Click($click)

    $panel.Add_MouseEnter({
        param($sender, $eventArgs)
        $sender.BackColor = [System.Drawing.Color]::FromArgb(248,250,252)
    })

    $panel.Add_MouseLeave({
        param($sender, $eventArgs)
        $sender.BackColor = [System.Drawing.Color]::White
    })

    [void]$Parent.Controls.Add($panel)

    return [PSCustomObject]@{
        Panel = $panel
        CaptionLabel = $captionLabel
        ValueLabel = $valueLabel
        SubLabel = $subLabel
    }
}

function Get-AuditHealth {
    param(
        [string]$Status,
        [string]$LicenseEnd
    )

    if (-not [string]::IsNullOrWhiteSpace($LicenseEnd)) {
        try {
            if ([datetime]$LicenseEnd -lt (Get-Date)) {
                return 'Critical'
            }
        } catch {}
    }

    if ([string]::IsNullOrWhiteSpace($Status)) { return 'Healthy' }

    switch -Regex ($Status) {
        'LICENSED - NOT IN CENTRAL INVENTORY' { return 'Critical' }
        'LICENSED - MONITORED - OFFLINE'      { return 'Critical' }
        'EXPIRED'                             { return 'Critical' }
        'LICENSED - IN INVENTORY - NOT PROVISIONED' { return 'Warning' }
        'LICENSED - PROVISIONED - NOT MONITORED'   { return 'Warning' }
        'LICENSED - MONITORED - STATUS UNKNOWN'    { return 'Warning' }
        'UNLICENSED - IN CENTRAL INVENTORY'         { return 'Warning' }
        default { return 'Healthy' }
    }
}

function Get-AuditIssueCount {
    return @($script:AuditResults | Where-Object {
        (Get-AuditHealth -Status ([string]$_.AuditStatus) -LicenseEnd ([string]$_.LicenseEnd)) -ne 'Healthy'
    }).Count
}

function Get-AuditCoveragePercent {
    if ($script:GreenLakeInventory.Count -eq 0) { return 0 }
    $matched = @($script:AuditResults | Where-Object { [string]$_.ArubaInventoryPresent -eq 'Yes' }).Count
    return [Math]::Round(($matched / [double]$script:GreenLakeInventory.Count) * 100, 2)
}

function Update-KpiTrend {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Label]$Label,
        [Parameter(Mandatory)][int]$Current,
        [Parameter(Mandatory)][string]$Metric
    )

    $history = @(Get-AuditHistory)
    if ($history.Count -lt 1) {
        $Label.Text = ''
        return
    }

    $comparisonRecord = if ($history.Count -gt 1) { $history[1] } else { $history[0] }
    $previous = $comparisonRecord.PSObject.Properties[$Metric]
    if ($null -eq $previous) {
        $Label.Text = ''
        return
    }

    $old = [int]$previous.Value
    $delta = $Current - $old

    if ($delta -eq 0) {
        $Label.Text = 'No change'
        $Label.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
    }
    elseif ($delta -gt 0) {
        $Label.Text = "▲ +$delta vs last audit"
        $Label.ForeColor = [System.Drawing.Color]::FromArgb(220,38,38)
    }
    else {
        $Label.Text = "▼ $([Math]::Abs($delta)) vs last audit"
        $Label.ForeColor = [System.Drawing.Color]::FromArgb(22,163,74)
    }
}

function Update-Dashboard {
    $glCount = $script:GreenLakeInventory.Count
    $centralCount = $script:ArubaInventory.Count
    $monitoredCount = $script:ArubaMonitoredInventory.Count
    $licensedCount = @($script:AuditResults | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LicenseTier) }).Count
    $unlicensedCount = @($script:AuditResults | Where-Object { [string]::IsNullOrWhiteSpace($_.LicenseTier) }).Count
    $expiredCount = @(Get-ViewObjects -View 'Expired').Count
    $notProvisionedCount = @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - IN INVENTORY - NOT PROVISIONED' }).Count
    $notMonitoredCount = @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - PROVISIONED - NOT MONITORED' }).Count
    $offlineCount = @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - MONITORED - OFFLINE' }).Count
    $issueCount = Get-AuditIssueCount
    $coverage = Get-AuditCoveragePercent

    $healthyCount = @($script:AuditResults | Where-Object { (Get-AuditHealth -Status ([string]$_.AuditStatus)) -eq 'Healthy' }).Count
    $warningCount = @($script:AuditResults | Where-Object { (Get-AuditHealth -Status ([string]$_.AuditStatus)) -eq 'Warning' }).Count
    $criticalCount = @($script:AuditResults | Where-Object { (Get-AuditHealth -Status ([string]$_.AuditStatus)) -eq 'Critical' }).Count

    $glAp = @($script:GreenLakeInventory | Where-Object { $_.NormalizedDeviceType -eq 'Access Point' }).Count
    $glSwitch = @($script:GreenLakeInventory | Where-Object { $_.NormalizedDeviceType -eq 'Switch' }).Count
    $glGateway = @($script:GreenLakeInventory | Where-Object { $_.NormalizedDeviceType -eq 'Gateway' }).Count

    if ($script:kpiGL) { $script:kpiGL.Value.Text = [string]$glCount }
    if ($script:kpiCentral) { $script:kpiCentral.Value.Text = [string]$centralCount }
    if ($script:kpiMonitored) { $script:kpiMonitored.Value.Text = [string]$monitoredCount }
    if ($script:kpiLicensed) { $script:kpiLicensed.Value.Text = [string]$licensedCount }
    if ($script:kpiIssues) { $script:kpiIssues.Value.Text = [string]$issueCount }
    if ($script:kpiExpired) { $script:kpiExpired.Value.Text = [string]$expiredCount }

    if ($script:healthHealthy) { $script:healthHealthy.Text = [string]$healthyCount }
    if ($script:healthWarning) { $script:healthWarning.Text = [string]$warningCount }
    if ($script:healthCritical) { $script:healthCritical.Text = [string]$criticalCount }
    if ($script:healthCoverage) { $script:healthCoverage.Text = "$coverage%" }
    if ($script:healthAP) { $script:healthAP.Text = [string]$glAp }
    if ($script:healthSwitch) { $script:healthSwitch.Text = [string]$glSwitch }
    if ($script:healthGateway) { $script:healthGateway.Text = [string]$glGateway }

    if ($script:healthHeadline) {
        if ($criticalCount -gt 0) {
            $script:healthHeadline.Text = 'ATTENTION REQUIRED'
            $script:healthHeadline.ForeColor = [System.Drawing.Color]::FromArgb(185,28,28)
        }
        elseif ($warningCount -gt 0) {
            $script:healthHeadline.Text = 'REVIEW RECOMMENDED'
            $script:healthHeadline.ForeColor = [System.Drawing.Color]::FromArgb(161,98,7)
        }
        else {
            $script:healthHeadline.Text = 'AUDIT HEALTHY'
            $script:healthHeadline.ForeColor = [System.Drawing.Color]::FromArgb(21,128,61)
        }
    }

    if ($script:healthDetail) {
        $script:healthDetail.Text = "$issueCount exception(s) | Coverage $coverage% | Offline $offlineCount | Not monitored $notMonitoredCount"
    }

    if ($script:kpiIssues -and $script:kpiIssues.Trend) { Update-KpiTrend -Label $script:kpiIssues.Trend -Current $issueCount -Metric 'IssueCount' }
    if ($script:kpiExpired -and $script:kpiExpired.Trend) { Update-KpiTrend -Label $script:kpiExpired.Trend -Current $expiredCount -Metric 'ExpiredCount' }
    if ($script:kpiLicensed -and $script:kpiLicensed.Trend) { Update-KpiTrend -Label $script:kpiLicensed.Trend -Current $licensedCount -Metric 'LicensedCount' }
}

# ---------------------------------------------------------------------------
# v3.1 GUI layout - Audit Workspace
# ---------------------------------------------------------------------------

Initialize-Logging
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppVersion = 'v3.1.0'

$fontRegular = [System.Drawing.Font]::new('Segoe UI', 10)
$fontSmall = [System.Drawing.Font]::new('Segoe UI', 9)
$fontTitle = [System.Drawing.Font]::new('Segoe UI Semibold', 20)
$fontSection = [System.Drawing.Font]::new('Segoe UI Semibold', 11)

$script:frm = New-Object System.Windows.Forms.Form
$script:frm.Text = "$script:AppName - $script:AppVersion"
$script:frm.StartPosition = 'CenterScreen'
$script:frm.BackColor = [System.Drawing.Color]::FromArgb(241,245,249)
$script:frm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$script:frm.AutoScaleDimensions = [System.Drawing.SizeF]::new(96,96)
$script:frm.Font = $fontRegular
$script:frm.KeyPreview = $true

$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$targetWidth = [Math]::Min(1600, [Math]::Max(1200, $workArea.Width - 60))
$targetHeight = [Math]::Min(980, [Math]::Max(720, $workArea.Height - 70))
$script:frm.MinimumSize = [System.Drawing.Size]::new(1100, 650)
$script:frm.ClientSize = [System.Drawing.Size]::new($targetWidth, $targetHeight)

$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = 'Fill'
$root.Margin = [System.Windows.Forms.Padding]::Empty
$root.Padding = [System.Windows.Forms.Padding]::Empty
$root.ColumnCount = 1
$root.RowCount = 6
$root.BackColor = [System.Drawing.Color]::FromArgb(241,245,249)
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 78))
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 112))
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 160))
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 54))
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 34))
[void]$root.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))

$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Fill'
$header.BackColor = [System.Drawing.Color]::FromArgb(15,23,42)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'ALIA'
$title.ForeColor = [System.Drawing.Color]::White
$title.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 21)
$title.AutoSize = $true
$title.Location = [System.Drawing.Point]::new(24, 7)
[void]$header.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Aruba License Inventory Audit  |  GreenLake + Aruba Central reconciliation'
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(148,163,184)
$subtitle.Font = [System.Drawing.Font]::new('Segoe UI', 10)
$subtitle.AutoSize = $true
$subtitle.Location = [System.Drawing.Point]::new(26, 43)
[void]$header.Controls.Add($subtitle)

$headerStatus = New-Object System.Windows.Forms.Label
$headerStatus.Text = '● Ready'
$headerStatus.ForeColor = [System.Drawing.Color]::FromArgb(45,212,191)
$headerStatus.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 9.5)
$headerStatus.AutoSize = $true
$headerStatus.Anchor = 'Top,Right'
[void]$header.Controls.Add($headerStatus)

$version = New-Object System.Windows.Forms.Label
$version.Text = $script:AppVersion
$version.ForeColor = [System.Drawing.Color]::FromArgb(148,163,184)
$version.AutoSize = $true
$version.Anchor = 'Top,Right'
[void]$header.Controls.Add($version)

$script:btnHistory = New-Object System.Windows.Forms.Button
$script:btnHistory.Text = 'Audit History'
$script:btnHistory.Size = [System.Drawing.Size]::new(108, 28)
$script:btnHistory.FlatStyle = 'Flat'
$script:btnHistory.FlatAppearance.BorderSize = 1
$script:btnHistory.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(71,85,105)
$script:btnHistory.BackColor = [System.Drawing.Color]::FromArgb(30,41,59)
$script:btnHistory.ForeColor = [System.Drawing.Color]::White
$script:btnHistory.Font = [System.Drawing.Font]::new('Segoe UI', 8.8)
$script:btnHistory.Cursor = [System.Windows.Forms.Cursors]::Hand
$script:btnHistory.Anchor = 'Top,Right'
[void]$header.Controls.Add($script:btnHistory)

function Position-Header {
    try {
        $version.Left = $header.ClientSize.Width - $version.Width - 18
        $version.Top = 12
        $headerStatus.Left = $version.Left - $headerStatus.Width - 18
        $headerStatus.Top = 12
        $script:btnHistory.Left = $headerStatus.Left - $script:btnHistory.Width - 14
        $script:btnHistory.Top = 8
    } catch {}
}
$header.Add_Resize({ Position-Header })

$connectionPanel = New-Object System.Windows.Forms.TableLayoutPanel
$connectionPanel.Dock = 'Fill'
$connectionPanel.Padding = [System.Windows.Forms.Padding]::new(14, 7, 14, 7)
$connectionPanel.ColumnCount = 3
$connectionPanel.RowCount = 1
[void]$connectionPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 37))
[void]$connectionPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 37))
[void]$connectionPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 26))

function New-CredentialCardV31 {
    param(
        [Parameter(Mandatory)][string]$TitleText,
        [Parameter(Mandatory)][string]$EndpointText
    )

    $group = New-Object System.Windows.Forms.Panel
    $group.Dock = 'Fill'
    $group.Margin = [System.Windows.Forms.Padding]::new(3, 0, 6, 0)
    $group.Padding = [System.Windows.Forms.Padding]::new(10, 5, 10, 5)
    $group.BackColor = [System.Drawing.Color]::White
    $group.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.ColumnCount = 3
    $layout.RowCount = 3
    $layout.BackColor = [System.Drawing.Color]::White
    [void]$layout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 90))
    [void]$layout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))
    [void]$layout.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 48))
    [void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 24))
    [void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 29))
    [void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 29))

    $headerRow = New-Object System.Windows.Forms.Panel
    $headerRow.Dock = 'Fill'
    $name = New-Object System.Windows.Forms.Label
    $name.Text = $TitleText
    $name.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 10.2)
    $name.ForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
    $name.Dock = 'Left'
    $name.AutoSize = $true

    $status = New-Object System.Windows.Forms.Label
    $status.Text = '○ Not tested'
    $status.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
    $status.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 8.8)
    $status.Dock = 'Right'
    $status.AutoSize = $true

    [void]$headerRow.Controls.Add($name)
    [void]$headerRow.Controls.Add($status)
    [void]$layout.Controls.Add($headerRow, 0, 0)
    $layout.SetColumnSpan($headerRow, 3)

    $idLabel = New-Object System.Windows.Forms.Label
    $idLabel.Text = 'Client ID'
    $idLabel.Dock = 'Fill'
    $idLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $idLabel.ForeColor = [System.Drawing.Color]::FromArgb(71,85,105)

    $idBox = New-Object System.Windows.Forms.TextBox
    $idBox.Dock = 'Fill'
    $idBox.Margin = [System.Windows.Forms.Padding]::new(0,1,4,1)
    $idBox.Font = [System.Drawing.Font]::new('Segoe UI', 10)

    $idPad = New-Object System.Windows.Forms.Label
    $idPad.Text = ''
    [void]$layout.Controls.Add($idLabel, 0, 1)
    [void]$layout.Controls.Add($idBox, 1, 1)
    [void]$layout.Controls.Add($idPad, 2, 1)

    $secretLabel = New-Object System.Windows.Forms.Label
    $secretLabel.Text = 'Secret'
    $secretLabel.Dock = 'Fill'
    $secretLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $secretLabel.ForeColor = [System.Drawing.Color]::FromArgb(71,85,105)

    $secretBox = New-Object System.Windows.Forms.TextBox
    $secretBox.Dock = 'Fill'
    $secretBox.Margin = [System.Windows.Forms.Padding]::new(0,1,4,1)
    $secretBox.Font = [System.Drawing.Font]::new('Segoe UI', 10)
    $secretBox.UseSystemPasswordChar = $true

    $show = New-Object System.Windows.Forms.Button
    $show.Text = 'Show'
    $show.Dock = 'Fill'
    $show.Margin = [System.Windows.Forms.Padding]::new(0,1,0,1)
    $show.FlatStyle = 'Flat'
    $show.FlatAppearance.BorderSize = 1
    $show.BackColor = [System.Drawing.Color]::FromArgb(248,250,252)
    $show.Font = [System.Drawing.Font]::new('Segoe UI', 8)
    $show.Tag = $secretBox

    $show.Add_Click({
        param($sender)
        $box = $sender.Tag
        $box.UseSystemPasswordChar = -not $box.UseSystemPasswordChar
        $sender.Text = if ($box.UseSystemPasswordChar) { 'Show' } else { 'Hide' }
    })

    [void]$layout.Controls.Add($secretLabel, 0, 2)
    [void]$layout.Controls.Add($secretBox, 1, 2)
    [void]$layout.Controls.Add($show, 2, 2)

    [void]$group.Controls.Add($layout)
    $tip = New-Object System.Windows.Forms.ToolTip
    $tip.SetToolTip($group, $EndpointText)

    return [PSCustomObject]@{
        Group = $group
        ClientId = $idBox
        ClientSecret = $secretBox
        Status = $status
    }
}

$glCard = New-CredentialCardV31 -TitleText 'HPE GreenLake' -EndpointText 'GreenLake device inventory endpoint is configured internally'
$arubaCard = New-CredentialCardV31 -TitleText 'Aruba Central' -EndpointText 'Central inventory and monitored-device endpoints are configured internally'

$script:txtGLClientId = $glCard.ClientId
$script:txtGLClientSecret = $glCard.ClientSecret
$script:lblGreenLakeConnection = $glCard.Status
$script:txtArubaClientId = $arubaCard.ClientId
$script:txtArubaClientSecret = $arubaCard.ClientSecret
$script:lblArubaConnection = $arubaCard.Status

$actions = New-Object System.Windows.Forms.Panel
$actions.Dock = 'Fill'
$actions.Padding = [System.Windows.Forms.Padding]::new(6, 3, 3, 3)

$runPanel = New-Object System.Windows.Forms.Panel
$runPanel.Dock = 'Top'
$runPanel.Height = 55
$runPanel.BackColor = [System.Drawing.Color]::FromArgb(15,118,110)

$script:btnRunAudit = New-Object System.Windows.Forms.Button
$script:btnRunAudit.Text = 'RUN LICENSE AUDIT'
$script:btnRunAudit.Dock = 'Fill'
$script:btnRunAudit.FlatStyle = 'Flat'
$script:btnRunAudit.FlatAppearance.BorderSize = 0
$script:btnRunAudit.BackColor = [System.Drawing.Color]::FromArgb(15,118,110)
$script:btnRunAudit.ForeColor = [System.Drawing.Color]::White
$script:btnRunAudit.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 11)
$script:btnRunAudit.Cursor = [System.Windows.Forms.Cursors]::Hand
[void]$runPanel.Controls.Add($script:btnRunAudit)
[void]$actions.Controls.Add($runPanel)

$runHint = New-Object System.Windows.Forms.Label
$runHint.Text = 'Collect inventory, licensing and monitoring state'
$runHint.Dock = 'Top'
$runHint.Height = 25
$runHint.ForeColor = [System.Drawing.Color]::FromArgb(71,85,105)
$runHint.Font = [System.Drawing.Font]::new('Segoe UI', 7.8)
$runHint.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
[void]$actions.Controls.Add($runHint)

$secondary = New-Object System.Windows.Forms.FlowLayoutPanel
$secondary.Dock = 'Fill'
$secondary.FlowDirection = 'LeftToRight'
$secondary.WrapContents = $false
$secondary.Padding = [System.Windows.Forms.Padding]::new(0, 5, 0, 0)

function New-SecondaryButton {
    param([string]$Text,[int]$Width,[System.Drawing.Color]$Color)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Width = $Width
    $b.Height = 28
    $b.Margin = [System.Windows.Forms.Padding]::new(2,0,4,0)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 1
    $b.BackColor = $Color
    $b.ForeColor = if ($Color.R + $Color.G + $Color.B -gt 560) { [System.Drawing.Color]::FromArgb(15,23,42) } else { [System.Drawing.Color]::White }
    $b.Font = [System.Drawing.Font]::new('Segoe UI', 8)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $b
}

$script:btnTestConnections = New-SecondaryButton 'Test Connections' 106 ([System.Drawing.Color]::FromArgb(37,99,235))
$script:btnExport = New-SecondaryButton 'Export' 65 ([System.Drawing.Color]::FromArgb(22,163,74))
$script:btnClear = New-SecondaryButton 'Clear' 55 ([System.Drawing.Color]::FromArgb(71,85,105))
$script:btnExport.Enabled = $false
[void]$secondary.Controls.Add($script:btnTestConnections)
[void]$secondary.Controls.Add($script:btnExport)
[void]$secondary.Controls.Add($script:btnClear)
[void]$actions.Controls.Add($secondary)

[void]$connectionPanel.Controls.Add($glCard.Group, 0, 0)
[void]$connectionPanel.Controls.Add($arubaCard.Group, 1, 0)
[void]$connectionPanel.Controls.Add($actions, 2, 0)

$overview = New-Object System.Windows.Forms.TableLayoutPanel
$overview.Dock = 'Fill'
$overview.Padding = [System.Windows.Forms.Padding]::new(14, 5, 14, 5)
$overview.ColumnCount = 2
$overview.RowCount = 1
[void]$overview.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute, 310))
[void]$overview.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))

$healthCard = New-Object System.Windows.Forms.Panel
$healthCard.Dock = 'Fill'
$healthCard.BackColor = [System.Drawing.Color]::White
$healthCard.BorderStyle = 'FixedSingle'
$healthCard.Padding = [System.Windows.Forms.Padding]::new(14,7,14,7)

$healthTitle = New-Object System.Windows.Forms.Label
$healthTitle.Text = 'AUDIT HEALTH'
$healthTitle.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 8.5)
$healthTitle.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
$healthTitle.Dock = 'Top'
$healthTitle.Height = 18

$script:healthHeadline = New-Object System.Windows.Forms.Label
$script:healthHeadline.Text = 'READY TO AUDIT'
$script:healthHeadline.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 16)
$script:healthHeadline.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)
$script:healthHeadline.Dock = 'Top'
$script:healthHeadline.Height = 29

$script:healthDetail = New-Object System.Windows.Forms.Label
$script:healthDetail.Text = 'No audit results yet'
$script:healthDetail.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
$script:healthDetail.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
$script:healthDetail.Dock = 'Top'
$script:healthDetail.Height = 30

$healthStats = New-Object System.Windows.Forms.TableLayoutPanel
$healthStats.Dock = 'Fill'
$healthStats.ColumnCount = 4
$healthStats.RowCount = 2
for($i=0;$i -lt 4;$i++){ [void]$healthStats.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,25)) }
[void]$healthStats.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 20))
[void]$healthStats.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))

function New-MetricLabel {
    param([string]$Text,[System.Drawing.Color]$Color,[int]$Size = 8)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Font = [System.Drawing.Font]::new('Segoe UI Semibold', $Size)
    $l.ForeColor = $Color
    $l.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $l.Dock = 'Fill'
    return $l
}

$healthyLabel = New-MetricLabel 'Healthy' ([System.Drawing.Color]::FromArgb(100,116,139))
$warningLabel = New-MetricLabel 'Warning' ([System.Drawing.Color]::FromArgb(100,116,139))
$criticalLabel = New-MetricLabel 'Critical' ([System.Drawing.Color]::FromArgb(100,116,139))
$coverageLabel = New-MetricLabel 'Coverage' ([System.Drawing.Color]::FromArgb(100,116,139))

$script:healthHealthy = New-MetricLabel '0' ([System.Drawing.Color]::FromArgb(22,163,74)) 13
$script:healthWarning = New-MetricLabel '0' ([System.Drawing.Color]::FromArgb(202,138,4)) 13
$script:healthCritical = New-MetricLabel '0' ([System.Drawing.Color]::FromArgb(220,38,38)) 13
$script:healthCoverage = New-MetricLabel '0%' ([System.Drawing.Color]::FromArgb(37,99,235)) 13

foreach($item in @(
    @($healthyLabel,$script:healthHealthy,0),
    @($warningLabel,$script:healthWarning,1),
    @($criticalLabel,$script:healthCritical,2),
    @($coverageLabel,$script:healthCoverage,3)
)){
    [void]$healthStats.Controls.Add($item[0],$item[2],0)
    [void]$healthStats.Controls.Add($item[1],$item[2],1)
}

[void]$healthCard.Controls.Add($healthStats)
[void]$healthCard.Controls.Add($script:healthDetail)
[void]$healthCard.Controls.Add($script:healthHeadline)
[void]$healthCard.Controls.Add($healthTitle)

$kpiPanel = New-Object System.Windows.Forms.TableLayoutPanel
$kpiPanel.Dock = 'Fill'
$kpiPanel.ColumnCount = 3
$kpiPanel.RowCount = 2
for($i=0;$i -lt 3;$i++){ [void]$kpiPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,33.333)) }
for($i=0;$i -lt 2;$i++){ [void]$kpiPanel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,50)) }

function New-KpiCard {
    param([string]$Caption,[System.Drawing.Color]$Accent)
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = 'Fill'
    $p.Margin = [System.Windows.Forms.Padding]::new(4,0,0,4)
    $p.Padding = [System.Windows.Forms.Padding]::new(10,4,10,3)
    $p.BackColor = [System.Drawing.Color]::White
    $p.BorderStyle = 'FixedSingle'

    $cap = New-Object System.Windows.Forms.Label
    $cap.Text = $Caption
    $cap.Font = [System.Drawing.Font]::new('Segoe UI', 8.2)
    $cap.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
    $cap.Dock = 'Top'
    $cap.Height = 17

    $val = New-Object System.Windows.Forms.Label
    $val.Text = '0'
    $val.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 18)
    $val.ForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
    $val.Dock = 'Top'
    $val.Height = 25

    $trend = New-Object System.Windows.Forms.Label
    $trend.Text = ''
    $trend.Font = [System.Drawing.Font]::new('Segoe UI', 7.4)
    $trend.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
    $trend.Dock = 'Fill'
    $trend.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

    $accentBar = New-Object System.Windows.Forms.Panel
    $accentBar.Dock = 'Left'
    $accentBar.Width = 4
    $accentBar.BackColor = $Accent

    [void]$p.Controls.Add($trend)
    [void]$p.Controls.Add($val)
    [void]$p.Controls.Add($cap)
    [void]$p.Controls.Add($accentBar)

    return [PSCustomObject]@{ Panel=$p; Caption=$cap; Value=$val; Trend=$trend }
}

$script:kpiGL = New-KpiCard 'GreenLake Inventory' ([System.Drawing.Color]::FromArgb(37,99,235))
$script:kpiCentral = New-KpiCard 'Central Inventory' ([System.Drawing.Color]::FromArgb(124,58,237))
$script:kpiMonitored = New-KpiCard 'Central Monitored' ([System.Drawing.Color]::FromArgb(14,116,144))
$script:kpiLicensed = New-KpiCard 'Licensed Devices' ([System.Drawing.Color]::FromArgb(22,163,74))
$script:kpiIssues = New-KpiCard 'Exceptions' ([System.Drawing.Color]::FromArgb(220,38,38))
$script:kpiExpired = New-KpiCard 'Expired Licenses' ([System.Drawing.Color]::FromArgb(202,138,4))

[void]$kpiPanel.Controls.Add($script:kpiGL.Panel,0,0)
[void]$kpiPanel.Controls.Add($script:kpiCentral.Panel,1,0)
[void]$kpiPanel.Controls.Add($script:kpiMonitored.Panel,2,0)
[void]$kpiPanel.Controls.Add($script:kpiLicensed.Panel,0,1)
[void]$kpiPanel.Controls.Add($script:kpiIssues.Panel,1,1)
[void]$kpiPanel.Controls.Add($script:kpiExpired.Panel,2,1)

[void]$overview.Controls.Add($healthCard,0,0)
[void]$overview.Controls.Add($kpiPanel,1,0)

$toolbar = New-Object System.Windows.Forms.Panel
$toolbar.Dock = 'Fill'
$toolbar.Padding = [System.Windows.Forms.Padding]::new(14,3,14,3)
$toolbar.BackColor = [System.Drawing.Color]::FromArgb(241,245,249)

function New-QuickViewButton {
    param([string]$Text,[string]$Tag)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Tag = $Tag
    $b.Width = 82
    $b.Height = 28
    $b.Margin = [System.Windows.Forms.Padding]::new(0,0,4,0)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 1
    $b.BackColor = [System.Drawing.Color]::White
    $b.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)
    $b.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 7.8)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $b
}

$quickPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$quickPanel.Dock = 'Left'
$quickPanel.Width = 485
$quickPanel.WrapContents = $false
$quickPanel.FlowDirection = 'LeftToRight'

$titleMap = @{
    Audit='All Audit Results'
    Issues='Exceptions Requiring Review'
    Licensed='GreenLake Licensed Devices'
    Unlicensed='GreenLake Devices Without License'
    NotMonitored='Licensed Devices Not in Central Monitoring'
    GreenLake='HPE GreenLake Inventory'
}

foreach($qb in @(
    (New-QuickViewButton 'All' 'Audit'),
    (New-QuickViewButton 'Issues' 'Issues'),
    (New-QuickViewButton 'Licensed' 'Licensed'),
    (New-QuickViewButton 'Unlicensed' 'Unlicensed'),
    (New-QuickViewButton 'Not Monitored' 'NotMonitored'),
    (New-QuickViewButton 'Inventory' 'GreenLake')
)){
    $qb.Add_Click({
        param($sender)
        $script:SearchTimer.Stop()
        $script:CurrentFilterDeviceType = 'All'
        $script:CurrentFilterHealth = 'All'
        $script:CurrentFilterLicense = 'All'
        $script:CurrentFilterStatus = 'All'
        $script:chkProblemsOnly.Checked = ($sender.Tag -eq 'Issues')
        Show-View -View ([string]$sender.Tag) -Title $titleMap[[string]$sender.Tag]
        Invoke-CurrentSearch
    })
    [void]$quickPanel.Controls.Add($qb)
}
[void]$toolbar.Controls.Add($quickPanel)

$script:txtSearch = New-Object System.Windows.Forms.TextBox
$script:txtSearch.Font = [System.Drawing.Font]::new('Segoe UI', 8.8)
$script:txtSearch.Width = 190
$script:txtSearch.Height = 28
$script:txtSearch.Text = ''
$script:txtSearch.Anchor = 'Top,Right'
$searchTip = New-Object System.Windows.Forms.ToolTip
$searchTip.SetToolTip($script:txtSearch, 'Search serial, MAC, model, device name or site')
[void]$toolbar.Controls.Add($script:txtSearch)

$script:cmbLicense = New-Object System.Windows.Forms.ComboBox
$script:cmbLicense.DropDownStyle = 'DropDownList'
[void]$script:cmbLicense.Items.AddRange(@('All','Licensed','Unlicensed','Expired'))
$script:cmbLicense.SelectedIndex = 0
$script:cmbLicense.Width = 85
$script:cmbLicense.Height = 28
$script:cmbLicense.Anchor = 'Top,Right'
[void]$toolbar.Controls.Add($script:cmbLicense)

$script:cmbHealth = New-Object System.Windows.Forms.ComboBox
$script:cmbHealth.DropDownStyle = 'DropDownList'
[void]$script:cmbHealth.Items.AddRange(@('All','Healthy','Warning','Critical'))
$script:cmbHealth.SelectedIndex = 0
$script:cmbHealth.Width = 78
$script:cmbHealth.Height = 28
$script:cmbHealth.Anchor = 'Top,Right'
[void]$toolbar.Controls.Add($script:cmbHealth)

$script:cmbDeviceType = New-Object System.Windows.Forms.ComboBox
$script:cmbDeviceType.DropDownStyle = 'DropDownList'
[void]$script:cmbDeviceType.Items.AddRange(@('All','Access Point','Switch','Gateway','Other'))
$script:cmbDeviceType.SelectedIndex = 0
$script:cmbDeviceType.Width = 100
$script:cmbDeviceType.Height = 28
$script:cmbDeviceType.Anchor = 'Top,Right'
[void]$toolbar.Controls.Add($script:cmbDeviceType)

$script:chkProblemsOnly = New-Object System.Windows.Forms.CheckBox
$script:chkProblemsOnly.Text = 'Problems only'
$script:chkProblemsOnly.AutoSize = $true
$script:chkProblemsOnly.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
$script:chkProblemsOnly.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)
$script:chkProblemsOnly.Anchor = 'Top,Right'
[void]$toolbar.Controls.Add($script:chkProblemsOnly)

$script:btnResetFilters = New-Object System.Windows.Forms.Button
$script:btnResetFilters.Text = 'Reset'
$script:btnResetFilters.Width = 55
$script:btnResetFilters.Height = 28
$script:btnResetFilters.FlatStyle = 'Flat'
$script:btnResetFilters.FlatAppearance.BorderSize = 1
$script:btnResetFilters.BackColor = [System.Drawing.Color]::White
$script:btnResetFilters.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)
$script:btnResetFilters.Font = [System.Drawing.Font]::new('Segoe UI', 8)
$script:btnResetFilters.Anchor = 'Top,Right'
[void]$toolbar.Controls.Add($script:btnResetFilters)

function Position-Toolbar {
    try {
        $right = $toolbar.ClientSize.Width - 14
        $script:btnResetFilters.Left = $right - $script:btnResetFilters.Width
        $script:chkProblemsOnly.Left = $script:btnResetFilters.Left - $script:chkProblemsOnly.Width - 8
        $script:cmbDeviceType.Left = $script:chkProblemsOnly.Left - $script:cmbDeviceType.Width - 8
        $script:cmbHealth.Left = $script:cmbDeviceType.Left - $script:cmbHealth.Width - 8
        $script:cmbLicense.Left = $script:cmbHealth.Left - $script:cmbLicense.Width - 8
        $script:txtSearch.Left = $script:cmbLicense.Left - $script:txtSearch.Width - 8
        $script:txtSearch.Top = 1
        $script:cmbLicense.Top = 1
        $script:cmbHealth.Top = 1
        $script:cmbDeviceType.Top = 1
        $script:chkProblemsOnly.Top = 6
        $script:btnResetFilters.Top = 1
    } catch {}
}
$toolbar.Add_Resize({ Position-Toolbar })

$workspaceHost = New-Object System.Windows.Forms.TableLayoutPanel
$workspaceHost.Dock = 'Fill'
$workspaceHost.RowCount = 2
[void]$workspaceHost.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute,34))
[void]$workspaceHost.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
[void]$workspaceHost.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))

$resultsHeader = New-Object System.Windows.Forms.Panel
$resultsHeader.Dock = 'Fill'

$script:lblViewTitle = New-Object System.Windows.Forms.Label
$script:lblViewTitle.Text = 'All Audit Results'
$script:lblViewTitle.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 11.5)
$script:lblViewTitle.AutoSize = $true
$script:lblViewTitle.Location = [System.Drawing.Point]::new(0,4)
$script:lblViewTitle.ForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
[void]$resultsHeader.Controls.Add($script:lblViewTitle)

$script:lblRecordCount = New-Object System.Windows.Forms.Label
$script:lblRecordCount.Text = 'Records: 0'
$script:lblRecordCount.AutoSize = $true
$script:lblRecordCount.Location = [System.Drawing.Point]::new(0,6)
$script:lblRecordCount.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
[void]$resultsHeader.Controls.Add($script:lblRecordCount)

$script:lblViewBadge = New-Object System.Windows.Forms.Label
$script:lblViewBadge.Text = 'All Audit Results'
$script:lblViewBadge.Font = [System.Drawing.Font]::new('Segoe UI', 8)
$script:lblViewBadge.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
$script:lblViewBadge.Anchor = 'Top,Right'
[void]$resultsHeader.Controls.Add($script:lblViewBadge)

function Position-ViewHeader {
    try {
        $script:lblRecordCount.Left = $script:lblViewTitle.Right + 12
        $script:lblViewBadge.Left = [Math]::Max(0,$resultsHeader.ClientSize.Width-$script:lblViewBadge.Width-4)
        $script:lblViewBadge.Top = 7
    } catch {}
}
$resultsHeader.Add_Resize({ Position-ViewHeader })

$workspace = New-Object System.Windows.Forms.SplitContainer
$workspace.Dock = 'Fill'
$workspace.Orientation = [System.Windows.Forms.Orientation]::Vertical
$workspace.Panel1MinSize = 650
$workspace.Panel2MinSize = 300
$workspace.SplitterDistance = 900
$workspace.BackColor = [System.Drawing.Color]::FromArgb(226,232,240)

$gridGroup = New-Object System.Windows.Forms.GroupBox
$gridGroup.Text = ' Audit Results '
$gridGroup.Font = $fontSection
$gridGroup.Dock = 'Fill'
$gridGroup.BackColor = [System.Drawing.Color]::White
$gridGroup.Padding = [System.Windows.Forms.Padding]::new(3,5,3,3)

$script:grid = New-Object System.Windows.Forms.DataGridView
$script:grid.Dock = 'Fill'
$script:grid.ReadOnly = $true
$script:grid.AllowUserToAddRows = $false
$script:grid.AllowUserToDeleteRows = $false
$script:grid.AllowUserToResizeRows = $false
$script:grid.RowHeadersVisible = $false
$script:grid.MultiSelect = $false
$script:grid.SelectionMode = 'FullRowSelect'
$script:grid.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditProgrammatically
$script:grid.StandardTab = $true
$script:grid.AutoGenerateColumns = $true
$script:grid.AutoSizeColumnsMode = 'DisplayedCells'
$script:grid.EnableHeadersVisualStyles = $false
$script:grid.BackgroundColor = [System.Drawing.Color]::White
$script:grid.BorderStyle = 'None'
$script:grid.GridColor = [System.Drawing.Color]::FromArgb(226,232,240)
$script:grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(15,23,42)
$script:grid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$script:grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8.8)
$script:grid.ColumnHeadersHeight = 30
$script:grid.DefaultCellStyle.Font = $fontSmall
$script:grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(219,234,254)
$script:grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
$script:grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(248,250,252)
$script:grid.RowTemplate.Height = 27
[void]$gridGroup.Controls.Add($script:grid)
[void]$workspace.Panel1.Controls.Add($gridGroup)

$detailGroup = New-Object System.Windows.Forms.GroupBox
$detailGroup.Text = ' Device Details '
$detailGroup.Font = $fontSection
$detailGroup.Dock = 'Fill'
$detailGroup.BackColor = [System.Drawing.Color]::White
$detailGroup.Padding = [System.Windows.Forms.Padding]::new(10,8,10,8)

$detailPanel = New-Object System.Windows.Forms.Panel
$detailPanel.Dock = 'Fill'
$detailPanel.AutoScroll = $true

$script:detailTitle = New-Object System.Windows.Forms.Label
$script:detailTitle.Text = 'Select a device'
$script:detailTitle.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 15)
$script:detailTitle.ForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
$script:detailTitle.Location = [System.Drawing.Point]::new(6,6)
$script:detailTitle.Size = [System.Drawing.Size]::new(320,32)

$script:detailStatus = New-Object System.Windows.Forms.Label
$script:detailStatus.Text = ''
$script:detailStatus.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 8.8)
$script:detailStatus.Location = [System.Drawing.Point]::new(6,38)
$script:detailStatus.Size = [System.Drawing.Size]::new(320,22)

$script:detailBody = New-Object System.Windows.Forms.RichTextBox
$script:detailBody.ReadOnly = $true
$script:detailBody.BorderStyle = 'None'
$script:detailBody.BackColor = [System.Drawing.Color]::White
$script:detailBody.Font = [System.Drawing.Font]::new('Segoe UI', 9)
$script:detailBody.Location = [System.Drawing.Point]::new(6,64)
$script:detailBody.Size = [System.Drawing.Size]::new(350,420)
$script:detailBody.Text = 'Select a row to inspect GreenLake, Aruba Central, monitoring and audit state.'
$script:detailBody.Anchor = 'Top,Left,Right'
[void]$detailPanel.Controls.Add($script:detailBody)
[void]$detailPanel.Controls.Add($script:detailStatus)
[void]$detailPanel.Controls.Add($script:detailTitle)
[void]$detailGroup.Controls.Add($detailPanel)
[void]$workspace.Panel2.Controls.Add($detailGroup)

function Update-DetailPanelFromSelection {
    if ($null -eq $script:grid -or $null -eq $script:grid.CurrentRow) {
        return
    }

    $row = $script:grid.CurrentRow
    function V([string]$name) {
        if ($script:grid.Columns.Contains($name)) {
            return [string]$row.Cells[$name].Value
        }
        return ''
    }

    $device = V 'DeviceName'
    $serial = V 'SerialNumber'
    $mac = V 'MACAddress'
    $model = V 'Model'
    $site = V 'SiteName'
    if ([string]::IsNullOrWhiteSpace($site)) { $site = V 'ArubaInventorySiteName' }
    if ([string]::IsNullOrWhiteSpace($site)) { $site = V 'ArubaMonitoredSiteName' }

    $status = V 'AuditStatus'
    if ([string]::IsNullOrWhiteSpace($status)) { $status = V 'Status' }

    $license = V 'LicenseTier'
    $licenseEnd = V 'LicenseEnd'
    $central = V 'ArubaInventoryPresent'
    $provisioned = V 'ArubaProvisioned'
    $monitored = V 'ArubaMonitoredPresent'
    $centralStatus = V 'ArubaStatus'
    $health = V 'ArubaHealth'
    $reason = V 'AuditReason'

    $script:detailTitle.Text = if (-not [string]::IsNullOrWhiteSpace($device)) { $device } elseif ($serial) { $serial } else { 'Device Details' }
    $healthState = Get-AuditHealth -Status $status -LicenseEnd $licenseEnd
    $script:detailStatus.ForeColor = switch ($healthState) {
        'Critical' { [System.Drawing.Color]::FromArgb(185,28,28) }
        'Warning' { [System.Drawing.Color]::FromArgb(161,98,7) }
        default { [System.Drawing.Color]::FromArgb(21,128,61) }
    }
    $script:detailStatus.Text = if ($status) { $status } else { 'Inventory record' }

    $script:detailBody.Text = @"
DEVICE
────────────────────────────────────
Serial Number   : $serial
MAC Address     : $mac
Model           : $model
Site            : $site

GREENLAKE
────────────────────────────────────
License         : $license
License End     : $licenseEnd

ARUBA CENTRAL
────────────────────────────────────
Inventory       : $central
Provisioned     : $provisioned
Monitored       : $monitored
Central Status  : $centralStatus
Health          : $health

AUDIT
────────────────────────────────────
Status          : $status
Reason          : $reason
"@
}

$script:grid.Add_SelectionChanged({ Update-DetailPanelFromSelection })

$cellMenu = New-Object System.Windows.Forms.ContextMenuStrip
$copyCell = $cellMenu.Items.Add('Copy Cell')
$copyRow = $cellMenu.Items.Add('Copy Row')
$copySerial = $cellMenu.Items.Add('Copy Serial')
$copyMac = $cellMenu.Items.Add('Copy MAC')
$showDetails = $cellMenu.Items.Add('Show Device Details')
$copyCell.Add_Click({
    if ($script:grid.CurrentCell) { [System.Windows.Forms.Clipboard]::SetText([string]$script:grid.CurrentCell.Value) }
})
$copyRow.Add_Click({
    if ($script:grid.CurrentRow) {
        $values = foreach ($cell in $script:grid.CurrentRow.Cells) { [string]$cell.Value }
        [System.Windows.Forms.Clipboard]::SetText([string]::Join([char]9, $values))
    }
})
$copySerial.Add_Click({
    if ($script:grid.Columns.Contains('SerialNumber') -and $script:grid.CurrentRow) {
        [System.Windows.Forms.Clipboard]::SetText([string]$script:grid.CurrentRow.Cells['SerialNumber'].Value)
    }
})
$copyMac.Add_Click({
    if ($script:grid.Columns.Contains('MACAddress') -and $script:grid.CurrentRow) {
        [System.Windows.Forms.Clipboard]::SetText([string]$script:grid.CurrentRow.Cells['MACAddress'].Value)
    }
})
$showDetails.Add_Click({ Update-DetailPanelFromSelection })
$script:grid.ContextMenuStrip = $cellMenu

$script:grid.Add_CellMouseDown({
    param($sender,$e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right -and $e.RowIndex -ge 0) {
        $sender.ClearSelection()
        $sender.Rows[$e.RowIndex].Selected = $true
        $sender.CurrentCell = $sender.Rows[$e.RowIndex].Cells[[Math]::Max(0,$e.ColumnIndex)]
    }
})

$progressPanel = New-Object System.Windows.Forms.Panel
$progressPanel.Dock = 'Fill'
$progressPanel.Padding = [System.Windows.Forms.Padding]::new(14,3,14,3)
$progressPanel.BackColor = [System.Drawing.Color]::FromArgb(241,245,249)

$script:lblProgress = New-Object System.Windows.Forms.Label
$script:lblProgress.Text = 'Ready'
$script:lblProgress.Font = [System.Drawing.Font]::new('Segoe UI', 8.7)
$script:lblProgress.ForeColor = [System.Drawing.Color]::FromArgb(71,85,105)
$script:lblProgress.Location = [System.Drawing.Point]::new(16,5)
$script:lblProgress.Size = [System.Drawing.Size]::new(520,28)
$script:lblProgress.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

$script:progressBar = New-Object System.Windows.Forms.ProgressBar
$script:progressBar.Style = 'Continuous'
$script:progressBar.Minimum = 0
$script:progressBar.Maximum = 100
$script:progressBar.Visible = $false
$script:progressBar.Location = [System.Drawing.Point]::new(535,9)
$script:progressBar.Size = [System.Drawing.Size]::new(420,20)
$script:progressBar.Anchor = 'Top,Left,Right'

$script:lblProgressPercent = New-Object System.Windows.Forms.Label
$script:lblProgressPercent.Text = ''
$script:lblProgressPercent.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 8.5)
$script:lblProgressPercent.ForeColor = [System.Drawing.Color]::FromArgb(71,85,105)
$script:lblProgressPercent.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$script:lblProgressPercent.Location = [System.Drawing.Point]::new(960,4)
$script:lblProgressPercent.Size = [System.Drawing.Size]::new(60,28)

function Position-ProgressBar {
    try {
        $usable = [Math]::Max(220, $progressPanel.ClientSize.Width - 620)
        $script:progressBar.Left = 535
        $script:progressBar.Width = $usable
        $script:lblProgressPercent.Left = 535 + $usable + 8
    } catch {}
}
$progressPanel.Add_Resize({ Position-ProgressBar })

$script:btnToggleLog = New-Object System.Windows.Forms.Button
$script:btnToggleLog.Text = 'Show Audit Log ▾'
$script:btnToggleLog.Width = 130
$script:btnToggleLog.Height = 30
$script:btnToggleLog.FlatStyle = 'Flat'
$script:btnToggleLog.FlatAppearance.BorderSize = 0
$script:btnToggleLog.BackColor = [System.Drawing.Color]::FromArgb(226,232,240)
$script:btnToggleLog.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)
$script:btnToggleLog.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 8.5)
$script:btnToggleLog.Cursor = [System.Windows.Forms.Cursors]::Hand

$logBar = New-Object System.Windows.Forms.Panel
$logBar.Dock = 'Top'
$logBar.Height = 34
$logBar.BackColor = [System.Drawing.Color]::FromArgb(226,232,240)

$logHint = New-Object System.Windows.Forms.Label
$logHint.Text = 'Diagnostics available for troubleshooting'
$logHint.Font = [System.Drawing.Font]::new('Segoe UI', 8)
$logHint.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
$logHint.Location = [System.Drawing.Point]::new(136,7)
$logHint.AutoSize = $true
[void]$logBar.Controls.Add($script:btnToggleLog)
[void]$logBar.Controls.Add($logHint)

$logGroup = New-Object System.Windows.Forms.GroupBox
$logGroup.Text = ' Audit Log '
$logGroup.Font = $fontSection
$logGroup.Dock = 'Fill'
$logGroup.BackColor = [System.Drawing.Color]::White
$logGroup.Padding = [System.Windows.Forms.Padding]::new(3,5,3,3)
$logGroup.Visible = $false

$script:txtLog = New-Object System.Windows.Forms.RichTextBox
$script:txtLog.Dock = 'Fill'
$script:txtLog.ReadOnly = $true
$script:txtLog.BorderStyle = 'None'
$script:txtLog.BackColor = [System.Drawing.Color]::FromArgb(248,250,252)
$script:txtLog.Font = [System.Drawing.Font]::new('Consolas', 8.5)
[void]$logGroup.Controls.Add($script:txtLog)

$script:btnToggleLog.Add_Click({
    $open = -not $logGroup.Visible
    $logGroup.Visible = $open
    $root.RowStyles[5].Height = if ($open) { 160 } else { 34 }
    $script:btnToggleLog.Text = if ($open) { 'Hide Audit Log ▴' } else { 'Show Audit Log ▾' }
})

function Get-HistoryPath {
    $base = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ALIA'
    if (-not (Test-Path -LiteralPath $base)) {
        New-Item -ItemType Directory -Path $base -Force | Out-Null
    }
    return Join-Path $base 'audit-history.json'
}

function Get-AuditHistory {
    $path = Get-HistoryPath
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try {
        $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        return @($raw | ConvertFrom-Json)
    } catch {
        return @()
    }
}

function Save-AuditHistory {
    param([Parameter(Mandatory)][timespan]$Duration)

    $record = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Duration = $Duration.ToString('hh\:mm\:ss')
        GreenLakeCount = $script:GreenLakeInventory.Count
        CentralCount = $script:ArubaInventory.Count
        MonitoredCount = $script:ArubaMonitoredInventory.Count
        LicensedCount = @($script:AuditResults | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LicenseTier) }).Count
        IssueCount = Get-AuditIssueCount
        ExpiredCount = @(Get-ViewObjects -View 'Expired').Count
        CoveragePercent = Get-AuditCoveragePercent
    }

    $history = @(Get-AuditHistory)
    $history = @($record) + @($history | Select-Object -First 49)
    $history | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Get-HistoryPath) -Encoding UTF8
    return $record
}

function Show-AuditHistoryDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'ALIA - Audit History'
    $form.StartPosition = 'CenterParent'
    $form.Size = [System.Drawing.Size]::new(930,520)
    $form.BackColor = [System.Drawing.Color]::FromArgb(241,245,249)

    $history = @(Get-AuditHistory)
    $table = New-Object System.Data.DataTable
    foreach($c in @('Date','Duration','GreenLake','Central','Monitored','Licensed','Exceptions','Expired','Coverage')) {
        [void]$table.Columns.Add($c)
    }

    foreach($h in $history){
        $row=$table.NewRow()
        $row['Date']=[string]$h.Timestamp
        $row['Duration']=[string]$h.Duration
        $row['GreenLake']=[string]$h.GreenLakeCount
        $row['Central']=[string]$h.CentralCount
        $row['Monitored']=[string]$h.MonitoredCount
        $row['Licensed']=[string]$h.LicensedCount
        $row['Exceptions']=[string]$h.IssueCount
        $row['Expired']=[string]$h.ExpiredCount
        $row['Coverage']="$([string]$h.CoveragePercent)%"
        [void]$table.Rows.Add($row)
    }

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock='Fill'
    $grid.ReadOnly=$true
    $grid.RowHeadersVisible=$false
    $grid.AllowUserToAddRows=$false
    $grid.AutoSizeColumnsMode='Fill'
    $grid.EnableHeadersVisualStyles=$false
    $grid.ColumnHeadersDefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(15,23,42)
    $grid.ColumnHeadersDefaultCellStyle.ForeColor=[System.Drawing.Color]::White
    $grid.DataSource=$table
    [void]$form.Controls.Add($grid)

    $form.ShowDialog($script:frm) | Out-Null
}

$script:btnHistory.Add_Click({ Show-AuditHistoryDialog })

$script:CurrentFilterDeviceType = 'All'
$script:CurrentFilterHealth = 'All'
$script:CurrentFilterLicense = 'All'
$script:CurrentFilterStatus = 'All'

$script:btnResetFilters.Add_Click({
    $script:txtSearch.Text = ''
    $script:cmbLicense.SelectedIndex = 0
    $script:cmbHealth.SelectedIndex = 0
    $script:cmbDeviceType.SelectedIndex = 0
    $script:chkProblemsOnly.Checked = $false
    Invoke-CurrentSearch
})

$script:cmbLicense.Add_SelectedIndexChanged({ Invoke-CurrentSearch })
$script:cmbHealth.Add_SelectedIndexChanged({ Invoke-CurrentSearch })
$script:cmbDeviceType.Add_SelectedIndexChanged({ Invoke-CurrentSearch })
$script:chkProblemsOnly.Add_CheckedChanged({ Invoke-CurrentSearch })

$resultsHeader.Visible = $true

$script:txtSearch.Add_TextChanged({
    $script:SearchTimer.Stop()
    if ([string]::IsNullOrWhiteSpace($script:txtSearch.Text)) {
        Invoke-CurrentSearch
        return
    }
    $script:SearchTimer.Start()
})
$script:txtSearch.Add_KeyDown({
    param($sender,$eventArgs)
    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $eventArgs.SuppressKeyPress = $true
        Invoke-CurrentSearch
    }
})
$script:SearchTimer.Add_Tick({ Invoke-CurrentSearch })

$script:frm.Add_KeyDown({
    param($sender,$eventArgs)
    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::F5 -and -not $script:Busy) {
        $script:btnRunAudit.PerformClick()
        $eventArgs.SuppressKeyPress = $true
    }
    elseif ($eventArgs.Control -and $eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::L) {
        $script:btnToggleLog.PerformClick()
        $eventArgs.SuppressKeyPress = $true
    }
})

function Update-SessionStatus {
    $last = @(Get-AuditHistory) | Select-Object -First 1
    if ($null -ne $last) {
        $script:sessionAuditLabel.Text = "Last audit: $($last.Timestamp)"
        $script:sessionDurationLabel.Text = "Duration: $($last.Duration)"
        $script:sessionCoverageLabel.Text = "Coverage: $($last.CoveragePercent)%"
    }
    else {
        $script:sessionAuditLabel.Text = 'Last audit: —'
        $script:sessionDurationLabel.Text = 'Duration: —'
        $script:sessionCoverageLabel.Text = 'Coverage: —'
    }
}

$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.Dock = 'Bottom'
$statusStrip.Height = 30
$statusStrip.SizingGrip = $false
$statusStrip.BackColor = [System.Drawing.Color]::FromArgb(226,232,240)

$script:statusIndicator = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:statusIndicator.Text = '●'
$script:statusIndicator.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)

$script:lblStatus = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:lblStatus.Text = 'Ready'
$script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)

$logSpring = New-Object System.Windows.Forms.ToolStripStatusLabel
$logSpring.Spring = $true

$script:sessionAuditLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:sessionAuditLabel.Text = 'Last audit: —'
$script:sessionDurationLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:sessionDurationLabel.Text = 'Duration: —'
$script:sessionCoverageLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:sessionCoverageLabel.Text = 'Coverage: —'

$logPath = New-Object System.Windows.Forms.ToolStripStatusLabel
$logPath.Text = "Log: $([System.IO.Path]::GetFileName($script:LogFile))"
$logPath.ToolTipText = "Log: $script:LogFile"
$logPath.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)

[void]$statusStrip.Items.Add($script:statusIndicator)
[void]$statusStrip.Items.Add($script:lblStatus)
[void]$statusStrip.Items.Add($script:sessionAuditLabel)
[void]$statusStrip.Items.Add($script:sessionDurationLabel)
[void]$statusStrip.Items.Add($script:sessionCoverageLabel)
[void]$statusStrip.Items.Add($logSpring)
[void]$statusStrip.Items.Add($logPath)

$root.Controls.Add($header,0,0)
$root.Controls.Add($connectionPanel,0,1)
$root.Controls.Add($overview,0,2)
$root.Controls.Add($toolbar,0,3)
$root.Controls.Add($workspaceHost,0,4)

$logHost = New-Object System.Windows.Forms.TableLayoutPanel
$logHost.Dock='Fill'
$logHost.RowCount=2
[void]$logHost.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute,34))
[void]$logHost.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
[void]$logHost.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
[void]$logHost.Controls.Add($logBar,0,0)
[void]$logHost.Controls.Add($logGroup,0,1)
$root.Controls.Add($logHost,0,5)

[void]$script:frm.Controls.Add($root)
[void]$script:frm.Controls.Add($statusStrip)

$script:frm.Add_Resize({
    try {
        Position-Header
        Position-Toolbar
        Position-ViewHeader
        Position-ProgressBar
        if ($workspace.ClientSize.Width -gt 0) {
            $workspace.SplitterDistance = [Math]::Max(650, [int]($workspace.ClientSize.Width * 0.72))
        }
    } catch {}
})

Position-Header
Position-Toolbar
Position-ViewHeader
Position-ProgressBar
Update-SessionStatus

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

$script:SearchTimer = New-Object System.Windows.Forms.Timer
$script:SearchTimer.Interval = 450

function Invoke-CurrentSearch {
    $script:SearchTimer.Stop()

    if ($script:CurrentView -eq 'Issues') {
        $base = @($script:AuditResults | Where-Object {
            (Get-AuditHealth -Status ([string]$_.AuditStatus)) -ne 'Healthy'
        })
    }
    else {
        $base = @(Get-ViewObjects -View $script:CurrentView)
    }

    $term = $script:txtSearch.Text.Trim()
    if (-not [string]::IsNullOrWhiteSpace($term)) {
        $escapedTerm = [regex]::Escape($term)
        $base = @(
            $base | Where-Object {
                $values = $_.PSObject.Properties |
                    ForEach-Object { [string]$_.Value } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                $blob = $values -join ' | '
                $blob -match "(?i)$escapedTerm"
            }
        )
    }

    $licenseFilter = [string]$script:cmbLicense.SelectedItem
    $healthFilter = [string]$script:cmbHealth.SelectedItem
    $deviceFilter = [string]$script:cmbDeviceType.SelectedItem
    $problemsOnly = $script:chkProblemsOnly.Checked

    if ($licenseFilter -eq 'Licensed') {
        $base = @($base | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LicenseTier) })
    }
    elseif ($licenseFilter -eq 'Unlicensed') {
        $base = @($base | Where-Object { [string]::IsNullOrWhiteSpace($_.LicenseTier) })
    }
    elseif ($licenseFilter -eq 'Expired') {
        $base = @($base | Where-Object {
            if ([string]::IsNullOrWhiteSpace($_.LicenseEnd)) { return $false }
            try { ([datetime]$_.LicenseEnd) -lt (Get-Date) } catch { return $false }
        })
    }

    if ($healthFilter -ne 'All') {
        $base = @($base | Where-Object {
            (Get-AuditHealth -Status ([string]$_.AuditStatus)) -eq $healthFilter
        })
    }

    if ($deviceFilter -ne 'All') {
        $base = @($base | Where-Object {
            [string]$_.GreenLakeDeviceType -eq $deviceFilter -or
            [string]$_.NormalizedDeviceType -eq $deviceFilter
        })
    }

    if ($problemsOnly) {
        $base = @($base | Where-Object {
            (Get-AuditHealth -Status ([string]$_.AuditStatus)) -ne 'Healthy'
        })
    }

    $properties = @(Get-ViewProperties -View $script:CurrentView)
    if ($script:CurrentView -eq 'Issues') {
        $properties = @(
            'SerialNumber','MACAddress','GreenLakeDeviceType','Model','DeviceName',
            'LicenseTier','LicenseEnd','ArubaInventoryPresent','ArubaProvisioned',
            'ArubaMonitoredPresent','ArubaStatus','ArubaHealth','AuditStatus','AuditReason'
        )
    }

    $searchTable = New-DataTableFromObjects -Items $base -Properties $properties

    $script:grid.SuspendLayout()
    try {
        $script:grid.DataSource = $null
        $script:grid.Columns.Clear()
        $script:grid.AutoGenerateColumns = $true
        $script:grid.DataSource = $searchTable
        foreach ($column in $script:grid.Columns) {
            $column.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::Automatic
        }
        if ($script:grid.Columns.Contains('SerialNumber')) { $script:grid.Columns['SerialNumber'].Frozen = $true }
        if ($script:grid.Columns.Contains('MACAddress')) { $script:grid.Columns['MACAddress'].Frozen = $true }
        foreach ($row in $script:grid.Rows) {
            if ($script:grid.Columns.Contains('AuditStatus')) {
                $licenseEndValue = if ($script:grid.Columns.Contains('LicenseEnd')) {
                    [string]$row.Cells['LicenseEnd'].Value
                } else { '' }
                switch (Get-AuditHealth -Status ([string]$row.Cells['AuditStatus'].Value) -LicenseEnd $licenseEndValue) {
                    'Critical' { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(254,242,242) }
                    'Warning'  { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(255,251,235) }
                }
            }
        }
    }
    finally {
        $script:grid.ResumeLayout()
    }

    $script:lblRecordCount.Text = "Records: $($base.Count)"
    Write-AuditLog DEBUG "Search/filter applied: view='$script:CurrentView'; term='$term'; license='$licenseFilter'; health='$healthFilter'; device='$deviceFilter'; problemsOnly=$problemsOnly; results=$($base.Count)."
    try { Update-DetailPanelFromSelection } catch {}
}
$script:SearchTimer.Add_Tick({
    Invoke-CurrentSearch
})

$script:txtSearch.Add_TextChanged({
    # Wait until the user pauses typing before running the search.
    $script:SearchTimer.Stop()

    if ([string]::IsNullOrWhiteSpace($script:txtSearch.Text)) {
        Invoke-CurrentSearch
        return
    }

    $script:SearchTimer.Start()
})

$script:txtSearch.Add_KeyDown({
    param($sender, $eventArgs)

    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $eventArgs.SuppressKeyPress = $true
        Invoke-CurrentSearch
    }
})

$script:btnShowAll.Add_Click({
    $script:SearchTimer.Stop()
    $script:txtSearch.Text = ''
    Show-View -View Audit -Title 'All Audit Results'
})



# ---------------------------------------------------------------------------
# Button events
# ---------------------------------------------------------------------------

$script:btnTestConnections.Add_Click({
    if ($script:Busy) {
        return
    }

    $glClientId = $script:txtGLClientId.Text.Trim()
    $glClientSecret = $script:txtGLClientSecret.Text
    $arubaClientId = $script:txtArubaClientId.Text.Trim()
    $arubaClientSecret = $script:txtArubaClientSecret.Text

    if ([string]::IsNullOrWhiteSpace($glClientId) -or
        [string]::IsNullOrWhiteSpace($glClientSecret) -or
        [string]::IsNullOrWhiteSpace($arubaClientId) -or
        [string]::IsNullOrWhiteSpace($arubaClientSecret)) {

        [System.Windows.Forms.MessageBox]::Show(
            $script:frm,
            'Please enter the Client ID and Client Secret for both HPE GreenLake and Aruba Central.',
            'Connection Test',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        return
    }

    try {
        $script:OperationMode = 'TestConnections'
        $script:AuditStartTime = Get-Date

        Set-BusyState $true

        $script:progressBar.Value = 0
        $script:progressBar.Visible = $false
        $script:lblProgress.Text = 'Connection test running...'
        Set-Status 'Testing HPE GreenLake and Aruba Central connections...' 'Running'

        Set-ConnectionIndicator -Platform GreenLake -State Testing -Message 'Testing...'
        Set-ConnectionIndicator -Platform ArubaCentral -State Testing -Message 'Testing...'

        Write-AuditLog INFO '============================================================'
        Write-AuditLog INFO 'Connection test started.'
        Write-AuditLog INFO 'Testing HPE GreenLake authentication and API access.'
        Write-AuditLog INFO 'Testing Aruba Central authentication and API access.'

        Start-OperationRunspace `
            -Mode TestConnections `
            -GLClientId $glClientId `
            -GLClientSecret $glClientSecret `
            -ArubaClientId $arubaClientId `
            -ArubaClientSecret $arubaClientSecret

        $script:WorkerTimer.Start()
    }
    catch {
        $message = Get-SafeErrorMessage $_

        Set-BusyState $false
        Set-Status 'Connection test could not be started.' 'Error'

        Write-AuditLog ERROR "Connection test start failed: $message"
        Show-ErrorDialog -Message $message -Title 'Connection Test Error'
    }
})

$script:btnRunAudit.Add_Click({
    if ($script:Busy) {
        return
    }

    $glClientId = $script:txtGLClientId.Text.Trim()
    $glClientSecret = $script:txtGLClientSecret.Text
    $arubaClientId = $script:txtArubaClientId.Text.Trim()
    $arubaClientSecret = $script:txtArubaClientSecret.Text

    if ([string]::IsNullOrWhiteSpace($glClientId) -or
        [string]::IsNullOrWhiteSpace($glClientSecret) -or
        [string]::IsNullOrWhiteSpace($arubaClientId) -or
        [string]::IsNullOrWhiteSpace($arubaClientSecret)) {

        [System.Windows.Forms.MessageBox]::Show(
            $script:frm,
            'Client ID and Client Secret are required for both platforms.',
            'License Audit',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        return
    }

    try {
        $script:OperationMode = 'RunAudit'
        $script:AuditStartTime = Get-Date
        $script:progressBar.Visible = $true
        $script:GreenLakeInventory = @()
        $script:ArubaInventory = @()
        $script:ArubaMonitoredInventory = @()
        $script:AuditResults = @()
        $script:CentralNotMonitoredCache = $null
        $script:GLUnlicensedCentralMonitoredCache = $null
        $script:LicensedNotInMonitoredCache = $null

        $script:txtSearch.Text = ''
        $script:grid.DataSource = $null
        $script:lblRecordCount.Text = 'Records: 0'

        Update-Dashboard
        Update-Progress 0 'Starting license audit...'
        Set-Status 'Starting license audit...' 'Running'
        Set-BusyState $true

        Write-AuditLog INFO '============================================================'
        Write-AuditLog INFO 'HPE Aruba License Inventory Audit started.'
        Write-AuditLog INFO '============================================================'
        Write-AuditLog INFO "GreenLake API: $script:GreenLakeDeviceApiUrl"
        Write-AuditLog INFO "Aruba Central API: $script:ArubaCentralInventoryApiUrl"
        Write-AuditLog INFO 'Credentials captured for this run. Credentials are not written to the audit log.'

        Start-OperationRunspace `
            -Mode RunAudit `
            -GLClientId $glClientId `
            -GLClientSecret $glClientSecret `
            -ArubaClientId $arubaClientId `
            -ArubaClientSecret $arubaClientSecret

        $script:WorkerTimer.Start()
    }
    catch {
        $message = Get-SafeErrorMessage $_

        Set-BusyState $false
        Update-Progress 0 'Audit failed.'
        Set-Status 'Unable to start license audit.' 'Error'

        Write-AuditLog ERROR "Audit start failed: $message"
        Show-ErrorDialog -Message $message -Title 'License Audit Error'
    }
})

$script:btnExport.Add_Click({
    try {
        $objects = @(Get-ViewObjects -View $script:CurrentView)

        if ($objects.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                $script:frm,
                'There are no records in the current view to export.',
                'Export',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Title = 'Export Current View'
        $dialog.Filter = 'CSV files (*.csv)|*.csv'
        $safeViewName = ($script:CurrentViewTitle -replace '[^A-Za-z0-9_-]', '_')
        $dialog.FileName = "ALIA_$safeViewName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $dialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')

        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            return
        }

        # Export the underlying object set, not GUI-formatted cell values.
        $objects | Export-Csv `
            -LiteralPath $dialog.FileName `
            -NoTypeInformation `
            -Encoding UTF8

        Write-AuditLog SUCCESS `
            "Exported $($objects.Count) record(s) from view '$($script:CurrentViewTitle)' to $($dialog.FileName)."

        [System.Windows.Forms.MessageBox]::Show(
            $script:frm,
            "Export completed successfully.`r`n`r`nRecords: $($objects.Count)`r`nFile: $($dialog.FileName)",
            'Export Complete',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch {
        $message = Get-SafeErrorMessage $_
        Write-AuditLog ERROR "Export failed: $message"
        Show-ErrorDialog -Message $message -Title 'Export Failed'
    }
})

$script:btnClear.Add_Click({
    if ($script:Busy) {
        return
    }

    $script:GreenLakeInventory = @()
    $script:ArubaInventory = @()
    $script:ArubaMonitoredInventory = @()
    $script:AuditResults = @()
    $script:CentralNotMonitoredCache = $null
    $script:GLUnlicensedCentralMonitoredCache = $null
    $script:LicensedNotInMonitoredCache = $null
    $script:CurrentView = 'Audit'
    $script:CurrentViewTitle = 'All Audit Results'

    $script:txtSearch.Text = ''
    $script:grid.DataSource = $null
    $script:lblViewTitle.Text = 'All Audit Results'
    $script:lblRecordCount.Text = 'Records: 0'

    $script:lblGreenLakeConnection.Text = 'Not Tested'
    $script:lblArubaConnection.Text = 'Not Tested'
    $script:lblGreenLakeConnection.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
    $script:lblArubaConnection.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)

    Update-Dashboard
    Update-Progress 0 'Ready'
    $script:progressBar.Visible = $false
    Set-Status 'Ready.' 'Ready'

    Write-AuditLog INFO 'Results and connection state cleared.'
})

# ---------------------------------------------------------------------------
# Runspace timer
# ---------------------------------------------------------------------------

$script:WorkerTimer = New-Object System.Windows.Forms.Timer
$script:WorkerTimer.Interval = 200

$script:WorkerTimer.Add_Tick({
    if ($null -eq $script:WorkerQueue) {
        return
    }

    $record = $null

    while ($script:WorkerQueue.TryDequeue([ref]$record)) {
        if ($record.RecordType -eq 'Log') {
            Write-AuditLog -Level $record.Level -Message $record.Message
        }
        elseif ($record.RecordType -eq 'Progress') {
            if ($script:OperationMode -eq 'RunAudit') {
                Update-Progress -Percent $record.Percent -Text $record.Message
            }
            else {
                # Connection tests update the status text but keep the progress bar hidden.
                $script:lblProgress.Text = $record.Message
            }
        }
        elseif ($record.RecordType -eq 'Result') {
            $script:WorkerFinalResult = $record
        }

        $record = $null
    }

    if ($script:WorkerAsyncResult -and $script:WorkerAsyncResult.IsCompleted) {
        $script:WorkerTimer.Stop()

        # Drain any final records emitted immediately before completion.
        $record = $null

        while ($script:WorkerQueue -and
               $script:WorkerQueue.TryDequeue([ref]$record)) {

            if ($record.RecordType -eq 'Log') {
                Write-AuditLog -Level $record.Level -Message $record.Message
            }
            elseif ($record.RecordType -eq 'Progress' -and
                    $script:OperationMode -eq 'RunAudit') {

                Update-Progress -Percent $record.Percent -Text $record.Message
            }
            elseif ($record.RecordType -eq 'Result') {
                $script:WorkerFinalResult = $record
            }

            $record = $null
        }

        try {
            # EndInvoke is required to surface pipeline-level runspace failures.
            $null = $script:WorkerPowerShell.EndInvoke($script:WorkerAsyncResult)
        }
        catch {
            $message = Get-SafeErrorMessage $_

            Stop-OperationRunspace
            Set-BusyState $false
            Set-Status 'Operation failed.' 'Error'
            Update-Progress 0 'Operation failed.'
            Write-AuditLog ERROR "Runspace execution failed: $message"

            Show-ErrorDialog -Message $message -Title 'ALIA Error'
            return
        }

        $final = $script:WorkerFinalResult
        $mode = $script:OperationMode

        Stop-OperationRunspace
        Set-BusyState $false

        if ($null -eq $final) {
            Set-Status 'Operation completed without a result.' 'Error'
            Write-AuditLog ERROR 'Runspace completed without returning a result.'
            Show-ErrorDialog -Message 'The operation completed without returning a final result.' -Title 'ALIA Error'
            return
        }

        if ([string]$final.Level -eq 'ERROR') {
            Set-Status 'Operation failed.' 'Error'
            Write-AuditLog ERROR [string]$final.Message
            Update-Progress 0 'Operation failed.'

            if ($mode -eq 'TestConnections') {
                [System.Windows.Forms.MessageBox]::Show(
                    $script:frm,
                    [string]$final.Message,
                    'Connection Test Error',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
            else {
                Show-ErrorDialog -Message ([string]$final.Message) -Title 'License Audit Error'
            }

            return
        }

        if ($mode -eq 'TestConnections') {
            $result = $final.Data
            Apply-ConnectionResult -Result $result

            $script:lblProgress.Text = 'Connection test complete.'
            $script:progressBar.Value = 0
            $script:progressBar.Visible = $false

            return
        }

        # RunAudit result: normalize + compare.
        $script:GreenLakeInventory = @($final.Data.GreenLake)
        $script:ArubaInventory = @($final.Data.ArubaInventory)
        $script:ArubaMonitoredInventory = @($final.Data.ArubaMonitored)

        Write-AuditLog INFO 'Building GreenLake-to-Aruba Central reconciliation results.'
        Update-Progress 84 'Matching GreenLake and Aruba Central inventories...'

        $script:AuditResults = @(Build-AuditResults `
            -GreenLake $script:GreenLakeInventory `
            -ArubaInventory $script:ArubaInventory `
            -ArubaMonitored $script:ArubaMonitoredInventory)

        # Build the expensive cross-dataset views once per audit. Tile clicks
        # and exports reuse these cached result sets.
        $script:CentralNotMonitoredCache = @(Get-CentralInventoryNotMonitored)
        $script:GLUnlicensedCentralMonitoredCache = @(Get-GLUnlicensedCentralMonitored)
        $script:LicensedNotInMonitoredCache = @($script:AuditResults | Where-Object {
            (-not [string]::IsNullOrWhiteSpace([string]$_.LicenseTier)) -and
            ([string]$_.ArubaMonitoredPresent -eq 'No')
        })

        Update-Dashboard

        $notInInventory = @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - NOT IN CENTRAL INVENTORY' }).Count
        $notProvisioned = @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - IN INVENTORY - NOT PROVISIONED' }).Count
        $notMonitored = @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - PROVISIONED - NOT MONITORED' }).Count
        $offline = @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - MONITORED - OFFLINE' }).Count
        $licensedNotInMonitoredCount = @($script:LicensedNotInMonitoredCache).Count
        Write-AuditLog INFO "Licensed devices absent from Aruba Central monitored list: $licensedNotInMonitoredCount"
        $centralNotMonitoredCount = @($script:CentralNotMonitoredCache).Count
        $glUnlicensedCentralMonitoredCount = @($script:GLUnlicensedCentralMonitoredCache).Count
        Write-AuditLog INFO "Central Inventory devices absent from Aruba Central monitored list: $centralNotMonitoredCount"

        Update-Progress 95 'Building audit dashboard...'

        Show-View -View Audit -Title 'All Audit Results'

        if (($notInInventory + $notProvisioned + $notMonitored + $offline + $licensedNotInMonitoredCount) -gt 0) {
            Write-AuditLog WARNING "Licensed-device exceptions: NotInInventory=$notInInventory; NotProvisioned=$notProvisioned; NotMonitored=$notMonitored; LicensedNotInMonitored=$licensedNotInMonitoredCount; Offline=$offline."
        }
        else {
            Write-AuditLog SUCCESS 'No licensed-device exceptions were identified.'
        }

        Update-Progress 100 'License audit completed.'
        Set-Status 'License audit completed successfully.' 'Success'

        $elapsed = (Get-Date) - $script:AuditStartTime

        Write-AuditLog SUCCESS (
            "Audit completed. GreenLake={0}; ArubaCentral={1}; Licensed={2}; NotInCentral={3}; Duration={4:mm\:ss}." -f
            $script:GreenLakeInventory.Count,
            $script:ArubaInventory.Count,
            @($script:AuditResults | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LicenseTier) }).Count,
            $notInInventory,
            $elapsed
        )

        $historyRecord = Save-AuditHistory -Duration $elapsed
        Update-SessionStatus
        Write-AuditLog SUCCESS ("Audit session saved to history. Exceptions={0}; Coverage={1}%." -f $historyRecord.IssueCount, $historyRecord.CoveragePercent)
        Update-Dashboard

        $script:btnExport.Enabled = $true
    }
})

# ---------------------------------------------------------------------------
# Form close handling
# ---------------------------------------------------------------------------

$script:frm.Add_FormClosing({
    param($sender, $e)

    if ($script:SearchTimer) {
        $script:SearchTimer.Stop()
    }

    if ($script:Busy) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            $script:frm,
            'An operation is currently running. Close the application anyway?',
            'Operation in Progress',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            $e.Cancel = $true
            return
        }

        if ($script:WorkerTimer) {
            $script:WorkerTimer.Stop()
        }

        Stop-OperationRunspace
    }
})

# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

Write-AuditLog INFO "Application started. Version=$script:AppVersion."
Write-AuditLog INFO "Log file: $script:LogFile"
Write-AuditLog INFO 'HPE GreenLake + Aruba Central license reconciliation.'
Write-AuditLog INFO 'Dedicated runspace worker initialized for Windows PowerShell 5.1 / ISE. GUI=Audit Workspace v3.1.'
Write-AuditLog INFO "GreenLake device endpoint: $script:GreenLakeDeviceApiUrl"
Write-AuditLog INFO "Aruba Central inventory endpoint: $script:ArubaCentralInventoryApiUrl"
Write-AuditLog INFO "Aruba Central monitored-device endpoint: $script:ArubaCentralDevicesApiUrl"
Write-AuditLog INFO 'Connection test uses API authentication and minimal inventory requests.'

Update-ResponsiveLayout
Update-Dashboard
$script:progressBar.Visible = $false
$script:lblProgress.Text = 'Ready'
Show-View -View Audit -Title 'All Audit Results'
[System.Windows.Forms.Application]::DoEvents()
Close-StartupSplash

[void]$script:frm.ShowDialog()

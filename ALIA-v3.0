#requires -Version 5.1

<#
.SYNOPSIS
    ALIA - HPE Aruba License Inventory Audit
    HPE GreenLake + Aruba Central Reconciliation
    Developed by Prathamesh Hankare

.VERSION
    3.0

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
        $graphics.DrawString('Version 3.0', $smallFont, $muted, (SX 216), (SY 268))

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
    Start-Sleep -Milliseconds 3000
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
$script:AppVersion = 'v3.0.3'

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

    if ($script:txtSearch -and
        $script:txtSearch.Text.Trim().Length -gt 0) {
        $script:txtSearch.Text = ''
    }

    $script:CurrentView = $View
    $script:CurrentViewTitle = if ($Title) { $Title } else { $View }
    $script:lblViewTitle.Text = $script:CurrentViewTitle
    Position-ViewHeader

    $objects = @(Get-ViewObjects -View $View)

    $properties = @(Get-ViewProperties -View $View)

    $table = New-DataTableFromObjects `
        -Items $objects `
        -Properties $properties

    # Force a complete DataGridView rebind when changing dashboard tiles.
    $script:grid.SuspendLayout()
    try {
        $script:grid.DataSource = $null
        $script:grid.Columns.Clear()
        $script:grid.AutoGenerateColumns = $true
        $script:grid.DataSource = $table
        Write-AuditLog DEBUG "Grid bound: view='$script:CurrentView'; rows=$($table.Rows.Count); columns=$($table.Columns.Count)."
        $script:grid.Refresh()
        $script:grid.Invalidate()
    }
    finally {
        $script:grid.ResumeLayout()
    }

    $headers = @{
        SerialNumber='Serial Number'; MACAddress='MAC Address'; NormalizedDeviceType='Device Type'
        GreenLakeDeviceType='GL Device Type'; DeviceName='Device Name'; SiteName='Site'
        LicenseTier='License Tier'; LicenseStart='License Start'; LicenseEnd='License End'
        IsProvisioned='Provisioned'; FirmwareVersion='Firmware'; DeviceGroupName='Device Group'
        DeviceFunction='Device Function'; Deployment='Deployment'; DeviceIp='IP Address'; ClusterName='Cluster'
        ArubaInventoryPresent='In Central Inventory'; ArubaProvisioned='Provisioned'
        ArubaMonitoredPresent='Monitored'; ArubaStatus='Central Status'; ArubaHealth='Central Health'
        ArubaInventoryDeviceName='Central Inventory Name'; ArubaInventorySiteName='Central Inventory Site'
        ArubaMonitoredDeviceName='Monitored Device Name'; ArubaMonitoredSiteName='Monitored Site'
        GreenLakeLicenseStatus='GreenLake License Status'
        InventoryMatchMethod='Inventory Match'; MonitoringMatchMethod='Monitoring Match'
        AuditStatus='Audit Status'; AuditReason='Audit Reason'; PartNumber='Part Number'
        Region='Region'; Category='Category'; Ownership='Ownership'; SubscriptionCount='Subscriptions'
    }

    foreach ($column in $script:grid.Columns) {
        if ($headers.ContainsKey($column.Name)) {
            $column.HeaderText = $headers[$column.Name]
        }
    }

    if ($script:grid.Columns.Contains('AuditStatus')) {
        foreach ($row in $script:grid.Rows) {
            $status = [string]$row.Cells['AuditStatus'].Value

            switch -Regex ($status) {
                '^LICENSED - NOT IN CENTRAL INVENTORY$' { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(254,242,242) }
                '^LICENSED - IN INVENTORY - NOT PROVISIONED$' { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(255,251,235) }
                '^LICENSED - PROVISIONED - NOT MONITORED$' { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(255,247,237) }
                '^LICENSED - MONITORED - OFFLINE$' { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(254,242,242) }
                '^LICENSED - MONITORED - ONLINE$' { $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240,253,244) }
            }
        }
    }

    $script:lblRecordCount.Text = "Records: $($objects.Count)"
    Write-AuditLog DEBUG "View '$script:CurrentViewTitle' loaded with $($objects.Count) record(s)."
}

# ---------------------------------------------------------------------------
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

function Update-Dashboard {
    $glCount = $script:GreenLakeInventory.Count
    $arubaInventoryCount = $script:ArubaInventory.Count
    $arubaMonitoredCount = $script:ArubaMonitoredInventory.Count
    $centralNotMonitoredCount = @(Get-CentralInventoryNotMonitored).Count
    $glUnlicensedCentralMonitoredCount = @(Get-GLUnlicensedCentralMonitored).Count

    $licensedCount = @($script:AuditResults | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LicenseTier) }).Count
    $unlicensedCount = @($script:AuditResults | Where-Object { [string]::IsNullOrWhiteSpace($_.LicenseTier) }).Count

    $notProvisionedCount = @($script:AuditResults | Where-Object { $_.AuditStatus -eq 'LICENSED - IN INVENTORY - NOT PROVISIONED' }).Count
    $licensedNotInMonitoredCount = @(Get-ViewObjects -View 'LicensedNotInMonitored').Count

    $expiredCount = @(Get-ViewObjects -View 'Expired').Count

    $glAp = @($script:GreenLakeInventory | Where-Object { $_.NormalizedDeviceType -eq 'Access Point' }).Count
    $glSwitch = @($script:GreenLakeInventory | Where-Object { $_.NormalizedDeviceType -eq 'Switch' }).Count
    $glGateway = @($script:GreenLakeInventory | Where-Object { $_.NormalizedDeviceType -eq 'Gateway' }).Count

    $arubaAp = @($script:ArubaInventory | Where-Object { $_.NormalizedDeviceType -eq 'Access Point' }).Count
    $arubaSwitch = @($script:ArubaInventory | Where-Object { $_.NormalizedDeviceType -eq 'Switch' }).Count
    $arubaGateway = @($script:ArubaInventory | Where-Object { $_.NormalizedDeviceType -eq 'Gateway' }).Count

    $script:tileGL.ValueLabel.Text = [string]$glCount
    $script:tileArubaInventory.ValueLabel.Text = [string]$arubaInventoryCount
    $script:tileArubaMonitored.ValueLabel.Text = [string]$arubaMonitoredCount
    $script:tileLicensed.ValueLabel.Text = [string]$licensedCount
    $script:tileUnlicensed.ValueLabel.Text = [string]$unlicensedCount
    $script:tileNotProvisioned.ValueLabel.Text = [string]$notProvisionedCount
    $script:tileLicensedNotInMonitored.ValueLabel.Text = [string]$licensedNotInMonitoredCount
    $script:tileLicensedNotInMonitored.SubLabel.Text = ''
    $script:tileCentralNotMonitored.ValueLabel.Text = [string]$centralNotMonitoredCount
    $script:tileCentralNotMonitored.SubLabel.Text = ''
    $script:tileGLUnlicensedCentralMonitored.ValueLabel.Text = [string]$glUnlicensedCentralMonitoredCount
    $script:tileGLUnlicensedCentralMonitored.SubLabel.Text = ''

    $script:tileAP.ValueLabel.Text = [string]$glAp
    $script:tileSwitch.ValueLabel.Text = [string]$glSwitch
    $script:tileGateway.ValueLabel.Text = [string]$glGateway

    $script:tileAP.SubLabel.Text = "Central: $arubaAp"
    $script:tileSwitch.SubLabel.Text = "Central: $arubaSwitch"
    $script:tileGateway.SubLabel.Text = "Central: $arubaGateway"
    $script:tileExpired.ValueLabel.Text = [string]$expiredCount
}

# ---------------------------------------------------------------------------
# GUI layout
# ---------------------------------------------------------------------------

Initialize-Logging
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppVersion = 'v3.0'

$fontRegular = [System.Drawing.Font]::new('Segoe UI', 10.5)
$fontSmall = [System.Drawing.Font]::new('Segoe UI', 9)
$fontTitle = [System.Drawing.Font]::new('Segoe UI Semibold', 19)
$fontSection = [System.Drawing.Font]::new('Segoe UI Semibold', 11)
$fontMetric = [System.Drawing.Font]::new('Segoe UI Semibold', 17)

$script:frm = New-Object System.Windows.Forms.Form
$script:frm.Text = "$script:AppName - $script:AppVersion"
$script:frm.StartPosition = 'CenterScreen'
$script:frm.BackColor = [System.Drawing.Color]::FromArgb(241,245,249)
$script:frm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$script:frm.AutoScaleDimensions = [System.Drawing.SizeF]::new(96,96)
$script:frm.Font = $fontRegular

# Start within the current display's working area so ALIA opens correctly on
# lower-resolution displays and remains usable above the minimum layout size.
$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$targetWidth = [Math]::Min(1500, [Math]::Max(1100, $workArea.Width - 70))
$targetHeight = [Math]::Min(900, [Math]::Max(660, $workArea.Height - 90))
$minClientWidth = [Math]::Min(1100, [Math]::Max(900, $workArea.Width - 40))
$minClientHeight = [Math]::Min(660, [Math]::Max(560, $workArea.Height - 60))
$script:frm.MinimumSize = [System.Drawing.Size]::new($minClientWidth, $minClientHeight)
$script:frm.ClientSize = [System.Drawing.Size]::new($targetWidth, $targetHeight)

# v3.0 root layout: credentials and actions share one compact enterprise row,
# reclaiming vertical space for the dashboard and results grid.
$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = 'Fill'
$root.Margin = [System.Windows.Forms.Padding]::Empty
$root.Padding = [System.Windows.Forms.Padding]::Empty
$root.ColumnCount = 1
$root.RowCount = 6
$root.BackColor = [System.Drawing.Color]::FromArgb(241,245,249)
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 80))   # Header
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 96))   # Credentials + 2x2 action buttons
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 42))   # Progress
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 228))  # Dashboard
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))    # Results
[void]$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 78))   # Audit log
[void]$root.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))

# Header
$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Fill'
$header.BackColor = [System.Drawing.Color]::FromArgb(15,23,42)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'HPE Aruba License Inventory Audit'
$title.ForeColor = [System.Drawing.Color]::White
$title.Font = $fontTitle
$title.AutoSize = $true
$title.Location = [System.Drawing.Point]::new(28, 6)
[void]$header.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'HPE GreenLake + Aruba Central Reconciliation '
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(148,163,184)
$subtitle.Font = [System.Drawing.Font]::new('Segoe UI', 10.5)
$subtitle.AutoSize = $true
$subtitle.Location = [System.Drawing.Point]::new(30, 49)
[void]$header.Controls.Add($subtitle)

$version = New-Object System.Windows.Forms.Label
$version.Text = $script:AppVersion
$version.ForeColor = [System.Drawing.Color]::FromArgb(148,163,184)
$version.AutoSize = $true
$version.Location = [System.Drawing.Point]::new(0, 31)
[void]$header.Controls.Add($version)

function Position-HeaderVersion {
    try {
        $version.Left = [Math]::Max(20, $header.ClientSize.Width - $version.Width - 28)
    }
    catch {}
}
$header.Add_Resize({ Position-HeaderVersion })

# Compact credential + action bar
# ---------------------------------------------------------------------------
# v3.0 enterprise layout:
#
#   HPE GreenLake credentials | Aruba Central credentials | 2x2 action buttons
#
# The credentials and buttons occupy the SAME horizontal band. The action
# buttons are arranged as:
#
#   [ Test Connections ] [ Run License Audit ]
#   [ Export View      ] [ Clear Results     ]
#
# This keeps the credential cards tall enough for both fields while avoiding
# a separate action row and reclaiming vertical space for the audit grid.
$connectionPanel = New-Object System.Windows.Forms.TableLayoutPanel
$connectionPanel.Dock = 'Fill'
$connectionPanel.Padding = [System.Windows.Forms.Padding]::new(14, 5, 14, 5)
$connectionPanel.ColumnCount = 3
$connectionPanel.RowCount = 1
[void]$connectionPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 36.0))
[void]$connectionPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 36.0))
[void]$connectionPanel.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 28.0))
[void]$connectionPanel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100.0))

function New-CredentialGroupCompact {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$EndpointText
    )

    # Use a nested TableLayoutPanel instead of absolute Y coordinates.
    # This is important with WinForms DPI scaling: the label and TextBox must
    # stay vertically aligned when Windows/CyberArk applies DPI scaling.
    $group = New-Object System.Windows.Forms.Panel
    $group.Dock = 'Fill'
    $group.Margin = [System.Windows.Forms.Padding]::new(3, 0, 5, 0)
    $group.Padding = [System.Windows.Forms.Padding]::new(8, 4, 8, 4)
    $group.BackColor = [System.Drawing.Color]::White
    $group.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $group.MinimumSize = [System.Drawing.Size]::new(250, 92)

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Margin = [System.Windows.Forms.Padding]::Empty
    $layout.Padding = [System.Windows.Forms.Padding]::Empty
    $layout.ColumnCount = 2
    $layout.RowCount = 3
    $layout.BackColor = [System.Drawing.Color]::White

    [void]$layout.ColumnStyles.Add(
        [System.Windows.Forms.ColumnStyle]::new(
            [System.Windows.Forms.SizeType]::Absolute, 92
        )
    )
    [void]$layout.ColumnStyles.Add(
        [System.Windows.Forms.ColumnStyle]::new(
            [System.Windows.Forms.SizeType]::Percent, 100
        )
    )

    [void]$layout.RowStyles.Add(
        [System.Windows.Forms.RowStyle]::new(
            [System.Windows.Forms.SizeType]::Absolute, 22
        )
    )
    [void]$layout.RowStyles.Add(
        [System.Windows.Forms.RowStyle]::new(
            [System.Windows.Forms.SizeType]::Percent, 50
        )
    )
    [void]$layout.RowStyles.Add(
        [System.Windows.Forms.RowStyle]::new(
            [System.Windows.Forms.SizeType]::Percent, 50
        )
    )

    # Header
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = 'Fill'
    $header.Margin = [System.Windows.Forms.Padding]::Empty

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.Dock = 'Left'
    $titleLabel.AutoSize = $true
    $titleLabel.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 10.2)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
    $titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    [void]$header.Controls.Add($titleLabel)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = 'Not Tested'
    $status.Dock = 'Right'
    $status.AutoSize = $true
    $status.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 8.5)
    $status.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
    $status.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    [void]$header.Controls.Add($status)

    [void]$layout.Controls.Add($header, 0, 0)
    $layout.SetColumnSpan($header, 2)

    # Common field label settings
    $labelFont = [System.Drawing.Font]::new('Segoe UI', 10.0)
    $inputFont = [System.Drawing.Font]::new('Segoe UI', 11.0)

    $label1 = New-Object System.Windows.Forms.Label
    $label1.Text = 'Client ID'
    $label1.Dock = 'Fill'
    $label1.AutoSize = $false
    $label1.AutoEllipsis = $false
    $label1.Font = $labelFont
    $label1.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)
    $label1.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label1.Margin = [System.Windows.Forms.Padding]::new(0, 0, 5, 0)
    [void]$layout.Controls.Add($label1, 0, 1)

    $idBox = New-Object System.Windows.Forms.TextBox
    $idBox.Dock = 'Fill'
    $idBox.Margin = [System.Windows.Forms.Padding]::new(0, 1, 0, 1)
    $idBox.Font = $inputFont
    $idBox.MinimumSize = [System.Drawing.Size]::new(100, 29)
    $idBox.Height = 29
    $idBox.AutoSize = $false
    $idBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
    [void]$layout.Controls.Add($idBox, 1, 1)

    $label2 = New-Object System.Windows.Forms.Label
    $label2.Text = 'Secret'
    $label2.Dock = 'Fill'
    $label2.AutoSize = $false
    $label2.AutoEllipsis = $false
    $label2.Font = $labelFont
    $label2.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)
    $label2.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label2.Margin = [System.Windows.Forms.Padding]::new(0, 0, 5, 0)
    [void]$layout.Controls.Add($label2, 0, 2)

    $secretBox = New-Object System.Windows.Forms.TextBox
    $secretBox.Dock = 'Fill'
    $secretBox.Margin = [System.Windows.Forms.Padding]::new(0, 1, 0, 1)
    $secretBox.Font = $inputFont
    $secretBox.MinimumSize = [System.Drawing.Size]::new(100, 29)
    $secretBox.Height = 29
    $secretBox.AutoSize = $false
    $secretBox.UseSystemPasswordChar = $true
    $secretBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
    [void]$layout.Controls.Add($secretBox, 1, 2)

    [void]$group.Controls.Add($layout)

    $tip = New-Object System.Windows.Forms.ToolTip
    $tip.SetToolTip($titleLabel, $EndpointText)
    $tip.SetToolTip($group, $EndpointText)

    return [PSCustomObject]@{
        Group = $group
        ClientId = $idBox
        ClientSecret = $secretBox
        Status = $status
    }
}

$glCard = New-CredentialGroupCompact -Title 'HPE GreenLake' -EndpointText 'Device inventory API configured internally'
$arubaCard = New-CredentialGroupCompact -Title 'Aruba Central' -EndpointText 'Inventory and monitored-device APIs configured internally'

$script:txtGLClientId = $glCard.ClientId
$script:txtGLClientSecret = $glCard.ClientSecret
$script:lblGreenLakeConnection = $glCard.Status
$script:txtArubaClientId = $arubaCard.ClientId
$script:txtArubaClientSecret = $arubaCard.ClientSecret
$script:lblArubaConnection = $arubaCard.Status

# Action buttons occupy the SAME row as the two credential cards.
# A 2x2 TableLayoutPanel guarantees that every button remains visible
# without relying on FlowLayoutPanel wrapping behavior.
$actions = New-Object System.Windows.Forms.TableLayoutPanel
$actions.Dock = 'Fill'
$actions.Margin = [System.Windows.Forms.Padding]::new(2, 0, 2, 0)
$actions.Padding = [System.Windows.Forms.Padding]::new(0, 1, 0, 1)
$actions.ColumnCount = 2
$actions.RowCount = 2
$actions.BackColor = [System.Drawing.Color]::Transparent
[void]$actions.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 50.0))
[void]$actions.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 50.0))
[void]$actions.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 50.0))
[void]$actions.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 50.0))

function New-CompactButton {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][System.Drawing.Color]$Color
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = [System.Drawing.Size]::new($Width, 31)
    $button.Margin = [System.Windows.Forms.Padding]::new(2, 2, 2, 2)
    $button.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 8.8)
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = $Color
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $button.UseCompatibleTextRendering = $true
    $button.Dock = 'Fill'
    return $button
}

$script:btnTestConnections = New-CompactButton 'Test Connections' 140 ([System.Drawing.Color]::FromArgb(37,99,235))
$script:btnRunAudit = New-CompactButton 'Run License Audit' 150 ([System.Drawing.Color]::FromArgb(15,118,110))
$script:btnExport = New-CompactButton 'Export View' 120 ([System.Drawing.Color]::FromArgb(22,163,74))
$script:btnClear = New-CompactButton 'Clear Results' 120 ([System.Drawing.Color]::FromArgb(71,85,105))
$script:btnExport.Enabled = $false

[void]$actions.Controls.Add($script:btnTestConnections, 0, 0)
[void]$actions.Controls.Add($script:btnRunAudit, 1, 0)
[void]$actions.Controls.Add($script:btnExport, 0, 1)
[void]$actions.Controls.Add($script:btnClear, 1, 1)

[void]$connectionPanel.Controls.Add($glCard.Group, 0, 0)
[void]$connectionPanel.Controls.Add($arubaCard.Group, 1, 0)
[void]$connectionPanel.Controls.Add($actions, 2, 0)

# Dedicated progress row.  The status text and progress bar share one stable row
# so progress remains visible at restored and maximized sizes.
$progressPanel = New-Object System.Windows.Forms.Panel
$progressPanel.Dock = 'Fill'
$progressPanel.Padding = [System.Windows.Forms.Padding]::new(14, 4, 14, 4)
$progressPanel.BackColor = [System.Drawing.Color]::FromArgb(241,245,249)

$script:lblProgress = New-Object System.Windows.Forms.Label
$script:lblProgress.Text = 'Ready'
$script:lblProgress.AutoSize = $false
$script:lblProgress.Font = [System.Drawing.Font]::new('Segoe UI', 9)
$script:lblProgress.ForeColor = [System.Drawing.Color]::FromArgb(71,85,105)
$script:lblProgress.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$script:lblProgress.Location = [System.Drawing.Point]::new(14, 5)
$script:lblProgress.Size = [System.Drawing.Size]::new(430, 28)
$progressTip = New-Object System.Windows.Forms.ToolTip
$progressTip.SetToolTip($script:lblProgress, '')
[void]$progressPanel.Controls.Add($script:lblProgress)

$script:progressBar = New-Object System.Windows.Forms.ProgressBar
$script:progressBar.Style = 'Continuous'
$script:progressBar.Minimum = 0
$script:progressBar.Maximum = 100
$script:progressBar.Location = [System.Drawing.Point]::new(455, 9)
$script:progressBar.Size = [System.Drawing.Size]::new(500, 20)
$script:progressBar.Anchor = 'Top,Left,Right'
$script:progressBar.Visible = $false
[void]$progressPanel.Controls.Add($script:progressBar)

$script:lblProgressPercent = New-Object System.Windows.Forms.Label
$script:lblProgressPercent.Text = ''
$script:lblProgressPercent.AutoSize = $false
$script:lblProgressPercent.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 8.5)
$script:lblProgressPercent.ForeColor = [System.Drawing.Color]::FromArgb(71,85,105)
$script:lblProgressPercent.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$script:lblProgressPercent.Location = [System.Drawing.Point]::new(960, 5)
$script:lblProgressPercent.Size = [System.Drawing.Size]::new(60, 28)
$script:lblProgressPercent.Anchor = 'Top,Left'
[void]$progressPanel.Controls.Add($script:lblProgressPercent)

function Position-ProgressBar {
    try {
        $usable = [Math]::Max(220, $progressPanel.ClientSize.Width - 455 - 80)
        $script:progressBar.Left = 455
        $script:progressBar.Width = $usable
        $script:lblProgressPercent.Left = 455 + $usable + 8
        $script:lblProgressPercent.Width = 52
    }
    catch {}
}
$progressPanel.Add_Resize({ Position-ProgressBar })

# Dashboard - compact, left-aligned and responsive.
$dashboardHost = New-Object System.Windows.Forms.Panel
$dashboardHost.Dock = 'Fill'
$dashboardHost.Padding = [System.Windows.Forms.Padding]::new(14, 3, 14, 3)

$dashboardStack = New-Object System.Windows.Forms.TableLayoutPanel
$dashboardStack.Dock = 'Fill'
$dashboardStack.Margin = [System.Windows.Forms.Padding]::Empty
$dashboardStack.Padding = [System.Windows.Forms.Padding]::Empty
$dashboardStack.ColumnCount = 1
$dashboardStack.RowCount = 3
$dashboardStack.BackColor = [System.Drawing.Color]::Transparent
[void]$dashboardStack.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 72))
[void]$dashboardStack.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 72))
[void]$dashboardStack.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 72))

function New-DashboardRow {
    $row = New-Object System.Windows.Forms.FlowLayoutPanel
    $row.Dock = 'Fill'
    $row.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $row.WrapContents = $false
    $row.AutoScroll = $false
    $row.AutoSize = $false
    $row.Margin = [System.Windows.Forms.Padding]::Empty
    $row.Padding = [System.Windows.Forms.Padding]::Empty
    $row.BackColor = [System.Drawing.Color]::Transparent
    return $row
}

$row1 = New-DashboardRow
$row2 = New-DashboardRow
$row3 = New-DashboardRow
[void]$dashboardStack.Controls.Add($row1, 0, 0)
[void]$dashboardStack.Controls.Add($row2, 0, 1)
[void]$dashboardStack.Controls.Add($row3, 0, 2)
[void]$dashboardHost.Controls.Add($dashboardStack)

$script:tileGL = New-DashboardTile 'GreenLake Inventory' 'GreenLake' -Accent ([System.Drawing.Color]::FromArgb(37,99,235)) -Parent $row1
$script:tileArubaInventory = New-DashboardTile 'Central Inventory' 'ArubaInventory' -Accent ([System.Drawing.Color]::FromArgb(124,58,237)) -Parent $row1
$script:tileArubaMonitored = New-DashboardTile 'Central Monitored' 'ArubaMonitored' -Accent ([System.Drawing.Color]::FromArgb(14,116,144)) -Parent $row1
$script:tileLicensed = New-DashboardTile 'GL - Licensed Devices' 'Licensed' -Accent ([System.Drawing.Color]::FromArgb(22,163,74)) -Parent $row1
$script:tileUnlicensed = New-DashboardTile 'GL - Without License' 'Unlicensed' -Accent ([System.Drawing.Color]::FromArgb(202,138,4)) -Parent $row1
$script:tileExpired = New-DashboardTile 'GL - Expired License' 'Expired' -Accent ([System.Drawing.Color]::FromArgb(220,38,38)) -Parent $row1

$script:tileNotProvisioned = New-DashboardTile 'Licensed - Not Provisioned' 'NotProvisioned' -Accent ([System.Drawing.Color]::FromArgb(202,138,4)) -Parent $row2
$script:tileLicensedNotInMonitored = New-DashboardTile 'Licensed - Not in Monitored' 'LicensedNotInMonitored' -Accent ([System.Drawing.Color]::FromArgb(220,38,38)) -Parent $row2
$script:tileCentralNotMonitored = New-DashboardTile 'Central - Not Monitored' 'CentralNotMonitored' -Accent ([System.Drawing.Color]::FromArgb(220,38,38)) -Parent $row2
$script:tileGLUnlicensedCentralMonitored = New-DashboardTile 'GL Unlicensed - Monitored' 'GLUnlicensedCentralMonitored' -Accent ([System.Drawing.Color]::FromArgb(180,83,9)) -Parent $row2

$script:tileAP = New-DashboardTile 'Access Points' 'AccessPoint' -Accent ([System.Drawing.Color]::FromArgb(37,99,235)) -Parent $row3
$script:tileSwitch = New-DashboardTile 'Switches' 'Switch' -Accent ([System.Drawing.Color]::FromArgb(124,58,237)) -Parent $row3
$script:tileGateway = New-DashboardTile 'Gateways' 'Gateway' -Accent ([System.Drawing.Color]::FromArgb(14,116,144)) -Parent $row3

# Responsive dashboard tiles: keep six columns on one row while preserving readable captions.
$tileCaptionTip = New-Object System.Windows.Forms.ToolTip
$dashboardTileRefs = @(
    $script:tileGL, $script:tileArubaInventory, $script:tileArubaMonitored,
    $script:tileLicensed, $script:tileUnlicensed, $script:tileExpired,
    $script:tileNotProvisioned, $script:tileLicensedNotInMonitored,
    $script:tileCentralNotMonitored, $script:tileGLUnlicensedCentralMonitored,
    $script:tileAP, $script:tileSwitch, $script:tileGateway
)

foreach ($tileRef in $dashboardTileRefs) {
    $tileRef.Panel.Dock = 'None'
    $tileRef.Panel.Anchor = 'Top,Left'
    $tileRef.Panel.Size = [System.Drawing.Size]::new(235, 68)
    $tileRef.Panel.Margin = [System.Windows.Forms.Padding]::new(0, 2, 8, 2)
    $tileRef.CaptionLabel.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
    $tileRef.CaptionLabel.AutoEllipsis = $true
    try { $tileCaptionTip.SetToolTip($tileRef.CaptionLabel, $tileRef.CaptionLabel.Text) } catch {}
    $tileRef.CaptionLabel.Location = [System.Drawing.Point]::new(12, 5)
    $tileRef.CaptionLabel.Height = 24
    $tileRef.CaptionLabel.Width = 211
    $tileRef.ValueLabel.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 15.5)
    $tileRef.ValueLabel.Location = [System.Drawing.Point]::new(12, 30)
    $tileRef.SubLabel.Location = [System.Drawing.Point]::new(10, 53)
    $tileRef.SubLabel.Size = [System.Drawing.Size]::new(215, 12)
    $tileRef.SubLabel.Font = [System.Drawing.Font]::new('Segoe UI', 7.2)
}

function Update-ResponsiveLayout {
    try {
        if ($null -eq $script:frm -or $script:frm.IsDisposed) { return }
        $width = [Math]::Max(900, $script:frm.ClientSize.Width)
        $height = [Math]::Max(560, $script:frm.ClientSize.Height)

        # IMPORTANT for RDP / CyberArk HTML5 sessions:
        # Do not shrink the vertical layout just because the browser viewport
        # is scaled. Windows Forms DPI scaling already handles DPI. A second
        # height-based scale causes text and controls to be clipped in HTML5
        # remote-desktop sessions (for example 1912x984 rendered into a smaller
        # browser canvas). Keep content-bearing sections at their safe heights
        # and let the Results area absorb the remaining space.
        $headerH = 76
        $credH   = 96
        $tileH   = 68
        $rowH    = 72
        $dashH   = 228

        # Keep the audit log compact only on genuinely short desktop heights;
        # the dashboard/header/credentials are never compressed below their
        # content-safe dimensions.
        $logH = if ($height -lt 800) { 60 } else { 78 }

        for ($i = 0; $i -lt 3; $i++) { $dashboardStack.RowStyles[$i].Height = $rowH }

        $root.RowStyles[0].Height = $headerH
        $root.RowStyles[1].Height = $credH
        $root.RowStyles[2].Height = 42
        $root.RowStyles[3].Height = $dashH
        $root.RowStyles[5].Height = $logH

        $available = [Math]::Max(900, $dashboardHost.ClientSize.Width - 2)
        $tileWidth = [int][Math]::Floor(($available - (5 * 8)) / 6)
        $tileWidth = [Math]::Max(175, [Math]::Min(235, $tileWidth))

        foreach ($tileRef in $dashboardTileRefs) {
            $tileRef.Panel.Width = $tileWidth
            $tileRef.Panel.Height = $tileH
            $tileRef.CaptionLabel.Width = [Math]::Max(145, $tileWidth - 24)
            $tileRef.CaptionLabel.Height = 24
            $tileRef.CaptionLabel.Font = [System.Drawing.Font]::new('Segoe UI', 8.5)
            $tileRef.ValueLabel.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 15.5)
            $tileRef.ValueLabel.Location = [System.Drawing.Point]::new(12, 30)
            $tileRef.SubLabel.Location = [System.Drawing.Point]::new(10, 53)
            $tileRef.SubLabel.Size = [System.Drawing.Size]::new([Math]::Max(40, $tileWidth - 20), 12)
        }

        Position-ProgressBar
        Position-ResultToolbar
        Position-ViewHeader
        Position-HeaderVersion
    }
    catch {}
}

$dashboardHost.Add_Resize({ Update-ResponsiveLayout })
$script:frm.Add_Resize({
    try { Update-ResponsiveLayout } catch {}
})

# Results / grid area
$resultsPanel = New-Object System.Windows.Forms.TableLayoutPanel
$resultsPanel.Dock = 'Fill'
$resultsPanel.Padding = [System.Windows.Forms.Padding]::new(14, 5, 14, 5)
$resultsPanel.ColumnCount = 1
$resultsPanel.RowCount = 2
[void]$resultsPanel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Absolute, 38))
[void]$resultsPanel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))

$viewBar = New-Object System.Windows.Forms.Panel
$viewBar.Dock = 'Fill'

$script:lblViewTitle = New-Object System.Windows.Forms.Label
$script:lblViewTitle.Text = 'All Audit Results'
$script:lblViewTitle.Font = [System.Drawing.Font]::new('Segoe UI Semibold', 11.5)
$script:lblViewTitle.AutoSize = $true
$script:lblViewTitle.Location = [System.Drawing.Point]::new(0, 6)
$script:lblViewTitle.ForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
[void]$viewBar.Controls.Add($script:lblViewTitle)

$script:lblRecordCount = New-Object System.Windows.Forms.Label
$script:lblRecordCount.Text = 'Records: 0'
$script:lblRecordCount.AutoSize = $true
$script:lblRecordCount.Location = [System.Drawing.Point]::new(0, 8)
$script:lblRecordCount.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)
[void]$viewBar.Controls.Add($script:lblRecordCount)

$script:btnShowAll = New-Object System.Windows.Forms.Button
$script:btnShowAll.Text = 'Show All Audit Results'
$script:btnShowAll.Size = [System.Drawing.Size]::new(205, 30)
$script:btnShowAll.Font = [System.Drawing.Font]::new('Segoe UI', 9.2)
$script:btnShowAll.FlatStyle = 'Flat'
$script:btnShowAll.FlatAppearance.BorderSize = 1
$script:btnShowAll.BackColor = [System.Drawing.Color]::White
$script:btnShowAll.ForeColor = [System.Drawing.Color]::FromArgb(51,65,85)
[void]$viewBar.Controls.Add($script:btnShowAll)

$script:txtSearch = New-Object System.Windows.Forms.TextBox
$script:txtSearch.Size = [System.Drawing.Size]::new(320, 30)
$script:txtSearch.Font = $fontSmall
$searchTip = New-Object System.Windows.Forms.ToolTip
$searchTip.SetToolTip($script:txtSearch, 'Search serial, MAC, model, device name or site')
[void]$viewBar.Controls.Add($script:txtSearch)

function Position-ResultToolbar {
    try {
        $rightEdge = $viewBar.ClientSize.Width - 4
        if ($viewBar.ClientSize.Width -lt 1000) {
            $script:btnShowAll.Width = 180
            $script:txtSearch.Width = 250
        }
        else {
            $script:btnShowAll.Width = 205
            $script:txtSearch.Width = 320
        }
        $script:btnShowAll.Left = [Math]::Max(0, $rightEdge - $script:btnShowAll.Width)
        $script:btnShowAll.Top = 2
        $script:txtSearch.Left = [Math]::Max(0, $script:btnShowAll.Left - 10 - $script:txtSearch.Width)
        $script:txtSearch.Top = 2
    }
    catch {}
}

function Position-ViewHeader {
    try { $script:lblRecordCount.Left = $script:lblViewTitle.Right + 12 } catch {}
}
$viewBar.Add_Resize({ Position-ResultToolbar; Position-ViewHeader })

[void]$resultsPanel.Controls.Add($viewBar, 0, 0)

$gridGroup = New-Object System.Windows.Forms.GroupBox
$gridGroup.Text = ' Inventory / Audit Results '
$gridGroup.Font = $fontSection
$gridGroup.Dock = 'Fill'
$gridGroup.BackColor = [System.Drawing.Color]::White
$gridGroup.Padding = [System.Windows.Forms.Padding]::new(3, 5, 3, 3)

$script:grid = New-Object System.Windows.Forms.DataGridView
$script:grid.Dock = 'Fill'
$script:grid.ReadOnly = $false
$script:grid.AllowUserToAddRows = $false
$script:grid.AllowUserToDeleteRows = $false
$script:grid.AllowUserToResizeRows = $false
$script:grid.RowHeadersVisible = $false
$script:grid.MultiSelect = $true
$script:grid.SelectionMode = 'CellSelect'
$script:grid.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditProgrammatically
$script:grid.StandardTab = $true
$script:grid.AutoGenerateColumns = $true
$script:grid.AutoSizeColumnsMode = 'DisplayedCells'
$script:grid.EnableHeadersVisualStyles = $false
$script:grid.BackgroundColor = [System.Drawing.Color]::White
$script:grid.BorderStyle = 'None'
$script:grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(15,23,42)
$script:grid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$script:grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
$script:grid.ColumnHeadersHeight = 30
$script:grid.DefaultCellStyle.Font = $fontSmall
$script:grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(219,234,254)
$script:grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
$script:grid.RowTemplate.Height = 25

$script:grid.Add_CellDoubleClick({
    param($sender, $eventArgs)
    if ($eventArgs.RowIndex -ge 0 -and $eventArgs.ColumnIndex -ge 0) {
        try {
            $script:grid.CurrentCell = $script:grid.Rows[$eventArgs.RowIndex].Cells[$eventArgs.ColumnIndex]
            $null = $script:grid.BeginEdit($true)
        } catch {}
    }
})

$script:grid.Add_EditingControlShowing({
    param($sender, $eventArgs)
    $editBox = $eventArgs.Control
    if ($editBox -is [System.Windows.Forms.TextBox]) {
        $editBox.ReadOnly = $true
        $editBox.ShortcutsEnabled = $true
        $editBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
        $editBox.BackColor = [System.Drawing.Color]::White
        $editBox.ForeColor = [System.Drawing.Color]::FromArgb(15,23,42)
    }
})

$cellMenu = New-Object System.Windows.Forms.ContextMenuStrip
$copyCell = $cellMenu.Items.Add('Copy Cell')
$copyRow = $cellMenu.Items.Add('Copy Row')
$copyCell.Add_Click({
    if ($script:grid.CurrentCell) { [System.Windows.Forms.Clipboard]::SetText([string]$script:grid.CurrentCell.Value) }
})
$copyRow.Add_Click({
    if ($script:grid.CurrentCell) {
        $rowIndex = $script:grid.CurrentCell.RowIndex
        if ($rowIndex -ge 0) {
            $values = foreach ($cell in $script:grid.Rows[$rowIndex].Cells) { [string]$cell.Value }
            [System.Windows.Forms.Clipboard]::SetText(($values -join "`t"))
        }
    }
})
$script:grid.ContextMenuStrip = $cellMenu

$gridTip = New-Object System.Windows.Forms.ToolTip
$gridTip.SetToolTip($script:grid, 'Double-click a cell to select text. Use Ctrl+C or right-click to copy.')
[void]$gridGroup.Controls.Add($script:grid)
[void]$resultsPanel.Controls.Add($gridGroup, 0, 1)

# Audit log
$logGroup = New-Object System.Windows.Forms.GroupBox
$logGroup.Text = ' Audit Log '
$logGroup.Font = $fontSection
$logGroup.Dock = 'Fill'
$logGroup.BackColor = [System.Drawing.Color]::White
$logGroup.Padding = [System.Windows.Forms.Padding]::new(3, 5, 3, 3)

$script:txtLog = New-Object System.Windows.Forms.RichTextBox
$script:txtLog.Dock = 'Fill'
$script:txtLog.ReadOnly = $true
$script:txtLog.BorderStyle = 'None'
$script:txtLog.BackColor = [System.Drawing.Color]::FromArgb(248,250,252)
$script:txtLog.Font = [System.Drawing.Font]::new('Consolas', 8.5)
$script:txtLog.Padding = [System.Windows.Forms.Padding]::new(6)
[void]$logGroup.Controls.Add($script:txtLog)

# Bottom status bar is outside the root table so it cannot be consumed by the
# flexible results row when the form is maximised/restored.
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

$logPath = New-Object System.Windows.Forms.ToolStripStatusLabel
$logPath.Text = "Log: $([System.IO.Path]::GetFileName($script:LogFile))"
$logPath.ToolTipText = "Log: $script:LogFile"
$logPath.ForeColor = [System.Drawing.Color]::FromArgb(100,116,139)

[void]$statusStrip.Items.Add($script:statusIndicator)
[void]$statusStrip.Items.Add($script:lblStatus)
[void]$statusStrip.Items.Add($logSpring)
[void]$statusStrip.Items.Add($logPath)

[void]$root.Controls.Add($header, 0, 0)
[void]$root.Controls.Add($connectionPanel, 0, 1)
[void]$root.Controls.Add($progressPanel, 0, 2)
[void]$root.Controls.Add($dashboardHost, 0, 3)
[void]$root.Controls.Add($resultsPanel, 0, 4)
[void]$root.Controls.Add($logGroup, 0, 5)
[void]$script:frm.Controls.Add($root)
[void]$script:frm.Controls.Add($statusStrip)

Update-ResponsiveLayout
$script:progressBar.Visible = $false
$script:lblProgressPercent.Text = ''
Position-ResultToolbar
Position-ViewHeader

# ---------------------------------------------------------------------------
# Search / grid helpers
# ---------------------------------------------------------------------------

$script:SearchTimer = New-Object System.Windows.Forms.Timer
$script:SearchTimer.Interval = 600

function Invoke-CurrentSearch {
    $script:SearchTimer.Stop()

    if ($script:CurrentView -eq 'GreenLake') {
        $base = @(Get-ViewObjects -View GreenLake)
    }
    elseif ($script:CurrentView -eq 'ArubaInventory') {
        $base = @(Get-ViewObjects -View ArubaInventory)
    }
    elseif ($script:CurrentView -eq 'ArubaMonitored') {
        $base = @(Get-ViewObjects -View ArubaMonitored)
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

    $properties = @(Get-ViewProperties -View $script:CurrentView)

    $searchTable = New-DataTableFromObjects `
        -Items $base `
        -Properties $properties

    $script:grid.SuspendLayout()
    try {
        $script:grid.DataSource = $null
        $script:grid.Columns.Clear()
        $script:grid.AutoGenerateColumns = $true
        $script:grid.DataSource = $searchTable
        $script:grid.Refresh()
        $script:grid.Invalidate()
    }
    finally {
        $script:grid.ResumeLayout()
    }

    $script:lblRecordCount.Text = "Records: $($base.Count)"

    Write-AuditLog DEBUG `
        "Search applied: view='$script:CurrentView'; term='$term'; results=$($base.Count)."
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
Write-AuditLog INFO 'Dedicated runspace worker initialized for Windows PowerShell 5.1 / ISE.'
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

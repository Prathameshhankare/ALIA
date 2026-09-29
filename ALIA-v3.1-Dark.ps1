#requires -Version 5.1

<##
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
    $splash.ShowInTaskbar = $false
    $splash.TopMost = $true
    $splash.DoubleBuffered = $true
    $splash.BackColor = [System.Drawing.Color]::FromArgb(15,23,42)

    $splash.Add_Paint({
        param($sender, $paintArgs)
        $graphics = $paintArgs.Graphics
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

        $rect = [System.Drawing.Rectangle]::new(0, 0, $sender.ClientSize.Width, $sender.ClientSize.Height)
        $topColor = [System.Drawing.Color]::FromArgb(15,23,42)
        $bottomColor = [System.Drawing.Color]::FromArgb(30,41,59)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $topColor, $bottomColor, 35)
        $graphics.FillRectangle($brush, $rect)
        $brush.Dispose()

        # Accent panel
        $graphics.FillRectangle([System.Drawing.Brushes]::White, [System.Drawing.Rectangle]::new(36, 48, 6, 190))

        # Stylized ALIA network mark - generated entirely in code.
        $nodeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(56,189,248))
        $nodeBrush2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45,212,191))
        $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100,116,139), 2)
        $graphics.DrawLine($linePen, 94, 83, 138, 58)
        $graphics.DrawLine($linePen, 138, 58, 168, 86)
        $graphics.DrawLine($linePen, 138, 58, 138, 112)
        $graphics.DrawLine($linePen, 138, 112, 106, 139)
        $graphics.DrawLine($linePen, 138, 112, 169, 139)
        $graphics.FillEllipse($nodeBrush, 88, 77, 12, 12)
        $graphics.FillEllipse($nodeBrush2, 132, 52, 12, 12)
        $graphics.FillEllipse($nodeBrush, 162, 80, 12, 12)
        $graphics.FillEllipse($nodeBrush2, 132, 106, 12, 12)
        $graphics.FillEllipse($nodeBrush, 100, 133, 12, 12)
        $graphics.FillEllipse($nodeBrush2, 163, 133, 12, 12)
        $linePen.Dispose()
        $nodeBrush.Dispose()
        $nodeBrush2.Dispose()

        $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $muted = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148,163,184))
        $accent = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(56,189,248))
        $brandFont = New-Object System.Drawing.Font('Segoe UI', 30, [System.Drawing.FontStyle]::Bold)
        $titleFont = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Regular)
        $bodyFont = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Regular)
        $smallFont = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)

        $graphics.DrawString('ALIA', $brandFont, $white, 215, 62)
        $graphics.DrawString('Aruba License Inventory Audit', $titleFont, $white, 215, 112)
        $graphics.DrawString('HPE GreenLake + Aruba Central reconciliation', $bodyFont, $muted, 216, 153)
        $graphics.DrawString('Inventory  •  Licensing  •  Monitoring  •  Audit', $smallFont, $accent, 216, 182)
        $graphics.DrawString('Developed by Prathamesh Hankare', $smallFont, $muted, 216, 246)
        $graphics.DrawString('Version 3.1', $smallFont, $muted, 216, 268)

        $progressPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(51,65,85), 1)
        $graphics.DrawRectangle($progressPen, 216, 296, 330, 5)
        $progressPen.Dispose()
        $graphics.FillRectangle($accent, 216, 296, 82, 5)

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
    Start-Sleep -Milliseconds 250
    [System.Windows.Forms.Application]::DoEvents()
    return $splash
}

# The remainder of this file is the exact user-provided ALIA v3.1 dark-mode script.
# It is intentionally stored as a standalone PowerShell application so it can be
# tested independently from ALIA-DarkTheme.ps1.


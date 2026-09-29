# ALIA v3.1

ALIA v3.1 introduces the Audit Workspace GUI redesign while preserving the v3.0 API and reconciliation engine.

## GUI changes

- Audit health summary with Healthy / Warning / Critical counts
- Reconciliation coverage metric
- Six compact KPI cards with audit-over-audit trend indicators
- Primary Run License Audit workflow
- Connection cards with status and show/hide secret controls
- Simplified Audit Status filtering with one dropdown instead of status buttons
- Search plus Audit Status / Health / Device Type filters
- Read-only, full-row audit grid with frozen identity columns
- Device detail pane showing GreenLake, Central, monitoring and audit state
- Copy Cell / Row / Serial / MAC actions
- Collapsible audit log
- Audit history stored under the current user's LocalApplicationData
- Audit history dialog with previous-run metrics
- Status bar showing last audit, duration and reconciliation coverage
- Reduced splash-screen delay
- Enterprise-oriented responsive workspace layout
- Keyboard shortcuts: F5 runs an audit; Ctrl+L toggles the log

## Compatibility

- Windows
- Windows PowerShell 5.1
- PowerShell ISE
- PS2EXE for EXE packaging

## Files

- `ALIA-v3.1.ps1` - v3.1 application
- `Build-ALIA-v3.1.ps1` - v3.1 EXE builder
- `ALIA-v3.0.ps1` - retained legacy application
- `Build-ALIA-v3.0.ps1` - retained legacy builder

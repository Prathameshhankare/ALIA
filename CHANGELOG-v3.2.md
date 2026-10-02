# ALIA v3.2 — DPI & Responsive GUI Fix

## Purpose

v3.2 keeps the v3.1 visual design and audit behavior while hardening the WinForms layout for different Windows display scaling, DPI, resolutions, and viewport sizes.

## GUI compatibility changes

- Added best-effort Per-Monitor V2 DPI awareness for the ALIA UI thread, with fallbacks for older Windows environments.
- Added runtime DPI detection and a shared 96-DPI design baseline.
- Scaled runtime layout coordinates and section heights from the actual window DPI.
- Added handling for the WinForms `DpiChanged` event so moving between differently scaled displays can trigger a fresh layout pass.
- Replaced rigid credential-card columns/rows with percentage-based layout.
- Made Audit Health geometry responsive to the available card size.
- Made KPI rows responsive and KPI card contents resize with the card width.
- Made the toolbar/search area responsive to narrow viewports.
- Scaled workspace minimum pane widths and retained a safe fallback for smaller/RDP viewports.
- Made Device Details header geometry responsive.
- Made the progress row responsive.
- Enabled DPI autoscaling explicitly for secondary filter/history dialogs.
- Scaled Audit History column widths using the active UI DPI.
- Added effective DPI-scale information to the ALIA audit log for troubleshooting.

## Compatibility target

The v3.2 layout is intended to behave consistently across:

- Windows 11 at 100%, 125%, 150% and 200% display scaling.
- Different screen resolutions and laptop/external monitor combinations.
- Smaller/RDP-style viewports.
- Windows PowerShell 5.1 / WinForms.
- PS2EXE 64-bit GUI builds.

## Regression protection

The v3.1 source and builder remain available on the `v3.1` branch. The `v3.2` branch contains these v3.2 files:

- `ALIA-v3.2.ps1`
- `Build-ALIA-v3.2.ps1`

No audit/reconciliation logic was intentionally changed as part of this GUI compatibility work.

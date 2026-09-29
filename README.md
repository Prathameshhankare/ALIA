# ALIA

## Aruba License Inventory Audit

**ALIA (Aruba License Inventory Audit)** is an enterprise-oriented Windows PowerShell application for reconciling **HPE GreenLake device inventory and licensing** with **Aruba Central inventory and monitoring state**.

The application is designed to help infrastructure and network teams identify devices whose GreenLake licensing and Aruba Central presence do not agree.

---

## What ALIA Does

ALIA currently provides the following workflow:

1. Test connectivity to HPE GreenLake and Aruba Central.
2. Retrieve the HPE GreenLake device inventory.
3. Retrieve Aruba Central device inventory.
4. Retrieve Aruba Central monitored-device information.
5. Match devices primarily by **serial number** and secondarily by **MAC address**.
6. Reconcile GreenLake licensing against Aruba Central inventory and monitoring state.
7. Highlight licensing and monitoring exceptions through dashboard views.
8. Display inventory totals and device-type counts for:
   - Access Points
   - Switches
   - Gateways
   - Other devices
9. Provide detailed audit logging.
10. Provide search/filtering and CSV export of the current audit view.

---

## Reconciliation Model

ALIA combines information from three logical data sets:

```text
                 HPE GreenLake
                      │
                      │ Device Inventory
                      ▼
              ┌───────────────┐
              │      ALIA     │
              │ Reconciliation│
              └───────────────┘
                 ▲     ▲     │
                 │     │     │ Monitoring
       Inventory │     │     ▼
                 │     │  Audit Results
          Aruba Central
```

The audit can identify conditions such as:

- GreenLake licensed devices
- GreenLake devices without a license
- Expired GreenLake licenses
- Licensed devices not provisioned in Central
- Licensed devices not present in the monitored-device data
- Central devices that are not monitored
- GreenLake-unlicensed devices that are monitored in Central

The dashboard counters provide a quick operational summary, while the audit grid provides device-level detail.

---

## Dashboard

The application provides dashboard counters for:

| Dashboard Item | Purpose |
|---|---|
| GreenLake Inventory | Total devices returned from GreenLake |
| Central Inventory | Total devices returned from Central inventory |
| Central Monitored | Total monitored devices returned from Central |
| GL - Licensed Devices | GreenLake devices with an active license |
| GL - Without License | GreenLake devices without a license |
| GL - Expired License | GreenLake devices with an expired license |
| Licensed - Not Provisioned | Licensed GreenLake devices not found in Central inventory |
| Licensed - Not in Monitored | Licensed devices not found in monitored-device data |
| Central - Not Monitored | Central inventory devices not found in monitored-device data |
| GL Unlicensed - Monitored | GreenLake-unlicensed devices that appear in monitored data |
| Access Points | GreenLake AP count, with Central comparison |
| Switches | GreenLake switch count, with Central comparison |
| Gateways | GreenLake gateway count, with Central comparison |

---

## Requirements

The current application targets:

- Windows
- **Windows PowerShell 5.1**
- Windows Forms
- Network access to the configured HPE GreenLake and Aruba Central API endpoints
- API client credentials for the respective services

The script is also documented as compatible with **PowerShell ISE**.

---

## Running ALIA

Run the PowerShell script from a Windows PowerShell 5.1 session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\ALIA-v3.0.ps1
```

The application prompts for the required **Client ID** and **Client Secret** values at runtime.

> Do not place client secrets directly into the PowerShell source code.

---

## Building the Windows EXE

The repository includes a production EXE builder:

```text
Build-ALIA-v3.0.ps1
```

The builder uses **PS2EXE** to compile `ALIA-v3.0.ps1` into a 64-bit, GUI-only Windows executable with DPI-aware metadata and an embedded application icon.

Run it from **Windows PowerShell 5.1**:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Build-ALIA-v3.0.ps1
```

If PS2EXE is not installed, the builder installs it for the current user automatically.

The resulting executable is created here:

```text
dist\ALIA-v3.0.exe
```

The `dist` directory and generated executable files are excluded from Git through `.gitignore`. The builder itself is version-controlled so a reproducible EXE can be generated from the repository source.

---

## Credential and Security Handling

ALIA is designed so that API credentials are supplied at runtime.

According to the application implementation:

- Client IDs and Client Secrets are entered through the GUI.
- Credentials are not written to the audit log.
- Credentials are not exported to CSV.
- API endpoints are configured internally by the application.
- Application audit logs are written to the `Logs` directory next to the application/script location when possible.

Before deploying ALIA in a production environment, review the script and the configured API endpoints against your organization's security and change-management requirements.

---

## Project Structure

```text
ALIA/
├── ALIA-v3.0.ps1          # Main Windows PowerShell application
├── Build-ALIA-v3.0.ps1    # Production EXE builder using PS2EXE
├── README.md              # Project documentation
├── LICENSE                # GPL-3.0 license
└── .gitignore             # Repository exclusions
```

Generated EXE/build output and runtime audit logs are intentionally excluded from Git.

---

## Version

**Current application version:** `v3.0.3`

The main application source remains named `ALIA-v3.0.ps1` because it represents the v3.0 application line.

The current v3.x release includes the redesigned dashboard layout, GreenLake/Central reconciliation workflow, audit views, logging, search and CSV export functionality.

---

## Development Notes

ALIA is implemented as a single PowerShell/Windows Forms application so it can be deployed in environments where installing a separate runtime or application framework is undesirable.

The application uses background execution/runspace handling for longer inventory operations so the GUI can remain responsive during API collection and reconciliation.

The dashboard and audit grid are intended to support operational review rather than replace the authoritative licensing or inventory systems.

---

## Repository

GitHub:

`https://github.com/PrathameshHankare/ALIA`

---

## Author

**Prathamesh Hankare**

Network & Security Engineering

---

## License

ALIA is distributed under the **GNU General Public License v3.0**. See [`LICENSE`](LICENSE) for the complete license text.


## ALIA v3.1 GUI Workspace

The v3.1 application is available as a redesigned workspace on the `v3.1-gui-redesign` branch.

Highlights include audit health, reconciliation coverage, compact KPI cards, audit-over-audit trends, quick views, advanced filters, problems-only mode, a read-only audit grid, device detail inspection, collapsible diagnostics, audit history, and a responsive enterprise layout.

Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\\ALIA-v3.1.ps1
```

Build the EXE:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\\Build-ALIA-v3.1.ps1
```

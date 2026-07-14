# ISO and software checklist

Download media only from the official pages below, record the selected edition, language,
version, URL, date, and SHA-256 value in your lab notebook before mounting anything. Keep the
original downloads outside the VM disks so the lab can be rebuilt predictably.

## Required media and installers

| Item | Official source | Lab use | Evaluation horizon |
|---|---|---|---|
| Windows Server 2025 Evaluation ISO | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025) | DC01, WDS01, CM01, and the unbooted parent VHDX | 180 days |
| Windows 11 Enterprise Evaluation ISO | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise) | REF01 and WDS install image | 90 days |
| Windows Server 2022 Evaluation ISO | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022) | Source of the standalone WDS `boot.wim` only | 180 days |
| SQL Server 2022 Evaluation | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-sql-server-2022) | CM01 default SQL instance | 180 days |
| SQL Server Management Studio | [Install SSMS](https://learn.microsoft.com/en-us/ssms/install/install) | SQL administration on CM01 | N/A |
| Configuration Manager Current Branch 2509 Eval | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-microsoft-endpoint-configuration-manager) | Site `HUF` | 180 days |
| Windows ADK 11, version 24H2 | [Download and install the ADK](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install) | CM01 deployment tooling | N/A |
| Windows PE add-on for the ADK | [Download and install the ADK](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install) | ConfigMgr WinPE boot images | N/A |
| Microsoft ODBC Driver 18 for SQL Server | [Microsoft ODBC Driver download](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server) | ConfigMgr prerequisite on CM01 | N/A |
| Latest Windows Server 2025 cumulative update | [Windows Server 2025 release health](https://learn.microsoft.com/en-us/windows/release-health/status-windows-server-2025) | Patch DC01 before promotion | Servicing lifecycle |

For the WDS phase, import the Server 2022 `boot.wim`; do not substitute a boot image copied
from Windows 11 or Windows Server 2025 installation media. Import the Windows 11 Enterprise
evaluation `install.wim` as the operating-system image. The WDS UI remains intentionally
interactive for this learning workflow: the `WindowsDeploymentServices` unattend settings do
not apply to Windows 11, as documented in [WindowsDeploymentServices](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-setup-windowsdeploymentservices).

## Integrity record

Use the checksum Microsoft publishes for the exact release whenever one is provided. When a
download page does not publish a hash, retain the Microsoft download URL and calculate a local
SHA-256 immediately after download; compare that recorded value before each rebuild.

```powershell
Get-FileHash -Algorithm SHA256 -Path 'D:\LabMedia\Windows_Server_2025.iso'
```

Record the full 64-character result—not a screenshot alone—in `docs/lab-notebook.md` or a
secure local build record. A matching local hash proves the file did not change between two
local copies; it does not independently establish publisher provenance, which is why the
official source URL remains part of the record.

## DC01 patch gate

Before promoting DC01, install **KB5060842 or a later cumulative update**, reboot, and verify
the installed build. Microsoft lists KB5060842 as the June 2025 cumulative update (build
26100.4349); consult the [Windows Server 2025 release-health page](https://learn.microsoft.com/en-us/windows/release-health/status-windows-server-2025)
for later servicing guidance. This lab's runbook treats the patch as a prerequisite to avoid
the documented post-reboot Public-network-profile behavior during initial DC setup.

```powershell
Get-HotFix -Id KB5060842
Get-ComputerInfo | Select-Object WindowsProductName, OsVersion, OsBuildNumber
```

If a later cumulative update supersedes KB5060842, document that KB and build instead. Do not
install a stale standalone update merely to make the first command return a particular ID.

## Expiry and rebuild plan

Evaluation media is disposable lab infrastructure. Windows Server, SQL Server, and
Configuration Manager evaluations have 180-day evaluation periods; Windows 11 Enterprise
Evaluation is 90 days. Confirm the current terms on the download page when downloading because
Microsoft can revise offerings and eligibility.

Plan a rebuild before the first evaluation expires:

1. Preserve the media inventory and SHA-256 record, scripts, runbooks, exported GPOs, WDS
   image metadata, ConfigMgr configuration notes, and lab evidence.
2. Export only learning artifacts that are safe to retain; never treat a rearm as a durable
   production licensing strategy. Do not rely on it as the standard lab lifecycle.
3. Recreate the parent VHDX from current evaluated media, rebuild server children, and replay
   the runbooks in phase order. Rebuild the ConfigMgr hierarchy rather than attempting an
   unsupported in-place extension of expired evaluation software.
4. Capture a fresh golden image after applying the current Windows updates and rerun the PXE
   handoff test.

This approach keeps the project reproducible and makes an expired evaluation a scheduled
practice exercise rather than a surprise outage.

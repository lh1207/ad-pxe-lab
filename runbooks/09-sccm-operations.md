# Phase 09 — SCCM ops: apps, patching, compliance

> **Resume bullet:** #3 · **Est. time:** 5–7 h · **VMs on:** DC01+CM01+one client (24 GB / 28 GB budget)

## Objectives

- Deliver 7-Zip as required and Notepad++ as available through ConfigMgr.
- Establish a manual update workflow, then an ADR and maintenance window.
- Deploy the `Workstation Security Baseline` with three compliance items.

## Prerequisites

- Phase 08 is verified. Keep only DC01, CM01, and one managed client (normally CL02) powered on:
  4 + 16 + 4 = 24 GB.
- Take checkpoints `Pre-Phase09-CM01` and `Pre-Phase09-CL02`. Obtain current 7-Zip 24.x x64 MSI
  and Notepad++ 8.x x64 installer from their publishers, validate hashes, and stage sources on
  CM01. Do not embed admin passwords; `LabP@ss2026!` remains an example only.

## Steps

1. In **Software Library** → **Application Management** → **Applications** → **Create
   Application**, select **Windows Installer (*.msi file)** and choose 7-Zip 24.x x64. Let
   ConfigMgr detect the MSI ProductCode, distribute the content to CM01 DP, and deploy as
   **Required** to `WKS-All`. 📸 Evidence: 7-Zip deployment type detection method and success
   state.

   PowerShell equivalent from the `HUF:` drive (inspect generated cmdlets before production use):

   ```powershell
   Set-Location HUF:
   New-CMApplication -Name '7-Zip 24.x (x64)' -Publisher '7-Zip' -SoftwareVersion '24.x'
   Add-CMMSIDeploymentType -ApplicationName '7-Zip 24.x (x64)' -DeploymentTypeName 'MSI' -ContentLocation '\\CM01\Sources\Apps\7-Zip' -InstallCommand 'msiexec /i 7z-x64.msi /qn'
   ```

2. Create Notepad++ 8.x x64 from **Create Application** → **Manually specify the application
   information**. Create an EXE deployment type with silent install command `/S`. Define manual
   detection using a stable installed file version or registry value, distribute to CM01 DP, and
   deploy as **Available** to users. Do not claim MSI ProductCode detection for this EXE. 📸 Evidence:
   Notepad++ manual detection clause and Software Center availability.

   PowerShell equivalent:

   ```powershell
   Set-Location HUF:
   New-CMApplication -Name 'Notepad++ 8.x (x64)' -Publisher 'Notepad++' -SoftwareVersion '8.x'
   Add-CMScriptDeploymentType -ApplicationName 'Notepad++ 8.x (x64)' -DeploymentTypeName 'EXE' -ContentLocation '\\CM01\Sources\Apps\NotepadPP' -InstallCommand 'npp.8.x.Installer.x64.exe /S'
   ```

3. In **Software Library** → **Software Updates** → **All Software Updates**, synchronize the
   SUP, filter a small test set, create a **Software Update Group** manually, download content,
   and deploy it to `WKS-All` with a controlled deadline. Confirm this manual SUG works before
   automating it. Monitor deployment compliance and client `UpdatesDeployment.log`.

   PowerShell equivalent:

   ```powershell
   Set-Location HUF:
   Sync-CMSoftwareUpdate
   New-CMSoftwareUpdateGroup -Name 'Lab Manual Update Group'
   ```

4. Create an automatic deployment rule in **Software Library** → **Software Updates** →
   **Automatic Deployment Rules** named `Patch Tuesday – Workstations`. Schedule it monthly for
   the second Tuesday offset, target `WKS-All`, select the approved Windows 11 products and update
   classifications, create a new SUG, download to CM01 DP, and set a safe availability/deadline
   cadence. In **Assets and Compliance** → **Device Collections** → `WKS-All` → **Properties** →
   **Maintenance Windows**, add a maintenance window that matches the lab schedule. 📸 Evidence:
   ADR schedule and maintenance window.

   PowerShell equivalent:

   ```powershell
   Set-Location HUF:
   Get-Command New-CMAutoDeploymentRule,New-CMMaintenanceWindow | Select-Object Name
   ```

5. Create configuration items in **Assets and Compliance** → **Compliance Settings** →
   **Configuration Items**. First, create a Windows 11 registry CI verifying SMBv1 is disabled.
   Second, create a script CI that evaluates local Administrators membership against
   `HUFFLAB\AG-WKS-LocalAdmin`. Third, create a remediating CI that sets
   `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\InactivityTimeoutSecs` to
   `900`. Run the scripts locally first and document any intentional built-in local accounts.

   PowerShell equivalents for the underlying checks/remediation:

   ```powershell
   Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name SMB1
   Get-LocalGroupMember -Group Administrators | Select-Object Name
   Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name InactivityTimeoutSecs -Type DWord -Value 900
   ```

6. Create configuration baseline `Workstation Security Baseline`, add all three CIs, deploy it to
   `WKS-All`, and allow remediation only for the screen-lock CI. In the client ConfigMgr control
   panel applet, run the Machine Policy Retrieval & Evaluation Cycle and Evaluate Software Updates/
   Compliance as appropriate. 📸 Evidence: baseline deployment compliance and remediated timeout.

   PowerShell equivalent:

   ```powershell
   Set-Location HUF:
   New-CMBaseline -Name 'Workstation Security Baseline' -AddOSConfigurationItemName 'SMBv1 Disabled','Local Administrators Allowlist','Screen Lock 900 Seconds'
   ```

## Verify

```powershell
# CM01 from the Configuration Manager console
Set-Location HUF:
Get-CMApplication -Name '7-Zip 24.x (x64)','Notepad++ 8.x (x64)' | Select-Object LocalizedDisplayName
Get-CMSoftwareUpdateGroup -Name 'Lab Manual Update Group'
Get-CMBaseline -Name 'Workstation Security Baseline'
```

```text
LocalizedDisplayName
--------------------
7-Zip 24.x (x64)
Notepad++ 8.x (x64)

Lab Manual Update Group
Workstation Security Baseline
```

```powershell
# Managed client after policy and baseline evaluation
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name InactivityTimeoutSecs
Get-LocalGroupMember -Group Administrators | Select-Object -ExpandProperty Name
```

```text
InactivityTimeoutSecs : 900
HUFFLAB\AG-WKS-LocalAdmin
```

## Rollback

Withdraw or disable a deployment before uninstalling content. For an application, remove the
deployment, wait for policy processing, then revise or supersede the deployment type. For the
baseline, remove its deployment and revert only the remediated timeout if that is the intended
state. Revert CM01 and the test client to `Pre-Phase09-*` checkpoints only for a lab reset; doing
so discards deployment history and update scan state.

## Troubleshoot

- 7-Zip is not detected: compare the MSI ProductCode in the deployment type with
  `Get-Package -Name '*7-Zip*'` and inspect `AppEnforce.log`.
- Notepad++ reports installed incorrectly: validate the exact file/registry detection clause and
  inspect `AppDiscovery.log`; an EXE requires manual detection.
- Updates stay unknown: check `WUAHandler.log`, `ScanAgent.log`, `UpdatesDeployment.log`, SUP sync
  status, and the client boundary/DP assignment.
- ADR does not run on Patch Tuesday: inspect the rule schedule and server time zone; confirm it is
  monthly with the second-Tuesday offset, not a generic weekly schedule.
- Baseline is noncompliant: run the CI script locally as SYSTEM when permissions matter, compare
  the local Administrators list to `AG-WKS-LocalAdmin`, and inspect `DCMReporting.log`.

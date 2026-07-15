# Recurring AD operations drills

> **Resume bullet:** #1 · **Cadence:** monthly and after material directory changes · **VMs on:** DC01+one client (8 GB / 28 GB budget)

Run these drills manually on DC01 and record commands, timestamps, results, and screenshots in
[../docs/lab-notebook.md](../docs/lab-notebook.md). Take a fresh Hyper-V checkpoint before a drill
that changes directory state. Use a dedicated test object; never practise destructive recovery on
`lhuff`, `adm-lhuff`, or production-like service accounts. `LabP@ss2026!` is only an example
password—substitute a unique secret.

## Objectives

- Rehearse AD Recycle Bin recovery, system-state backup/restore planning, FSMO operations, AD
  health validation, and GPO backup.
- Produce repeatable evidence for routine directory administration.

## Prerequisites

- DC01 is healthy, patched, and backed up; one client is optional for logon/GPO verification.
- Verify DC01 (4 GB) plus one client (4 GB) totals 8 GB. Keep WDS01 and CM01 off for this drill.
- Install Windows Server Backup if the system-state backup drill has not already done so, and use a
  separate backup target that is not the DC system volume.

## Steps

1. **Recycle Bin recovery.** In **Active Directory Administrative Center** → domain →
   **Deleted Objects**, restore a deliberately deleted test user to its original OU. Confirm the
   AD Recycle Bin is enabled before deletion; enabling it is forest-wide and irreversible.

   PowerShell equivalent:

   ```powershell
   Get-ADOptionalFeature 'Recycle Bin Feature' | Select-Object EnabledScopes
   Get-ADObject -IncludeDeletedObjects -Filter "Name -eq 'drill.recycle'" | Restore-ADObject
   ```

2. **System-state backup and recovery rehearsal.** In **Windows Server Backup**, choose
   **Local Backup** → **Backup Once** → **Custom** → **System state**, target the dedicated backup
   volume. Practise only the recovery decision tree in a disposable checkpointed lab: Directory
   Services Restore Mode, authoritative versus non-authoritative restore, and post-restore health
   checks. Do not perform a restore unless the lab recovery scenario specifically requires it.

   PowerShell equivalent:

   ```powershell
   Install-WindowsFeature Windows-Server-Backup
   wbadmin start systemstatebackup -backuptarget:E: -quiet
   wbadmin get versions
   ```

3. **FSMO inventory and transfer.** In **Active Directory Users and Computers**, inspect
   **Operations Masters** for RID/PDC/Infrastructure; use **Active Directory Domains and Trusts**
   for Domain Naming and the Schema MMC snap-in for Schema Master. Record all holders. In this
   one-DC lab, practise the transfer command only as an intentional scenario; do not seize roles
   while DC01 is healthy.

   PowerShell equivalent:

   ```powershell
   Get-ADForest | Select-Object SchemaMaster,DomainNamingMaster
   Get-ADDomain | Select-Object PDCEmulator,RIDMaster,InfrastructureMaster
   # Intentional transfer scenario only:
   # Move-ADDirectoryServerOperationMasterRole -Identity <TargetDC> -OperationMasterRole PDCEmulator
   ```

4. **Directory health.** From an elevated command prompt on DC01, run `dcdiag /v` and
   `repadmin /replsummary`. A one-DC forest has no replication partners, but the commands still
   establish a baseline. Investigate DNS and advertising failures before treating a lab phase as
   complete. 📸 Evidence: clean `dcdiag` summary.

   PowerShell equivalent:

   ```powershell
   dcdiag /q
   repadmin /replsummary
   Get-ADDomainController -Discover -Service PrimaryDC
   ```

5. **GPO backup and restore readiness.** In **Group Policy Management**, right-click each lab GPO
   → **Back Up All**, storing backups outside the DC OS disk. Capture the backup ID and test
   `Restore-GPO` only against a noncritical test GPO or after a checkpoint. Include
   `GPO-C-Workstation-Baseline` and `GPO-U-IT-DriveMaps`; edit domain password policy only in
   Default Domain Policy, with a PSO for the administrator drill.

   PowerShell equivalent:

   ```powershell
   Backup-GPO -All -Path 'E:\GpoBackups'
   Get-GPO -All | Select-Object DisplayName,Id
   ```

## Verify

```powershell
Get-ADOptionalFeature 'Recycle Bin Feature' | Select-Object EnabledScopes
wbadmin get versions
dcdiag /q
repadmin /replsummary
Get-ChildItem 'E:\GpoBackups' | Select-Object -First 3 Name
```

```text
EnabledScopes
-------------
CN=Partitions,CN=Configuration,DC=hufflab,DC=internal

Version identifier: <system-state backup version>
<no dcdiag errors>
Source DSA          largest delta    fails/total %%   error
DC01                00:00:00        0 / 0    0
<GPO backup folders present>
```

## Rollback

Use the checkpoint taken before the drill to undo deliberately deleted test objects or a test GPO
restore. Do not use a Hyper-V checkpoint as a substitute for a documented system-state recovery
procedure. For an actual directory outage, follow the Windows Server Backup recovery plan, choose
authoritative restore only when justified, and validate DNS, `dcdiag`, and client logon afterward.

## Troubleshoot

- Deleted objects are not visible: verify Recycle Bin is enabled with `Get-ADOptionalFeature` and
  use ADAC's Deleted Objects container rather than standard ADUC.
- System-state backup fails: verify the backup target is not a critical volume and inspect
  `wbadmin` output/Event Viewer → **Microsoft-Windows-Backup**.
- `dcdiag` reports DNS failures: test `Resolve-DnsName dc01.hufflab.internal -Server 10.0.100.10`,
  then check AD-integrated zones and DC01's own DNS client setting.
- `repadmin` output is confusing on one DC: record the zero-partner baseline; it is not evidence
  of a replication failure by itself.
- GPO backup cannot be restored: verify the backup path and permissions, list backups with
  `Get-GPOBackup -Path 'E:\GpoBackups'`, and restore only to the intended GPO.

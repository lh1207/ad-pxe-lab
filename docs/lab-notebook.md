# Lab notebook

Use this notebook to retain execution evidence for the AD/PXE lab. Add one row for every runbook
item marked **📸 Evidence** and link the corresponding screenshot or text export. Never record
passwords, recovery secrets, product keys, or unredacted password-bearing answer files.

For each result, record the date in ISO format, the phase, the command or console path used, the
expected and observed result, the evidence filename, and any variance. Keep evidence files outside
source control when they contain hostnames, usernames, hashes, or other details you do not intend to
publish; the filename can still be recorded here.

## Build identity

| Field | Value |
|---|---|
| Build started | 2026-07-21 |
| Hyper-V host | WOLF |
| Operator | _name or initials_ |
| Current phase | Stage 1 complete — Phase 03 AD structure and AGDLP verified |
| Last verified checkpoint | `pre-phase-04` on DC01 (2026-08-03) |

## Media integrity record

Record the official source URL, download date, selected edition/version/language, exact configured
filename, and full SHA-256 value. A locally calculated hash proves consistency between local copies;
retain the official source URL separately as provenance.

| Item | Configured filename | Edition / version / language | Official source URL | Downloaded | SHA-256 | Verified |
|---|---|---|---|---|---|---|
| Windows Server 2025 Evaluation | `Windows_Server_2025_Evaluation.iso` | English (United States), x64 evaluation media refresh, build 26100.32230 | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025) | 2026-07-22 | `7B052573BA7894C9924E3E87BA732CCD354D18CB75A883EFA9B900EA125BFD51` | Local SHA-256 recorded; source host and file size verified |
| Windows 11 Enterprise Evaluation | `Windows_11_Enterprise_Evaluation.iso` | Version 25H2, Enterprise Eval x64, EN-US | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise) | 2026-07-22 | `A61ADEAB895EF5A4DB436E0A7011C92A2FF17BB0357F58B13BBC4062E535E7B9` | Matches Microsoft-published SHA-256 |
| Windows Server 2022 Evaluation | `Windows_Server_2022_Evaluation.iso` | English (United States), x64 evaluation | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022) | 2026-07-22 | `3E4FA6D8507B554856FC9CA6079CC402DF11A8B79344871669F0251535255325` | Local SHA-256 recorded; source host and file size verified |
| SQL Server 2022 Evaluation | `SQL_Server_2022_Evaluation.iso` | Evaluation, x64, EN-US | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-sql-server-2022) | 2026-07-22 | `342FC9F4B89EAA50A0D1EF0D30470EA7B6AF91B425C26023461198CB4E925B4F` | Download completed by the signed Microsoft SQL Server Installer; local SHA-256 recorded |
| Configuration Manager 2509 Evaluation | `ConfigMgr_2509_Evaluation.exe` | Current Branch 2509, English | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-microsoft-endpoint-configuration-manager) | 2026-07-22 | `4CB0380E2B1C43F1E0B2DA266BEDDD1B975DD72537F8D8113C702EADF1E6E313` | Valid Microsoft Authenticode signature |
| Windows ADK 11 24H2 | `adksetup.exe` | 10.1.26100.2454 (December 2024) bootstrapper | [Microsoft Learn](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install) | 2026-07-22 | `7F61E29F2314BCDD7E0ABF67A8367D83A05AA4A7B9223F85C5FD2582A35CC6F4` | Valid Microsoft Authenticode signature; latest servicing patch still required when installed |
| Windows PE add-on | `adkwinpesetup.exe` | Add-on for ADK 10.1.26100.2454 | [Microsoft Learn](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install) | 2026-07-22 | `ADF53CA21CAE36821E0A8F3C31546752B9CE066944DE1D4F1673E491831255E2` | Valid Microsoft Authenticode signature |
| SQL Server Management Studio | _exact filename_ | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| Microsoft ODBC Driver 18 | _exact filename_ | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| WS2025 cumulative update | Windows Update | KB5101372; OS build 26100.33158 | Microsoft Windows Update | 2026-07-22 | N/A | Installed and verified before/with Phase 02 completion |

## Phase status and checkpoints

Do not mark a phase complete until its runbook Verify block passes. Record a host restore point or
directory backup for Phase 01 because no VM checkpoint exists before the lab VMs are created.

| Phase | Started | Verify passed | Boundary checkpoint / backup | Evidence complete | Notes |
|---:|---|---|---|---|---|
| 01 | 2026-07-21 | 2026-07-22 | Host restore point `AD PXE Lab pre-Phase-01` | 2026-07-22 | Verified isolated switch/NAT, read-only parent, and six stopped Generation 2 VMs on approved `G:\HyperV\ad-pxe-lab` storage. |
| 02 | 2026-07-22 | 2026-07-22 | `pre-phase-03` | 2026-07-22 | Windows Server 2025 forest, AD-integrated DNS, DNS forwarders/scavenging, static network, and authorized DHCP scope verified. |
| 03 | 2026-07-22 | 2026-08-03 | `pre-phase-04` | 2026-08-03 | OU/account/group structure and AGDLP share passed the runbook verification; only DC01 remains running. |
| 04 | _pending_ | _pending_ | _record per runbook_ | _pending_ | |
| 05 | _pending_ | _pending_ | _record per runbook_ | _pending_ | |
| 06 | _pending_ | _pending_ | _record per runbook_ | _pending_ | |
| 07 | _pending_ | _pending_ | _record per runbook_ | _pending_ | |
| 08 | _pending_ | _pending_ | _record per runbook_ | _pending_ | |
| 09 | _pending_ | _pending_ | _record per runbook_ | _pending_ | |
| 10 | _pending_ | _pending_ | _record per runbook_ | _pending_ | |

## Stage 1 evidence — AD foundation

This table mirrors the consolidated checklist in the
[Phase 1 execution handoff](handoffs/phase-01-handoff.md). Replace each placeholder only after the
corresponding command and console checks pass.

| # | Date | Phase | Command / console path and observed result | Evidence filename | Variance / remediation |
|---:|---|---:|---|---|---|
| 1 | 2026-07-22 | 01 | Elevated readiness passed: Hyper-V enabled, 63 GB RAM, 693 GB free on `G:`, active hypervisor, all seven configured media items, and all script parser checks | `docs/phase-01-readiness.txt` | Corrected the virtualization gate to accept an active Hyper-V hypervisor when firmware reporting is masked. |
| 2 | 2026-07-22 | 01 | Created and verified internal `LabSwitch`, host vNIC `10.0.100.1/24`, and `LabNAT` prefix `10.0.100.0/24` | `docs/phase-01-network.txt` | None. |
| 3 | 2026-07-22 | 02 | DC01 verified at `10.0.100.10/24`, gateway `10.0.100.1`, self-DNS `10.0.100.10`, build 26100.33158 with KB5101372 installed | `docs/phase-02-configuration-verification.txt` | The post-promotion reboot initially failed because the local credential was invalid after promotion; host-side restart completed AD DS initialization. |
| 4 | 2026-07-22 | 02 | DC01 authorized for DHCP; active `10.0.100.100`–`10.0.100.199` scope with 8-hour lease, options 003/006/015 and implicit lease option 051; no 060/066/067 | `docs/phase-02-configuration-verification.txt` | Windows Server exposes option 051 for the configured lease duration; the PXE-prohibited options are absent. |
| 5 | 2026-08-03 | 03 | PowerShell Direct enumerated the complete 13-OU `HUFFLAB` tree with every OU protected from accidental deletion; Users/Computers containers redirected correctly | `docs/phase-03-configuration-verification.txt` | Text enumeration is the authoritative equivalent of the requested expanded ADUC tree screenshot. |
| 6 | 2026-08-03 | 03 | Verified `hr.jones`/`hr.smith` → `RG-HR-Staff` → `AG-Share-HR-Modify`; SMB Change and NTFS Modify on `C:\HRShare`, with no direct user ACLs | `docs/phase-03-configuration-verification.txt` | One-base deterministic derivation produced nine distinct complex lab passwords without storing or logging values. |

## Additional evidence log

Append later-phase evidence and ad hoc verification here. Keep one result per row so a failed check
and its successful rerun remain distinguishable.

| Date | Phase | Command / console path | Expected result | Observed result | Evidence filename | Variance / remediation |
|---|---:|---|---|---|---|---|
| 2026-07-22 | 01 | Elevated `00-Test-HostReadiness.ps1` preflight | ≥500 GB free at configured lab root; all configured media staged; active Hyper-V recognized | `G:` had approximately 714 GB free; media was not yet staged; the active hypervisor exposed a false-negative firmware flag | `docs/phase-01-readiness-preflight.txt` | Staged six of seven media items and corrected the CPU gate to accept `HypervisorPresent=True`; final rerun pending SQL ISO. No Hyper-V resources created. |
| 2026-07-22 | 01 | Elevated `00-Test-HostReadiness.ps1` final gate | Every host, media, and parser check passes | All checks passed with 693 GB free before VM storage creation | `docs/phase-01-readiness.txt` | None. |
| 2026-07-22 | 01 | Elevated `02-New-LabParentDisk.ps1` | Detached, read-only 60 GB dynamic WS2025 parent VHDX | Created `G:\HyperV\ad-pxe-lab\VHD\WS2025-parent.vhdx`; 15,103,688,704-byte file; detached and read-only | `docs/phase-01-parent-disk.txt` | Corrected the configured image name to the ISO's exact `Windows Server 2025 Standard Evaluation (Desktop Experience)` label after a safe pre-creation stop. |
| 2026-07-22 | 01 | Elevated `03-New-LabVM.ps1` and boundary verification | Six stopped Generation 2 VMs, correct RAM/CPU, switch, disks, firmware, and boot order | All six passed; CL01/CL02 network-first; DC01/WDS01 differencing parents correct; parent remained read-only | `docs/phase-01-vms.txt` | None. |
| 2026-07-22 | 02 | PowerShell Direct Phase 02 configuration and verification | Windows2025 forest/domain, forward/reverse AD-integrated DNS, authorized DHCP, static network, current update, and `pre-phase-03` | All Phase 02 checks passed; DC01 build 26100.33158, DHCP active, automatic checkpoints disabled | `docs/phase-02-configuration-verification.txt` | DNS client and missing default route were corrected before the successful gate. |
| 2026-08-03 | 03 | Idempotent PowerShell Direct Phase 03 convergence and verification | 13 protected OUs, nine enabled users, five scoped security groups, AGDLP share permissions | All checks passed and `pre-phase-04` was created | `docs/phase-03-configuration-verification.txt` | An earlier rejected password left `lhuff` disabled; the final convergence reset only that derived password and enabled the account. |
| 2026-08-03 | 03 | Independent elevated Hyper-V host boundary audit | Six Generation 2 VMs; only DC01 running; automatic checkpoints disabled; `pre-phase-03` and `pre-phase-04` present | Verification passed exactly | `docs/phase-03-host-boundary.txt` | None. |

## Rollback and variance log

Record why a checkpoint was applied or an approved variance was introduced. A Hyper-V checkpoint is
not a system-state backup for Active Directory.

| Date | Phase | Event | Affected VM(s) / host artifact | Reason | Result and follow-up |
|---|---:|---|---|---|---|
| 2026-07-21 | 01 | Approved storage-path variance | Lab root, ISO directory, VHD directory, and parent VHDX | `C:` has approximately 43 GB free, below the 500 GB gate; operator approved use of `G:` Backup Disk | Updated authoritative paths to `G:\HyperV\ad-pxe-lab`; Git checkout remains on `C:`. |
| 2026-07-22 | 01 | Host restore point | WOLF host before Hyper-V lab resource creation | Phase 01 requires a host recovery boundary before VM checkpoints exist | Created restore point `AD PXE Lab pre-Phase-01` before `LabSwitch`, `LabNAT`, parent disk, or VM creation. |

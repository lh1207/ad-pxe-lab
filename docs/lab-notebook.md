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
| Build started | _YYYY-MM-DD_ |
| Hyper-V host | _record a non-sensitive identifier_ |
| Operator | _name or initials_ |
| Current phase | _00–10_ |
| Last verified checkpoint | _checkpoint name_ |

## Media integrity record

Record the official source URL, download date, selected edition/version/language, exact configured
filename, and full SHA-256 value. A locally calculated hash proves consistency between local copies;
retain the official source URL separately as provenance.

| Item | Configured filename | Edition / version / language | Official source URL | Downloaded | SHA-256 | Verified |
|---|---|---|---|---|---|---|
| Windows Server 2025 Evaluation | `Windows_Server_2025_Evaluation.iso` | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| Windows 11 Enterprise Evaluation | `Windows_11_Enterprise_Evaluation.iso` | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| Windows Server 2022 Evaluation | `Windows_Server_2022_Evaluation.iso` | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| SQL Server 2022 Evaluation | `SQL_Server_2022_Evaluation.iso` | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| Configuration Manager 2509 Evaluation | `ConfigMgr_2509_Evaluation.exe` | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| Windows ADK 11 24H2 | `adksetup.exe` | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| Windows PE add-on | `adkwinpesetup.exe` | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| SQL Server Management Studio | _exact filename_ | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| Microsoft ODBC Driver 18 | _exact filename_ | _pending_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters_ | _pending_ |
| WS2025 cumulative update | _exact filename or Windows Update_ | _KB and build_ | _pending_ | _YYYY-MM-DD_ | _64 hex characters or N/A_ | _pending_ |

## Phase status and checkpoints

Do not mark a phase complete until its runbook Verify block passes. Record a host restore point or
directory backup for Phase 01 because no VM checkpoint exists before the lab VMs are created.

| Phase | Started | Verify passed | Boundary checkpoint / backup | Evidence complete | Notes |
|---:|---|---|---|---|---|
| 01 | _pending_ | _pending_ | _host restore point or directory backup_ | _pending_ | |
| 02 | _pending_ | _pending_ | `pre-phase-03` | _pending_ | |
| 03 | _pending_ | _pending_ | `pre-phase-04` | _pending_ | |
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
| 1 | _pending_ | 01 | Readiness: Hyper-V, virtualization, storage, media, and parser checks | _pending_ | |
| 2 | _pending_ | 01 | Virtual Switch Manager: `LabSwitch`; `Get-NetNat`: `LabNAT` | _pending_ | |
| 3 | _pending_ | 02 | DC01 static IPv4; installed KB5060842 or later (record KB and build) | _pending_ | |
| 4 | _pending_ | 02 | DHCP authorization, active `.100`–`.199` scope, options 003/006/015 only | _pending_ | |
| 5 | _pending_ | 03 | ADUC expanded through the complete `HUFFLAB` OU tree | _pending_ | |
| 6 | _pending_ | 03 | AGDLP membership chain and `HRShare` share/NTFS permissions | _pending_ | |

## Additional evidence log

Append later-phase evidence and ad hoc verification here. Keep one result per row so a failed check
and its successful rerun remain distinguishable.

| Date | Phase | Command / console path | Expected result | Observed result | Evidence filename | Variance / remediation |
|---|---:|---|---|---|---|---|
| _YYYY-MM-DD_ | _00–10_ | _pending_ | _pending_ | _pending_ | _pending_ | |

## Rollback and variance log

Record why a checkpoint was applied or an approved variance was introduced. A Hyper-V checkpoint is
not a system-state backup for Active Directory.

| Date | Phase | Event | Affected VM(s) / host artifact | Reason | Result and follow-up |
|---|---:|---|---|---|---|
| _YYYY-MM-DD_ | _00–10_ | _checkpoint, rollback, or variance_ | _pending_ | _pending_ | _pending_ |

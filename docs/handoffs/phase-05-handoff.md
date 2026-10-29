# Phase 05 Handoff — GPO Suite on WOLF

> **Completed, 2026-10-28:** the attended finalizer reports `PHASE 05 FINAL GATE: PASS` after
> fresh configuration, computer RSOP, and HR-user RSOP assertions. It creates Standard
> `pre-phase-06` checkpoints on DC01 (`69c63c35-f7aa-4dec-add4-37358ef7b111`) and CL02
> (`56d7c809-6470-4737-a610-8477a10e4eb1`); only DC01 and CL02 were running. The GPMC link,
> drive-map target, banner, HR mapping, and final-gate captures are saved. Do not rerun
> initialization, password recovery, or finalization.
> The operator approves either a regular hyphen or an em dash in the banner title. Read the
> completion record and `phase-05-operator-steps.md`; earlier observations below remain historical.

> **Type:** execution handoff · **Covers:** [Phase 05 runbook](../../runbooks/05-gpo-suite.md)
> · **Starts from:** verified Phase 04 boundary · **Execution host:** Windows Hyper-V host `WOLF`

## 1 · Hard environment boundary

This phase is Windows administration work. It must execute in the saved local project at
`C:\HyperV\ad-pxe-lab` on `WOLF`. Do not execute it from ChatGPT Work cloud, a Linux container,
WSL, macOS, or an SSH session whose remote endpoint is Linux. Linux may be used only to read the
Markdown; it cannot administer Hyper-V, PowerShell Direct, Group Policy, or the Windows guests.

An agent must stop before mutation if any of these are true:

- `hostname` is not `WOLF`;
- `[Environment]::OSVersion.Platform` is not `Win32NT` (works in Windows PowerShell 5.1 too);
- the working directory is not under `C:\HyperV\ad-pxe-lab`;
- `Get-Command Get-VM` or `Invoke-Command -VMName` is unavailable;
- the shell is not elevated.

In Codex desktop, reopen this repository as a **local Windows project on WOLF**. Do not create a
cloud task for execution. If a task already opened elsewhere, hand it back to the local WOLF host
or start a local task with this file as its initial context.

Run the read-only gate from **elevated Windows PowerShell**:

```powershell
Set-Location C:\HyperV\ad-pxe-lab
.\scripts\05-Test-Phase05Environment.ps1
```

Expected final field:

```text
Result : PASS - Windows host boundary is ready for Phase 05
```

Do not translate failed Windows commands into Bash alternatives. Correct the execution host.

### Verified desktop elevation path

On 2026-10-27, a Codex sandbox elevation request still returned a non-administrator Windows token.
Launching Windows PowerShell with `Start-Process -Verb RunAs` and accepting Windows UAC did obtain
an elevated token. Use a hidden window for a scripted helper and capture its output to a local file.
The operator confirms this UAC method matches the established workflow used in the previous phases.
If script execution is disabled, `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` can
set policy for that process without changing the machine execution policy.

The elevated read-only check found **all six lab VMs Off** and correctly stopped at the VM-state
gate. No VM or GPO changes occurred. At execution time, start only DC01 and CL02, wait for guest
readiness, then rerun the preflight. This observation does not prove the later checkpoint or guest
prerequisite checks pass.

## 2 · Authoritative starting state

`docs/phase-04-configuration-verification.txt` is the last live assertion transcript. It ends
`PHASE 04 FINAL GATE: PASS` and proves:

- CL02 is Windows 11 Enterprise Evaluation, joined to `hufflab.internal`, using DNS
  `10.0.100.10`, with a healthy secure channel;
- its computer object is exactly
  `CN=CL02,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal`;
- standard `pre-phase-05` checkpoints exist on DC01, WDS01, and CL02;
- automatic checkpoints are disabled on all six lab VMs;
- the captured Phase 04 boundary had DC01, WDS01, and CL02 running.

Phase 05 needs only DC01 and CL02. Power off WDS01 before running the preflight; keep CM01, CL01,
and REF01 off. The valid VM allocation is 8 GB total: DC01 4 GB plus CL02 4 GB.

Do not create duplicate `pre-phase-05` checkpoints. Verify the existing standard checkpoints and
use them as the rollback boundary.

## 3 · Credential reality

- Active Directory cannot reveal existing plaintext passwords. Never try to “grab” one from DC01.
- The nine Phase 03 lab identities were reset on 2026-08-11 to one operator-chosen temporary lab
  password. The value is intentionally absent from Git, transcripts, screenshots, and this handoff.
- Prompt the operator when a credential is needed. Do not place a password in a command, script,
  environment variable, transcript, or screenshot.
- Use `HUFFLAB\Administrator` or an explicitly delegated account for GPO/AD changes. `hr.jones`
  is a normal test user. The CL02 local administrator and domain Administrator are separate
  identities even if the operator chose the same lab-only value.
- If a required password is unknown, reset only the affected lab identity with operator approval;
  do not bulk-reset accounts again.

Example prompt-only pattern:

```powershell
$domainAdmin = Get-Credential 'HUFFLAB\Administrator'
```

## 4 · Phase 05 objective

Complete the authoritative [GPO suite runbook](../../runbooks/05-gpo-suite.md):

1. Set the Default Domain Policy password settings to the approved lab values.
2. Create `PSO-Admins-Strong` and assign it to `adm-lhuff`.
3. Create and link `GPO-C-Workstation-Baseline` to the Workstations OU.
4. Create and link the runbook-named `GPO-U-IT-DriveMaps` to the Users OU, with an `H:` mapping
   to `\\DC01\HRShare` targeted to `RG-HR-Staff`.
5. Validate computer policy and the HR-targeted user preference on CL02.
6. Capture evidence, export backups, run the final gate, and create the Phase 06 boundary.

The runbook remains authoritative for the exact GUI paths and approved values. This handoff adds
the execution boundary and a safer operator sequence.

## 5 · Recommended execution sequence

### A. Host preflight

From elevated Windows PowerShell on WOLF:

```powershell
Set-Location C:\HyperV\ad-pxe-lab
Get-VM -Name DC01,WDS01,CM01,CL01,CL02,REF01 | Select-Object Name,State,MemoryAssigned
if ((Get-VM -Name WDS01).State -eq 'Running') {
    Stop-VM -Name WDS01   # graceful guest shutdown; wait for Off
}
if ((Get-VM -Name WDS01).State -ne 'Off') {
    throw 'WDS01 is not Off. Inspect the guest before continuing.'
}
.\scripts\05-Test-Phase05Environment.ps1
```

If graceful WDS01 shutdown fails, inspect the guest before considering `Stop-VM -TurnOff`; do not
force it merely to make the gate green.

### B. Verify prerequisites on DC01

Use Hyper-V Manager/VMConnect or PowerShell Direct with an interactively supplied credential:

```powershell
$domainAdmin = Get-Credential 'HUFFLAB\Administrator'
Invoke-Command -VMName DC01 -Credential $domainAdmin -ScriptBlock {
    Import-Module ActiveDirectory
    Import-Module GroupPolicy
    Get-ADComputer CL02 -Properties DistinguishedName | Select-Object Name,DistinguishedName
    Get-ADGroup RG-HR-Staff
    Get-ADGroup AG-WKS-LocalAdmin
    Get-ADPrincipalGroupMembership hr.jones | Select-Object Name
    Get-ADGroupMember RG-HR-Staff -Recursive | Select-Object SamAccountName
    Get-ADGroupMember AG-Share-HR-Modify -Recursive | Select-Object SamAccountName
    Get-SmbShareAccess HRShare
    $share = Get-SmbShare HRShare
    (Get-Acl -LiteralPath $share.Path).Access
}
```

Stop if CL02 is outside the Workstations OU, `hr.jones` is not in `RG-HR-Staff`, or HRShare no
longer grants the Phase 03 AGDLP chain.

### C. Configure domain password policy and PSO

Perform runbook steps 1–2 on DC01 using GPMC/ADAC or the documented PowerShell equivalents.
Before modifying Default Domain Policy, run this backup **inside DC01** in an elevated domain
administrator PowerShell session (or inside a PowerShell Direct script block targeting DC01):

```powershell
New-Item -ItemType Directory -Path C:\GPO-Backups\Phase05 -Force
Backup-GPO -Name 'Default Domain Policy' -Path C:\GPO-Backups\Phase05
```

Do not replace or delete Default Domain Policy. A PSO supplements it and applies only to its
assigned subject.

### D. Build and link the workstation baseline

Create `GPO-C-Workstation-Baseline`, link it only to the Workstations OU, and configure the three
computer settings in the runbook: removable-storage deny, approved logon banner, and 900-second
machine inactivity limit. Confirm CL02 remains in that OU before testing.

### E. Build the targeted drive map

Create `GPO-U-IT-DriveMaps` exactly as named in the runbook, link it to the HUFFLAB Users OU, and
configure `H:` → `\\DC01\HRShare` with item-level targeting for `RG-HR-Staff`.

The map must not grant access by itself. Phase 03 permissions remain:

```text
hr.jones -> RG-HR-Staff -> AG-Share-HR-Modify -> SMB Change + NTFS Modify
```

### F. Test in the correct user contexts

While signed in interactively as `HUFFLAB\hr.jones`, use a **normal, non-elevated** PowerShell or
Command Prompt for the user-policy test:

```powershell
gpupdate /target:user /force
```

Sign out and back in as `HUFFLAB\hr.jones`, then run:

```powershell
Get-PSDrive -Name H
Test-Path H:\
whoami
gpresult /scope user /r
$drive = Get-PSDrive -Name H -ErrorAction Stop
if ((whoami) -ine 'HUFFLAB\hr.jones') { throw 'Wrong user context for drive-map test.' }
if ($drive.DisplayRoot -ine '\\DC01\HRShare' -and $drive.Root -ine '\\DC01\HRShare') {
    throw 'H: does not map to the expected HR share.'
}
if (-not (Test-Path H:\)) { throw 'HR share is inaccessible through H:.' }
```

Do not elevate with a different administrator for this check; doing so changes user context and can
hide or misattribute the mapped drive.

Use a separate elevated administrator session for computer policy:

```powershell
gpupdate /target:computer /force
gpresult /scope computer /r
```

Restart or sign out only when the policy requires it. Validate the banner at the next sign-in. Test
USB denial only with a disposable device and only if safe for the host.

## 6 · Final verification and evidence

Capture and record in `docs/lab-notebook.md`:

- GPMC links for the Workstations and Users OUs;
- the Drive Maps item-level target `RG-HR-Staff`;
- the CL02 logon banner;
- `H:` mapped for `HUFFLAB\hr.jones`;
- `gpresult` showing both expected GPOs;
- password-policy and PSO command results;
- final VM state and the new Phase 06 rollback boundary.

Export a text transcript to `docs/phase-05-configuration-verification.txt`. The final gate must
assert, not merely display:

- Default Domain Policy values match the approved Phase 05 settings;
- `PSO-Admins-Strong` is resultant for `adm-lhuff`;
- `GPO-C-Workstation-Baseline` is linked to Workstations;
- `GPO-U-IT-DriveMaps` is linked to Users and appears for `hr.jones`;
- `H:` resolves to `\\DC01\HRShare` in the `hr.jones` session;
- CL02 remains domain-joined with a healthy secure channel;
- only DC01 and CL02 are running during the phase.

After every assertion passes, create standard `pre-phase-06` checkpoints for DC01 and CL02. Do
not checkpoint during `gpupdate`, restart, or other active writes.

## 7 · Rollback and stop conditions

Use the existing `pre-phase-05` checkpoints only for a wholesale rollback, and revert DC01 and
CL02 together because domain policy state and client-applied state are related. Export evidence and
note the reason before applying checkpoints. Remember that a DC checkpoint is not a system-state
backup.

Stop and report rather than improvising when:

- the execution environment is not elevated Windows on WOLF;
- a required credential is unknown;
- Phase 04 identity, OU, DNS, secure-channel, or checkpoint assertions fail;
- GPO settings conflict with an existing policy not described in the runbook;
- the client applies policy under the wrong user context;
- a rollback would affect later work not represented by the checkpoints.

## 8 · Copy/paste bootstrap for the next agent

```text
Operate Phase 05 only from the local Windows project C:\HyperV\ad-pxe-lab on Hyper-V host WOLF.
Do not use Linux, WSL, a container, or ChatGPT Work cloud for execution. Read
docs/handoffs/phase-05-handoff.md and run scripts/05-Test-Phase05Environment.ps1 from elevated
Windows PowerShell before any mutation. The authoritative starting evidence is
docs/phase-04-configuration-verification.txt, which ends PHASE 04 FINAL GATE: PASS. Phase 05 uses
only DC01 and CL02; WDS01, CM01, CL01, and REF01 must be off. Existing standard pre-phase-05
checkpoints on DC01 and CL02 are the rollback boundary. Prompt for credentials and never store or
recover plaintext passwords. Execute runbooks/05-gpo-suite.md, test the H: drive in the normal
HUFFLAB\hr.jones session, capture evidence, assert the final gate, and create pre-phase-06 only
after all checks pass.
```

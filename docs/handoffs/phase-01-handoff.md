# Phase 1 Handoff — Stage 1: AD Foundation (runbooks 01–03)

> **Type:** execution handoff · **Covers:** [Phase 01](../../runbooks/01-host-prep.md) →
> [Phase 02](../../runbooks/02-dc01-adds-dns-dhcp.md) → [Phase 03](../../runbooks/03-ad-structure.md)
> · **Assumes:** all Phase 0 groundwork complete (see below)

## Purpose

Pick up here to execute the **AD foundation** end to end. Stage 1 takes the lab from bare host to a
working domain: it builds the isolated host foundation (`LabSwitch`/`LabNAT`, the never-booted
`WS2025-parent.vhdx`, and six Generation 2 VMs), promotes DC01 to the `hufflab.internal` forest with
AD-integrated DNS and an authorized DHCP scope, and lays down the canonical `HUFFLAB` OU/user/group
tree with a working AGDLP share (`\\DC01\HRShare`).

**In scope:** runbooks 01, 02, 03. **Out of scope (later phases):** WDS/PXE (04), GPO suite (05),
golden image (06), and the ConfigMgr line (07–10). Do not build any of those here — but note the
DHCP scope you create in Phase 02 must already respect the single-PXE-responder rule (no options
60/66/67), because that scope survives into the WDS/ConfigMgr work.

Work the phases **in order**. Take the named Hyper-V checkpoint before each phase, capture every
📸 evidence item into `docs/lab-notebook.md`, and do not advance until that phase's **Verify** block
passes.

---

## 1 · Assumed complete (Phase 0) — confirm, do not redo

Before starting Phase 01, confirm each item. If any is missing, resolve it first —
[conventions](../../runbooks/00-conventions.md) and the [ISO checklist](../iso-checklist.md) are the
source of truth.

- [ ] **Conventions adopted.** Forest `hufflab.internal`, NetBIOS `HUFFLAB`, servers `DC01`/`WDS01`/
      `CM01`, `HUFFLAB-` artifact prefix. Checkpoint (`pre-phase-NN`) and 📸 evidence discipline
      understood. RAM master table and the "start only the active phase's VMs" rule in effect.
- [ ] **Secure lab password chosen.** A unique value you control — **never** the `LabP@ss2026!`
      example. Never placed in scripts, transcripts, screenshots, source control, or command history.
      Scripts prompt for it via `Read-Host -AsSecureString`.
- [ ] **Media downloaded, SHA-256 recorded, and placed in `IsoDir`** (`C:\HyperV\ad-pxe-lab\ISO`)
      with the exact filenames from `scripts/lab.config.psd1` → `Paths.IsoFiles`. Stage 1 needs the
      Windows Server 2025 evaluation ISO (`Windows_Server_2025_Evaluation.iso`); the remaining media
      (`Windows_11_Enterprise_Evaluation.iso`, `Windows_Server_2022_Evaluation.iso`, SQL, ConfigMgr,
      ADK, WinPE) is required by later phases but should already be inventoried.
- [ ] **A WS2025 cumulative update at KB5060842 or later** is available for the Phase 02 patch gate.
- [ ] **Host meets `HostRequirements`:** ≥ 32 GB installed RAM, ≥ 500 GB free lab storage, Hyper-V
      enabled, hardware virtualization on, Secure Boot template `MicrosoftWindows`, and an **elevated
      Windows PowerShell 5.1** session available.

---

## 2 · Environment quick-reference

All values are authoritative from [`scripts/lab.config.psd1`](../../scripts/lab.config.psd1).

| Domain | Value |
|---|---|
| Forest FQDN / NetBIOS | `hufflab.internal` / `HUFFLAB` |
| Time zone | `Eastern Standard Time` |

| Network | Value |
|---|---|
| Subnet / prefix | `10.0.100.0/24` (`/24`) |
| Host vNIC & gateway | `10.0.100.1` |
| Switch / NAT | `LabSwitch` (internal) / `LabNAT` |
| Statics | DC01 `10.0.100.10` · WDS01 `10.0.100.20` · CM01 `10.0.100.30` |
| DHCP scope | `10.0.100.100`–`10.0.100.199`, 8-hour lease |
| DNS forwarders | `1.1.1.1`, `9.9.9.9` |

| Paths | Value |
|---|---|
| Lab root | `C:\HyperV\ad-pxe-lab` |
| ISO dir | `C:\HyperV\ad-pxe-lab\ISO` |
| VHD dir | `C:\HyperV\ad-pxe-lab\VHD` |
| Parent disk | `C:\HyperV\ad-pxe-lab\VHD\WS2025-parent.vhdx` (read-only, never booted) |

**VM / RAM master table** — budget is **28 GB** of VM allocation (leaves ≥ 4 GB for the host). Start
only the active phase's VMs.

| VM | RAM | Type | Disk | Stage 1 use |
|---|---:|---|---|---|
| DC01 | 4 GB | Static | 60 GB differencing | **On** in 02–03 |
| WDS01 | 2 GB | Static | 60 GB differencing | Off |
| CM01 | 16 GB | Static | 150 GB fixed | Off |
| CL01 | 4 GB | Dynamic | 60 GB dynamic | Off |
| CL02 | 4 GB | Dynamic | 60 GB dynamic | Off |
| REF01 | 4 GB | Dynamic | 60 GB dynamic | Off |

> **Stage 1 power state:** in Phase 01 all six VMs are created but stay **off**. From Phase 02
> onward, **only DC01 runs (4 GB)**; every other VM remains powered off.

---

## 3 · Execution sequence

### Phase 01 — Host prep & lab foundation

**Goal:** validated host, `LabSwitch`/`LabNAT`, the read-only WS2025 parent disk, and six stopped
Gen 2 VMs. **Full detail:** [runbooks/01-host-prep.md](../../runbooks/01-host-prep.md).

**Checkpoint first:** none exist yet — instead take a **host restore point** or ensure the lab
directory is backed up before creating artifacts (per the runbook's Rollback).

Run from `.\scripts` in an elevated PowerShell 5.1 session, in order:

```powershell
Set-Location .\scripts
.\00-Test-HostReadiness.ps1                                  # readiness gate
.\01-New-LabSwitch.ps1                                       # LabSwitch + LabNAT (host vNIC 10.0.100.1/24)
.\02-New-LabParentDisk.ps1                                   # builds read-only WS2025-parent.vhdx (never booted)
$adminPassword = Read-Host 'Local Administrator password' -AsSecureString
.\03-New-LabVM.ps1 -AdminPassword $adminPassword             # creates all six Gen2 VMs; do NOT start them
```

**Verify** (expected: `LabSwitch`, `LabNAT` with prefix `10.0.100.0/24`, six stopped Gen 2 VMs,
CL01/CL02 network-first boot, parent VHDX read-only):

```powershell
Get-VMSwitch -Name LabSwitch
Get-NetNat -Name LabNAT
Get-VM | Select-Object Name, Generation, State
Get-VMFirmware -VMName CL01 | Select-Object -ExpandProperty BootOrder   # network adapter precedes disk
(Get-Item (Import-PowerShellDataFile .\lab.config.psd1).Paths.ParentVhdx).IsReadOnly   # -> True
```

**📸 Evidence:** readiness output (Hyper-V, virtualization, storage, media, parser checks); Virtual
Switch Manager showing `LabSwitch` plus `Get-NetNat` showing `LabNAT`.

**Exit gate:** all six VMs exist and are **powered off**; verify block passes.

---

### Phase 02 — DC01: AD DS, DNS, DHCP

**Goal:** patched, promoted `hufflab.internal` forest with AD-integrated DNS and an authorized DHCP
scope. **Full detail:** [runbooks/02-dc01-adds-dns-dhcp.md](../../runbooks/02-dc01-adds-dns-dhcp.md).

**Checkpoint first:**

```powershell
Checkpoint-VM -Name DC01 -SnapshotName pre-phase-02
```

Start **only DC01** (4 GB). Command spine (GUI paths in the runbook):

```powershell
# 1) Static addressing, then rename + reboot
New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 10.0.100.10 -PrefixLength 24 -DefaultGateway 10.0.100.1
Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses 10.0.100.10
Rename-Computer -NewName DC01 -Restart

# 2) After reboot: remove the one-time answer file, then PATCH before promotion
Remove-Item 'C:\Windows\Panther\unattend.xml' -Force            # delete password-bearing answer file
#   install KB5060842 or later via Windows Update, reboot until current

# 3) Install AD DS + DNS and promote a NEW forest (WS2025 functional level 10)
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
$dsrmPassword = Read-Host 'DSRM password' -AsSecureString
Install-ADDSForest -DomainName 'hufflab.internal' -DomainNetbiosName 'HUFFLAB' `
  -ForestMode Win2025 -DomainMode Win2025 -SafeModeAdministratorPassword $dsrmPassword -Force

# 4) DNS forwarders, reverse zone, scavenging
Set-DnsServerForwarder -IPAddress 1.1.1.1, 9.9.9.9
Add-DnsServerPrimaryZone -NetworkId '10.0.100.0/24' -ReplicationScope Domain
Set-DnsServerScavenging -ScavengingState $true -ApplyOnAllZones $true

# 5) DHCP install, authorize, scope — options 003/006/015 ONLY (never 60/66/67)
Install-WindowsFeature DHCP -IncludeManagementTools
Add-DhcpServerInDC -DnsName 'DC01.hufflab.internal' -IPAddress 10.0.100.10
Add-DhcpServerv4Scope -Name 'Lab-10.0.100.0' -StartRange 10.0.100.100 -EndRange 10.0.100.199 `
  -SubnetMask 255.255.255.0 -LeaseDuration (New-TimeSpan -Hours 8) -State Active
Set-DhcpServerv4OptionValue -ScopeId 10.0.100.0 -Router 10.0.100.1 -DnsServer 10.0.100.10 `
  -DnsDomain 'hufflab.internal'
```

**Verify** (expected: WS2025 FL level 10 for domain + forest; DC01 resolves to `10.0.100.10`; both
zones present; forwarders `1.1.1.1`/`9.9.9.9`; DHCP authorized; scope `.100`–`.199`, 8-hour lease;
options 003/006/015 only — **no** 60/66/67):

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode
Get-ADForest | Select-Object RootDomain, ForestMode
Resolve-DnsName DC01.hufflab.internal
Get-DnsServerZone | Where-Object ZoneName -in 'hufflab.internal', '100.0.10.in-addr.arpa'
Get-DnsServerForwarder | Select-Object -ExpandProperty IPAddress
Get-DhcpServerInDC
Get-DhcpServerv4Scope -ScopeId 10.0.100.0 | Select-Object ScopeId, StartRange, EndRange, LeaseDuration, State
Get-DhcpServerv4OptionValue -ScopeId 10.0.100.0
```

**📸 Evidence:** DC01 static IPv4 settings + installed KB5060842 (or later); DHCP authorization,
active scope range, and scope options 003/006/015.

**Exit gate:** verify block passes, then checkpoint and keep DC01 **on**:

```powershell
Checkpoint-VM -Name DC01 -SnapshotName pre-phase-03
```

---

### Phase 03 — AD structure: OUs, users, groups, AGDLP

**Goal:** canonical `HUFFLAB` OU tree, accounts, role/access groups, and a working AGDLP share.
**Full detail:** [runbooks/03-ad-structure.md](../../runbooks/03-ad-structure.md).

**Checkpoint first:** confirm `pre-phase-03` exists (created at the end of Phase 02). DC01 is the
only powered-on VM. Sign in as `HUFFLAB\Administrator` or a delegated equivalent.

Command spine (assign a unique password — not the example — to every account):

```powershell
# 1) OU tree
$domainDn = (Get-ADDomain).DistinguishedName
$root = "OU=HUFFLAB,$domainDn"
New-ADOrganizationalUnit -Name HUFFLAB -Path $domainDn -ProtectedFromAccidentalDeletion $true
'Admins','ServiceAccounts','Users','Groups','Workstations','Servers' | ForEach-Object {
  New-ADOrganizationalUnit -Name $_ -Path $root -ProtectedFromAccidentalDeletion $true }
'IT','HR','Finance','Engineering' | ForEach-Object {
  New-ADOrganizationalUnit -Name $_ -Path "OU=Users,$root" -ProtectedFromAccidentalDeletion $true }
'Role','Access' | ForEach-Object {
  New-ADOrganizationalUnit -Name $_ -Path "OU=Groups,$root" -ProtectedFromAccidentalDeletion $true }

# 2) Redirect default computer/user containers
redircmp "OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal"
redirusr "OU=Users,OU=HUFFLAB,DC=hufflab,DC=internal"

# 3) Accounts (9): daily driver, admin, two service accounts, five department users
$password = Read-Host 'Password for lab user accounts' -AsSecureString
$usersRoot = "OU=Users,$root"
New-ADUser -Name 'Levi Huff' -SamAccountName lhuff -Path $usersRoot -Enabled $true -AccountPassword $password
New-ADUser -Name 'Levi Huff (Admin)' -SamAccountName adm-lhuff -Path "OU=Admins,$root" -Enabled $true -AccountPassword $password
'svc-sccm-push','svc-sccm-na' | ForEach-Object {
  New-ADUser -Name $_ -SamAccountName $_ -Path "OU=ServiceAccounts,$root" -Enabled $true -AccountPassword $password }
@{ 'hr.jones'='HR'; 'hr.smith'='HR'; 'fin.brown'='Finance'; 'it.davis'='IT'; 'eng.miller'='Engineering' }.GetEnumerator() | ForEach-Object {
  New-ADUser -Name $_.Key -SamAccountName $_.Key -Path "OU=$($_.Value),OU=Users,$root" -Enabled $true -AccountPassword $password }

# 4) Groups: role = Global, access = Domain Local
'RG-IT-Helpdesk','RG-HR-Staff','RG-Fin-Staff' | ForEach-Object {
  New-ADGroup -Name $_ -GroupScope Global -GroupCategory Security -Path "OU=Role,OU=Groups,$root" }
'AG-Share-HR-Modify','AG-WKS-LocalAdmin' | ForEach-Object {
  New-ADGroup -Name $_ -GroupScope DomainLocal -GroupCategory Security -Path "OU=Access,OU=Groups,$root" }

# 5) AGDLP: users -> role (Global) -> access (Domain Local) -> ACL on \\DC01\HRShare
Add-ADGroupMember -Identity RG-HR-Staff -Members hr.jones, hr.smith
Add-ADGroupMember -Identity AG-Share-HR-Modify -Members RG-HR-Staff
New-Item -Path C:\HRShare -ItemType Directory
New-SmbShare -Name HRShare -Path C:\HRShare -ChangeAccess 'HUFFLAB\AG-Share-HR-Modify'
$acl = Get-Acl C:\HRShare
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule('HUFFLAB\AG-Share-HR-Modify','Modify','ContainerInherit,ObjectInherit','None','Allow')
$acl.AddAccessRule($rule)
Set-Acl -Path C:\HRShare -AclObject $acl
```

**Verify** (expected: HUFFLAB root + six first-level OUs; nine enabled users; three Global role
groups + two DomainLocal access groups; `hr.jones`/`hr.smith` in `RG-HR-Staff`, that group nested in
`AG-Share-HR-Modify`; Modify/Change on `\\DC01\HRShare`):

```powershell
Get-ADOrganizationalUnit -Filter 'Name -eq "HUFFLAB" -or Name -in ("Admins","ServiceAccounts","Users","Groups","Workstations","Servers")' | Select-Object Name, DistinguishedName
@('lhuff','adm-lhuff','svc-sccm-push','svc-sccm-na','hr.jones','hr.smith','fin.brown','it.davis','eng.miller') | ForEach-Object { Get-ADUser -Identity $_ } | Select-Object SamAccountName, Enabled
@('RG-IT-Helpdesk','RG-HR-Staff','RG-Fin-Staff','AG-Share-HR-Modify','AG-WKS-LocalAdmin') | ForEach-Object { Get-ADGroup -Identity $_ } | Select-Object Name, GroupScope
Get-ADGroupMember RG-HR-Staff | Select-Object SamAccountName
Get-ADGroupMember AG-Share-HR-Modify | Select-Object Name
Get-SmbShareAccess -Name HRShare
icacls C:\HRShare
```

**📸 Evidence:** ADUC tree expanded through all HUFFLAB OUs; the AGDLP group-membership chain and the
`HRShare` NTFS/security permissions showing the domain-local access group.

**Exit gate:** verify block passes, then checkpoint the Stage 1 boundary:

```powershell
Checkpoint-VM -Name DC01 -SnapshotName pre-phase-04
```

---

## 4 · Safety rails (do not skip)

- **PXE single-responder rule.** Never set DHCP options **60/66/67**. This is a same-subnet
  broadcast design; the scope built in Phase 02 must stay clean because a single live PXE responder
  (WDS, later ConfigMgr) handles boot — not DHCP options.
- **Patch gate.** Install **KB5060842 or later** and reboot **before** promoting DC01, to avoid the
  WS2025 post-reboot Public-network-profile bug. If a newer CU supersedes it, document that KB/build.
- **Secrets hygiene.** Delete `C:\Windows\Panther\unattend.xml` after first boot; use
  `Read-Host -AsSecureString`; keep passwords out of scripts, transcripts, screenshots, and history.
  If a password lands in evidence, rotate it immediately and redact.
- **AGDLP discipline.** Users → role (Global) → access (Domain Local) → ACL. Never grant a user
  account directly on the share, and never use a Global group directly as the share ACL.
- **Accidental-deletion protection** stays enabled on completed OUs; clear it only for a deliberate,
  approved restructure, then re-enable.
- **Functional level.** Select the GUI-displayed **Windows Server 2025** level (level 10); never
  choose an older level to work around a build difference.
- **RAM budget.** Never exceed 28 GB of VM allocation. In Stage 1 only DC01 runs — keep the rest off.

---

## 5 · Rollback map

Revert **only** the VMs changed in a phase, via **Hyper-V Manager > VM > Checkpoints > Apply** or
`Restore-VMSnapshot`. Export evidence and note the reason before reverting.

| Checkpoint | Taken | Applying it discards |
|---|---|---|
| host restore point / dir backup | before Phase 01 | host-level foundation artifacts (no VM checkpoints exist yet) |
| `pre-phase-02` | before Phase 02 | DC01 promotion, DNS, and DHCP configuration |
| `pre-phase-03` | end of Phase 02 | Phase 03 AD structure / share changes only |
| `pre-phase-04` | end of Phase 03 | boundary into Phase 04 (Stage 1 complete) |

Never run a reverted DC beside an unreverted copy of the same domain controller. Once later phases
or domain members depend on these identities, do not roll back without planning AD recovery. A
checkpoint is not a substitute for a system-state backup once AD DS exists.

---

## 6 · Definition of done (unblocks Phase 04)

Stage 1 is complete when **all** of the following hold:

- [ ] Six Gen 2 VMs exist; five are powered **off** and DC01 is **on**.
- [ ] Phase 02 verify passes: WS2025 FL level 10 forest, both DNS zones + forwarders, authorized
      DHCP scope `.100`–`.199` with options **003/006/015 only**.
- [ ] Phase 03 verify passes: full `HUFFLAB` OU tree, nine enabled accounts, three Global + two
      DomainLocal groups, and the AGDLP chain resolving to Modify on `\\DC01\HRShare`.
- [ ] Checkpoint `pre-phase-04` exists.
- [ ] Every 📸 evidence item (below) is recorded in `docs/lab-notebook.md`.

---

## 7 · Evidence checklist

Record each with **filename, date, phase, command/result, and any variance**, per the
[conventions](../../runbooks/00-conventions.md).

| # | Phase | Evidence |
|---|---|---|
| 1 | 01 | Readiness output (Hyper-V, virtualization, storage, media, parser checks) |
| 2 | 01 | Virtual Switch Manager showing `LabSwitch` + `Get-NetNat` showing `LabNAT` |
| 3 | 02 | DC01 static IPv4 settings + installed KB5060842 (or later) |
| 4 | 02 | DHCP authorization, active scope range, and options 003/006/015 |
| 5 | 03 | ADUC tree expanded through all HUFFLAB OUs |
| 6 | 03 | AGDLP membership chain + `HRShare` NTFS/security permissions |

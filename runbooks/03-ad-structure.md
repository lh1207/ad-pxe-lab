# Phase 03 — AD structure: OUs, users, groups, AGDLP

> **Resume bullet:** #1 · **Est. time:** 2–4 h · **VMs on:** DC01 (4 GB / 28 GB budget)

## Objectives

- Build the canonical HUFFLAB OU tree, accounts, and role/access groups.
- Redirect default computer and user containers, and protect intentional OUs from accidental deletion.
- Demonstrate AGDLP end to end by granting HR users Modify access to `\\DC01\HRShare`.

## Prerequisites

- Phase 02 verifies AD DS, DNS, and DHCP. DC01 is the only powered-on VM (4 GB).
- Create Hyper-V checkpoint `pre-phase-03` if it does not already exist. Sign in as
  `HUFFLAB\Administrator` or a delegated equivalent; the displayed password example `LabP@ss2026!`
  must be replaced with your own secure value.
- This phase intentionally does not create GPOs; Phase 05 owns password-policy and GPO configuration.

## Steps

1. In **Server Manager > Tools > Active Directory Users and Computers**, enable **View > Advanced
   Features**. Create root OU `HUFFLAB` at the domain root, then create `Admins`, `ServiceAccounts`,
   `Users`, `Groups`, `Workstations`, and `Servers`. Under `Users`, create `IT`, `HR`, `Finance`, and
   `Engineering`; under `Groups`, create `Role` and `Access`. In each OU's **Object** tab, clear
   **Protect object from accidental deletion** only long enough to restructure it, then ensure it is
   selected for the completed OUs.

   ```powershell
   $domainDn = (Get-ADDomain).DistinguishedName
   $root = "OU=HUFFLAB,$domainDn"
   New-ADOrganizationalUnit -Name HUFFLAB -Path $domainDn -ProtectedFromAccidentalDeletion $true
   'Admins','ServiceAccounts','Users','Groups','Workstations','Servers' | ForEach-Object {
     New-ADOrganizationalUnit -Name $_ -Path $root -ProtectedFromAccidentalDeletion $true
   }
   'IT','HR','Finance','Engineering' | ForEach-Object {
     New-ADOrganizationalUnit -Name $_ -Path "OU=Users,$root" -ProtectedFromAccidentalDeletion $true
   }
   'Role','Access' | ForEach-Object {
     New-ADOrganizationalUnit -Name $_ -Path "OU=Groups,$root" -ProtectedFromAccidentalDeletion $true
   }
   ```

   📸 Evidence: Active Directory Users and Computers tree expanded through all HUFFLAB OUs.

2. Redirect new computer and user objects to the lab OUs. Run these commands from an elevated Command
   Prompt or PowerShell on DC01; the console equivalent is intentionally absent because `redircmp` and
   `redirusr` are the supported command-line tools.

   ```powershell
   redircmp "OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal"
   redirusr "OU=Users,OU=HUFFLAB,DC=hufflab,DC=internal"
   ```

3. Create the named people and service accounts. In **Active Directory Users and Computers**, right-click
   the target OU, choose **New > User**, and assign a unique password that is not the example. Create
   `lhuff` under Users as the daily driver, `adm-lhuff` under Admins as the separate administrator, the
   two service accounts under ServiceAccounts, and the five sample department users in their matching
   OUs. Set service accounts to non-interactive use. Consider adding `adm-lhuff` to Protected Users only
   after understanding its authentication restrictions.

   ```powershell
   $password = Read-Host 'Password for lab user accounts' -AsSecureString
   $usersRoot = "OU=Users,$root"
   New-ADUser -Name 'Levi Huff' -SamAccountName lhuff -Path $usersRoot -Enabled $true -AccountPassword $password
   New-ADUser -Name 'Levi Huff (Admin)' -SamAccountName adm-lhuff -Path "OU=Admins,$root" -Enabled $true -AccountPassword $password
   'svc-sccm-push','svc-sccm-na' | ForEach-Object {
     New-ADUser -Name $_ -SamAccountName $_ -Path "OU=ServiceAccounts,$root" -Enabled $true -AccountPassword $password
   }
   @{ 'hr.jones'='HR'; 'hr.smith'='HR'; 'fin.brown'='Finance'; 'it.davis'='IT'; 'eng.miller'='Engineering' }.GetEnumerator() | ForEach-Object {
     New-ADUser -Name $_.Key -SamAccountName $_.Key -Path "OU=$($_.Value),OU=Users,$root" -Enabled $true -AccountPassword $password
   }
   ```

   `svc-sccm-push` is reserved for Configuration Manager client push. `svc-sccm-na` is the network
   access account learning artifact; modern Configuration Manager uses Enhanced HTTP over NAA where
   possible, so do not design new workflows around broad NAA use.

4. Create the canonical groups in **Active Directory Users and Computers > HUFFLAB > Groups**. Create
   `RG-IT-Helpdesk`, `RG-HR-Staff`, and `RG-Fin-Staff` as **Global/Security** groups in `Role`; create
   `AG-Share-HR-Modify` and `AG-WKS-LocalAdmin` as **Domain Local/Security** groups in `Access`.

   ```powershell
   'RG-IT-Helpdesk','RG-HR-Staff','RG-Fin-Staff' | ForEach-Object {
     New-ADGroup -Name $_ -GroupScope Global -GroupCategory Security -Path "OU=Role,OU=Groups,$root"
   }
   'AG-Share-HR-Modify','AG-WKS-LocalAdmin' | ForEach-Object {
     New-ADGroup -Name $_ -GroupScope DomainLocal -GroupCategory Security -Path "OU=Access,OU=Groups,$root"
   }
   ```

5. Build the AGDLP demo. Add `hr.jones` and `hr.smith` to `RG-HR-Staff`; nest that global group in
   `AG-Share-HR-Modify`. In **File Explorer** on DC01, create `C:\HRShare`, then **Properties > Sharing
   > Advanced Sharing**; share it as `HRShare`. In **Security**, grant `HUFFLAB\AG-Share-HR-Modify`
   Modify permission on both the share and NTFS ACL. Do not grant user accounts directly.

   ```powershell
   Add-ADGroupMember -Identity RG-HR-Staff -Members hr.jones, hr.smith
   Add-ADGroupMember -Identity AG-Share-HR-Modify -Members RG-HR-Staff
   New-Item -Path C:\HRShare -ItemType Directory
   New-SmbShare -Name HRShare -Path C:\HRShare -ChangeAccess 'HUFFLAB\AG-Share-HR-Modify'
   $acl = Get-Acl C:\HRShare
   $rule = New-Object System.Security.AccessControl.FileSystemAccessRule('HUFFLAB\AG-Share-HR-Modify','Modify','ContainerInherit,ObjectInherit','None','Allow')
   $acl.AddAccessRule($rule)
   Set-Acl -Path C:\HRShare -AclObject $acl
   ```

   📸 Evidence: group membership chain and the `HRShare` NTFS/security permissions showing the
   domain-local access group.

6. Document the result in the lab notebook and create `pre-phase-04` only after the verification
   commands succeed.

   ```powershell
   Checkpoint-VM -Name DC01 -SnapshotName pre-phase-04
   ```

## Verify

```powershell
Get-ADOrganizationalUnit -Filter 'Name -eq "HUFFLAB" -or Name -in ("Admins","ServiceAccounts","Users","Groups","Workstations","Servers")' |
  Select-Object Name, DistinguishedName
```

Expected output includes the HUFFLAB root and all six first-level OUs. The Users and Groups child OUs
also appear when queried beneath their distinguished names.

```powershell
@('lhuff','adm-lhuff','svc-sccm-push','svc-sccm-na','hr.jones','hr.smith','fin.brown','it.davis','eng.miller') |
  ForEach-Object { Get-ADUser -Identity $_ } | Select-Object SamAccountName, Enabled
@('RG-IT-Helpdesk','RG-HR-Staff','RG-Fin-Staff','AG-Share-HR-Modify','AG-WKS-LocalAdmin') |
  ForEach-Object { Get-ADGroup -Identity $_ } | Select-Object Name, GroupScope
```

Expected output lists all nine enabled user accounts and the three Global role groups plus two
DomainLocal access groups.

```powershell
Get-ADGroupMember RG-HR-Staff | Select-Object SamAccountName
Get-ADGroupMember AG-Share-HR-Modify | Select-Object Name
Get-SmbShareAccess -Name HRShare
icacls C:\HRShare
```

Expected output shows `hr.jones` and `hr.smith` in `RG-HR-Staff`, `RG-HR-Staff` nested in
`AG-Share-HR-Modify`, and Modify/Change access for `HUFFLAB\AG-Share-HR-Modify` on `\\DC01\HRShare`.

## Rollback

Apply `pre-phase-03` to remove all Phase 03 directory and share changes, then re-run this phase from
the start. If keeping Phase 02 but selectively undoing an object, remove it in **Active Directory Users
and Computers** only after confirming dependencies; protected OUs require deliberate unprotection.
Do not delete groups while their ACLs remain on `C:\HRShare`, and do not roll back once later phases
depend on these identities without reconciling those dependencies.

## Troubleshoot

1. **An OU cannot be deleted or moved.** This is usually intentional accidental-deletion protection.
   Inspect the flag, temporarily clear it only for an approved restructure, then re-enable it.

   ```powershell
   Get-ADOrganizationalUnit -Identity "OU=HUFFLAB,DC=hufflab,DC=internal" -Properties ProtectedFromAccidentalDeletion |
     Select-Object Name, ProtectedFromAccidentalDeletion
   ```

2. **`redircmp` or `redirusr` rejects the distinguished name.** Confirm all parent OUs exist and quote
   the complete DN exactly; these commands do not create missing OUs.

   ```powershell
   Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName
   ```

3. **A user cannot access `\\DC01\HRShare`.** Verify the AGDLP chain and both share and NTFS ACLs; log
   off/on after changing group membership so the access token refreshes.

   ```powershell
   Get-ADGroupMember RG-HR-Staff
   Get-ADGroupMember AG-Share-HR-Modify
   Get-SmbShareAccess HRShare
   ```

4. **A group has the wrong scope.** Create a replacement with the canonical scope and migrate members
   before deleting the incorrect group; do not use a Global group directly as a share ACL in this demo.

   ```powershell
   Get-ADGroup -Identity AG-Share-HR-Modify -Properties GroupScope | Select-Object Name, GroupScope
   ```

5. **A service account is used interactively.** Remove unneeded interactive rights, rotate its password,
   and document its intended role. `svc-sccm-na` is a learning artifact; prefer Enhanced HTTP over NAA
   in modern Configuration Manager.

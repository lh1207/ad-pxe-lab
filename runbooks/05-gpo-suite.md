# Phase 05 — GPO suite

> **Resume bullet:** #1 · **Est. time:** 2–3 h · **VMs on:** DC01+CL02 (8 GB / 28 GB budget)

## Objectives

- Manage domain password settings only through Default Domain Policy and practice one PSO drill.
- Apply the required computer baseline to the Workstations OU.
- Deliver an HR-targeted `H:` drive map with Group Policy Preferences and verify resultant policy.

## Prerequisites

- Complete Phases 02–04. DC01 (4 GB) and domain-joined CL02 (4 GB) consume 8 GB of the 28 GB
  VM budget. CL02 must be in `OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal`.
- Confirm Phase 03 created `RG-HR-Staff`, `AG-WKS-LocalAdmin`, HR users, and `\\DC01\HRShare`.
  Ensure `hr.jones` belongs to `RG-HR-Staff` for the drive-map test.
- Create Hyper-V checkpoint `pre-phase-05` for DC01 and CL02. Use a delegated admin account as
  appropriate; the documented `LabP@ss2026!` is only an example and must be replaced.

## Steps

1. On DC01, open **Group Policy Management** from Server Manager → **Tools**. Expand
   **Forest: hufflab.internal** → **Domains** → **hufflab.internal** → **Group Policy Objects**;
   right-click **Default Domain Policy** → **Edit**. Navigate to **Computer Configuration** →
   **Policies** → **Windows Settings** → **Security Settings** → **Account Policies** →
   **Password Policy**. Set the lab policy deliberately, for example: minimum length 14,
   complexity enabled, history 24, and maximum age 90 days. Do not create a separate password
   GPO; domain password policy belongs only in Default Domain Policy.

   PowerShell equivalent:

   ```powershell
   Set-ADDefaultDomainPasswordPolicy -Identity 'hufflab.internal' -MinPasswordLength 14 `
     -ComplexityEnabled $true -PasswordHistoryCount 24 -MaxPasswordAge (New-TimeSpan -Days 90)
   ```

2. For the fine-grained password-policy drill, in **Active Directory Administrative Center** →
   **Tree View** → `hufflab.internal` → **System** → **Password Settings Container**, choose
   **New** → **Password Settings**. Create `PSO-Admins-Strong` with precedence 10 and assign it
   to `adm-lhuff` (or a dedicated administrator group). This drill supplements, not replaces,
   Default Domain Policy.

   PowerShell equivalent:

   ```powershell
   New-ADFineGrainedPasswordPolicy -Name 'PSO-Admins-Strong' -Precedence 10 `
     -ComplexityEnabled $true -MinPasswordLength 16 -PasswordHistoryCount 24 `
     -MaxPasswordAge (New-TimeSpan -Days 60) -LockoutThreshold 5
   Add-ADFineGrainedPasswordPolicySubject -Identity 'PSO-Admins-Strong' -Subjects 'adm-lhuff'
   ```

3. In **Group Policy Management**, right-click the **Workstations** OU → **Create a GPO in this
   domain, and Link it here**. Name it `GPO-C-Workstation-Baseline`, then edit it. Configure:

   - **Computer Configuration** → **Policies** → **Administrative Templates** → **System** →
     **Removable Storage Access** → **All Removable Storage classes: Deny all access** = Enabled.
   - **Computer Configuration** → **Policies** → **Windows Settings** → **Security Settings** →
     **Local Policies** → **Security Options** → **Interactive logon: Message title/text for users
     attempting to log on** = the approved lab-use banner.
   - **Computer Configuration** → **Policies** → **Windows Settings** → **Security Settings** →
     **Local Policies** → **Security Options** → **Interactive logon: Machine inactivity limit**
     = `900` seconds.

   PowerShell equivalent for creation and link; use the editor above for policy settings:

   ```powershell
   New-GPO -Name 'GPO-C-Workstation-Baseline'
   New-GPLink -Name 'GPO-C-Workstation-Baseline' -Target 'OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal'
   ```

4. In **Group Policy Management**, right-click **Users** under the HUFFLAB OU → **Create a GPO
   in this domain, and Link it here**. Name it `GPO-U-IT-DriveMaps` and edit it. Navigate to
   **User Configuration** → **Preferences** → **Windows Settings** → **Drive Maps** → **New** →
   **Mapped Drive**. Set Action to **Update**, Location to `\\DC01\HRShare`, Label to `HRShare`,
   and Drive Letter to `H:`. On **Common**, select **Item-level targeting** → **Targeting** →
   **New Item** → **Security Group**, then choose `RG-HR-Staff`.

   PowerShell equivalent for creation and link; configure the preference and item-level targeting
   in the GUI because GroupPolicy cmdlets do not provide a supported first-class GPP drive-map
   authoring command:

   ```powershell
   New-GPO -Name 'GPO-U-IT-DriveMaps'
   New-GPLink -Name 'GPO-U-IT-DriveMaps' -Target 'OU=Users,OU=HUFFLAB,DC=hufflab,DC=internal'
   ```

5. On CL02, sign in first as `HUFFLAB\hr.jones`. Open an elevated Command Prompt and run a policy
   refresh, then sign out and back in so user preferences apply. Confirm `H:` opens
   `\\DC01\HRShare`; the access is governed by the Phase 03 AGDLP chain.

   PowerShell equivalent:

   ```powershell
   gpupdate /force
   Get-PSDrive -Name H
   ```

6. On CL02, force computer policy, wait for the 900-second inactivity behavior only in a safe
   test window, and use a removable USB device only if safe for the host. Confirm the interactive
   logon banner at the next logon and that removable storage is denied.

   PowerShell equivalent:

   ```powershell
   gpupdate /target:computer /force
   gpresult /scope computer /r
   ```

   📸 Evidence: Capture the GPO links, the Drive Maps item-level target, the CL02 banner, an
   `H:` mapping under `hr.jones`, and a `gpresult` showing both policies.

## Verify

```powershell
Get-ADDefaultDomainPasswordPolicy | Select-Object MinPasswordLength, ComplexityEnabled, PasswordHistoryCount, MaxPasswordAge
# Expected: 14, True, 24, and 90 days (or the approved lab values).
```

```powershell
Get-ADUserResultantPasswordPolicy -Identity 'adm-lhuff' | Select-Object Name, MinPasswordLength, LockoutThreshold
# Expected: PSO-Admins-Strong, 16, and 5.
```

```powershell
Get-GPInheritance -Target 'OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal' | Select-Object -ExpandProperty GpoLinks
# Expected: GPO-C-Workstation-Baseline is linked.
```

```powershell
gpresult /h "$env:TEMP\CL02-gpo.html"
# Expected: report lists GPO-C-Workstation-Baseline and, for hr.jones, GPO-U-IT-DriveMaps.
```

```powershell
Get-PSDrive -Name H
# Expected when signed in as hr.jones: H uses \\DC01\HRShare.
```

## Rollback

Restore `pre-phase-05` checkpoints to undo the suite wholesale. For a targeted rollback, unlink
the relevant GPO from its OU before deleting it, remove `PSO-Admins-Strong` only after removing
its subjects, and retain Default Domain Policy rather than deleting or replacing it. Export GPO
backups before material edits.

## Troubleshoot

- **CL02 does not receive the workstation baseline:** verify its OU with
  `Get-ADComputer CL02 -Properties DistinguishedName`; run `gpupdate /force` and inspect
  `gpresult /r` as an administrator.
- **`H:` is missing:** verify `hr.jones` is a direct or nested member of `RG-HR-Staff` with
  `Get-ADPrincipalGroupMembership hr.jones`, then log off and on after `gpupdate /force`.
- **`H:` maps but access is denied:** test `Test-Path '\\DC01\HRShare'` and review the Phase 03
  share and NTFS ACLs for `AG-Share-HR-Modify`; a mapped drive does not grant permissions.
- **Password setting appears ignored:** domain password settings must be in Default Domain Policy;
  use `Get-ADDefaultDomainPasswordPolicy`. A PSO applies only to its explicitly assigned subject.
- **Banner or USB policy is absent:** inspect the exact computer policy path in the editor and
  generate `gpresult /h`; check for security filtering or a higher-precedence conflicting GPO.

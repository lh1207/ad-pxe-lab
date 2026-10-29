# Phase 05 attended configuration

Run only on local Windows host WOLF, using the saved project at `C:\HyperV\ad-pxe-lab`.
The authoritative runbook is [05-gpo-suite.md](../../runbooks/05-gpo-suite.md).
Keep credentials out of chat and evidence. Administrator recovery is already complete.

> **Completion notice, 2026-10-28:** Phase 05 has passed its attended final gate. The finalizer
> recorded Standard `pre-phase-06` checkpoints on DC01
> (`69c63c35-f7aa-4dec-add4-37358ef7b111`) and CL02
> (`56d7c809-6470-4737-a610-8477a10e4eb1`). The instructions below are retained as the executed
> record; do not rerun them. Physical USB denial and the timed 900-second inactivity behavior were
> not exercised because the runbook permits those tests only in a safe test window.

For the short remaining acceptance list, use [verification checklist](phase-05-verification-checklist.md).

## 1. Initialize with a visible elevated host session

In **Administrator Windows PowerShell on WOLF**, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\HyperV\ad-pxe-lab\scripts\05-InitializeGpoSuite.ps1
```

Enter the saved `HUFFLAB\Administrator` password only in the credential prompt. The helper
rechecks host and guest prerequisites, backs up the two original GPOs, creates the administrator
PSO, and creates/links the two new GPOs. It stops at `GUI_REQUIRED`. It does not configure the
domain password policy, workstation settings, or drive-map preference. If it fails, return to
Codex with the result; do not rerun it against potentially partial state.

## 2. Configure Default Domain Policy on DC01

In the DC01 console, signed in as `HUFFLAB\Administrator`, open **Server Manager → Tools →
Group Policy Management**. Expand **Forest → Domains → hufflab.internal → Group Policy Objects**.
Right-click **Default Domain Policy → Edit**. Navigate to:

**Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies →
Password Policy**. Save these four settings:

| Setting | Value |
|---|---|
| Minimum password length | 14 characters |
| Password must meet complexity requirements | Enabled |
| Enforce password history | 24 passwords remembered |
| Maximum password age | 90 days |

Preserve all other settings. Close that editor. Do not create another password GPO.

## 3. Configure the workstation baseline

Edit the existing **GPO-C-Workstation-Baseline** in Group Policy Objects. The helper already links
it to **HUFFLAB → Workstations**; do not create a duplicate or add another link.

Check the editor's left-tree root says **GPO-C-Workstation-Baseline**, not **Default Domain Policy**.
Close the Default Domain Policy editor first to avoid configuring the baseline in the domain-wide
policy. The message **title** is the short HUFFLAB label; the message **text** is the longer sentence.

Under **Computer Configuration → Policies → Administrative Templates → System → Removable Storage
Access**, set **All Removable Storage classes: Deny all access** to **Enabled**.

Under **Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies →
Security Options**, define these settings:

| Setting | Value |
|---|---|
| Interactive logon: Message title for users attempting to log on | HUFFLAB - Authorized Lab Use |
| Interactive logon: Message text for users attempting to log on | This system is for authorized HUFFLAB training and administration only. Activity may be monitored. |
| Interactive logon: Machine inactivity limit | 900 seconds |

Save each setting and close the editor.

The operator accepts either a regular hyphen or an em dash in the title. The verifier accepts
both; punctuation alone is not a reason to edit an already saved banner.

## 4. Configure the HR-targeted preference

Edit the existing **GPO-U-IT-DriveMaps**, already linked to **HUFFLAB → Users**. Navigate to
**User Configuration → Preferences → Windows Settings → Drive Maps**. Choose **New → Mapped Drive**:

| Field | Value |
|---|---|
| Action | Update |
| Location | `\\DC01\HRShare` |
| Label as | HRShare |
| Drive letter | Use H: |

On **Common**, select **Item-level targeting → Targeting → New Item → Security Group**.
Choose **HUFFLAB\RG-HR-Staff**, with **User in group** and positive membership. Save the targeting
and mapped-drive dialogs. Leave GPO security filtering at its default; the item-level target selects
HR users. Capture the target and GPMC links with no credentials visible.

## 5. Refresh DC01 and run the verifier

After saving all GPMC settings, use elevated PowerShell **inside DC01** to refresh its computer
policy so the edited Default Domain Policy reaches the domain's effective password settings:

```powershell
gpupdate /target:computer /force /wait:120
```

Then use **Administrator Windows PowerShell on WOLF** to run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\HyperV\ad-pxe-lab\scripts\05-Test-GpoConfiguration.ps1
```

Enter the saved administrator password only in its prompt. Tell Codex when the verifier ends;
it will inspect the saved evidence. Configuration is not the final gate: a normal
`HUFFLAB\hr.jones` interactive drive-map test, banner evidence, RSOP inspection, and final
assertions remain required. Do not create `pre-phase-06` checkpoints yet.

The prepared `scripts/05-Test-GpoConfiguration.ps1` helper checks saved GPO templates, targeting,
the PSO, and effective CL02 registry values, exports reports/backups and computer RSOP XML,
and leaves RSOP inspection plus HR interactive evidence pending. The 2026-10-28 03:39 EDT run
passes these checks; Codex subsequently verifies the exported computer RSOP. If a later run
fails, preserve its output for inspection.

## 6. Normal HR user acceptance on CL02

After Codex confirms the computer checks, sign in interactively on CL02 as `HUFFLAB\hr.jones`.
Use normal, non-elevated PowerShell for `gpupdate /target:user /force`, then sign out and sign
back in. Record whether the approved banner appears. In the new HR session, run:

```powershell
whoami
Get-PSDrive H | Select-Object Name,Root,DisplayRoot
Test-Path H:\
gpresult /scope user /r
```

Expected: `hufflab\hr.jones`, `H:` targeting `\\DC01\HRShare`, `True` for share access, and
`GPO-U-IT-DriveMaps` under applied user policies. Capture the output without credentials and
return to Codex for final assertions. A different administrator session cannot prove this test.

## 7. Final assertions and Phase 06 checkpoints

After Codex records the normal HR-user test and banner evidence, run in **Administrator Windows
PowerShell on WOLF**:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\HyperV\ad-pxe-lab\scripts\05-FinalizeGpoSuite.ps1
```

The finalizer prompts once for the saved domain administrator credential in memory. It runs fresh
configuration checks, exports and asserts computer/user RSOP, checks live guest and host readiness,
then creates and verifies standard `pre-phase-06` checkpoints for DC01 and CL02. Expected final
line is `PHASE 05 FINAL GATE: PASS`. Return to Codex to audit the transcript and save the receipt.
If it fails, retain all evidence and any partial checkpoint state; do not rerun blindly or delete
checkpoints. It refuses to create duplicates.

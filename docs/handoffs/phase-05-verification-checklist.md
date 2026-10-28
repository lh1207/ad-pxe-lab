# Phase 05 remaining verification checklist

Already recorded: the approved CL02 banner screenshot, normal hr.jones console output,
H: share access, applied user GPO, latest configuration pass, and computer RSOP assertions.
Do not repeat initialization or password recovery. A regular hyphen in the banner is accepted.

## 1. Capture the two GPO links on DC01

Open **Server Manager → Tools → Group Policy Management** and expand the domain and HUFFLAB.

- [ ] Select **Workstations → Linked Group Policy Objects**. Capture
  `GPO-C-Workstation-Baseline`, **Link Enabled = Yes**, **Enforced = No**.
  Suggested filename: `gpmc-workstations-link.png`.
- [ ] Select **Users → Linked Group Policy Objects**. Capture
  `GPO-U-IT-DriveMaps`, **Link Enabled = Yes**, **Enforced = No**.
  Suggested filename: `gpmc-users-link.png`.

## 2. Capture the HR mapping and target on DC01

Right-click **GPO-U-IT-DriveMaps → Edit**. Check the editor's root name before proceeding.
Navigate to **User Configuration → Preferences → Windows Settings → Drive Maps**.

- [ ] Capture the H: item with **Update**, location `\\DC01\HRShare`, label **HRShare**, letter **H:**.
- [ ] Open its **Common → Item-level targeting → Targeting** window. Capture the positive
  **User in group HUFFLAB\RG-HR-Staff** target. Suggested filename: `hr-drive-map-targeting.png`.

If test entries or extra targets remain, send the screenshot before changing them. The verifier
expects the intended HR membership target; do not delete GPOs or loosen checks blindly.

## 3. Run the final gate on WOLF

Close GPO editors and wait for any policy refresh/restart to finish. Use **Administrator Windows
PowerShell on WOLF**, not the guest and not the normal HR-user shell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\HyperV\ad-pxe-lab\scripts\05-FinalizeGpoSuite.ps1
```

- [ ] Enter the saved domain administrator credential only in its prompt.
- [ ] Expected last line: **PHASE 05 FINAL GATE: PASS**.
- [ ] Capture that result. The script records the assertion log locally and creates the two
  standard checkpoints only after the required checks pass.

If it fails, send the error and leave the current state alone. If it reports an existing
pre-phase-06 checkpoint, do not delete or recreate it; send the output for inspection.

## 4. Capture the checkpoint boundary on WOLF

In Hyper-V Manager:

- [ ] Select **DC01** and capture its `pre-phase-06` checkpoint.
- [ ] Select **CL02** and capture its `pre-phase-06` checkpoint.
- [ ] Confirm the finalizer log identifies both checkpoints as **Standard** and records their IDs.
  Suggested filenames: `dc01-pre-phase-06.png`, `cl02-pre-phase-06.png`.

Send the screenshots here or save them under `docs/evidence/phase-05/`. Keep passwords,
credential prompts, password managers, product keys and unrelated personal windows out of them.

## 5. Finish the record

- [ ] Codex inspects the new finalizer transcript, user/computer RSOP and checkpoint records.
- [ ] Codex updates the notebook and canonical Phase 05 final gate from actual evidence.
- [ ] Codex updates the PR and project memory, then writes a completion receipt.

Physical USB denial and the timed 900-second lock behavior have not been recorded as exercised.
Only test those in a safe lab window with a disposable device; otherwise retain the explicit
not-exercised note. Registry/policy configuration is already verified.

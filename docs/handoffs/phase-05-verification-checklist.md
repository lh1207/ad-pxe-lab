# Phase 05 verification record

Completed 2026-10-28: the attended finalizer reports `PHASE 05 FINAL GATE: PASS` after fresh
configuration, computer RSOP, and HR-user RSOP assertions. It created the Standard
`pre-phase-06` checkpoints on DC01 (`69c63c35-f7aa-4dec-add4-37358ef7b111`) and CL02
(`56d7c809-6470-4737-a610-8477a10e4eb1`). Do not repeat initialization, recovery, or the
finalizer. A regular hyphen in the banner is accepted.

## 1. Capture the two GPO links on DC01

Open **Server Manager → Tools → Group Policy Management** and expand the domain and HUFFLAB.

- [x] Selected **Workstations → Linked Group Policy Objects** and captured
  `GPO-C-Workstation-Baseline`, **Link Enabled = Yes**, **Enforced = No**.
  Suggested filename: `gpmc-workstations-link.png`.
- [x] Selected **Users → Linked Group Policy Objects** and captured
  `GPO-U-IT-DriveMaps`, **Link Enabled = Yes**, **Enforced = No**.
  Suggested filename: `gpmc-users-link.png`.

## 2. Capture the HR mapping and target on DC01

Right-click **GPO-U-IT-DriveMaps → Edit**. Check the editor's root name before proceeding.
Navigate to **User Configuration → Preferences → Windows Settings → Drive Maps**.

- [x] Captured the H: item with **Update**, location `\\DC01\HRShare`, label **HRShare**, letter **H:**.
- [x] Opened its **Common → Item-level targeting → Targeting** window and captured the positive
  **User in group HUFFLAB\RG-HR-Staff** target. Suggested filename: `hr-drive-map-targeting.png`.

If test entries or extra targets remain, send the screenshot before changing them. The verifier
expects the intended HR membership target; do not delete GPOs or loosen checks blindly.

## 3. Final gate on WOLF

Close GPO editors and wait for any policy refresh/restart to finish. Use **Administrator Windows
PowerShell on WOLF**, not the guest and not the normal HR-user shell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\HyperV\ad-pxe-lab\scripts\05-FinalizeGpoSuite.ps1
```

- [x] Entered the saved domain administrator credential only in its prompt.
- [x] Final line: **PHASE 05 FINAL GATE: PASS**.
- [x] Captured the result in `docs/evidence/phase-05/phase-05-final-gate-and-checkpoints.png`.
  The script records the assertion log locally and created the two standard checkpoints only
  after the required checks passed.

If it fails, send the error and leave the current state alone. If it reports an existing
pre-phase-06 checkpoint, do not delete or recreate it; send the output for inspection.

## 4. Checkpoint boundary on WOLF

In Hyper-V Manager:

- [x] Finalizer records one Standard `pre-phase-06` checkpoint on DC01:
  `69c63c35-f7aa-4dec-add4-37358ef7b111`.
- [x] Finalizer records one Standard `pre-phase-06` checkpoint on CL02:
  `56d7c809-6470-4737-a610-8477a10e4eb1`.
- [x] Captured the final gate after checkpoint creation; the finalizer log contains both IDs.

Send the screenshots here or save them under `docs/evidence/phase-05/`. Keep passwords,
credential prompts, password managers, product keys and unrelated personal windows out of them.

## 5. Finish the record

- [x] Codex inspected the finalizer transcript, user/computer RSOP and checkpoint records.
- [x] Notebook and canonical Phase 05 final gate are updated from actual evidence.
- [x] Publication is open as [PR #6](https://github.com/lh1207/ad-pxe-lab/pull/6).
- [ ] Root saves the completed project-memory receipt.

Physical USB denial and the timed 900-second lock behavior have not been recorded as exercised.
Only test those in a safe lab window with a disposable device; otherwise retain the explicit
not-exercised note. Registry/policy configuration is already verified.

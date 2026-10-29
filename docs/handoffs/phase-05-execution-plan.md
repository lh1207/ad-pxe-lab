# Phase 05 execution plan

## Completed boundary — 2026-10-28

The attended finalizer completes at 20:40 EDT with `PHASE 05 FINAL GATE: PASS`. It reruns the
configuration verifier, validates fresh computer and HR-user RSOP, and records the required
standard `pre-phase-06` checkpoints: DC01
`69c63c35-f7aa-4dec-add4-37358ef7b111` at 20:40:21 and CL02
`56d7c809-6470-4737-a610-8477a10e4eb1` at 20:40:29. Only DC01 and CL02 were running.
Publication branch: `codex/phase-05-gpo-suite`. Publication is open as
[PR #6](https://github.com/lh1207/ad-pxe-lab/pull/6); Root will add the completion evidence and
project-memory record in a follow-up commit.

## Requirements and progress

- [x] Phase 04 boundary and existing standard pre-phase-05 checkpoints verified.
- [x] Administrator recovery completed; normal console sign-in confirmed. Do not repeat recovery.
- [x] Elevated Windows WOLF host and both guest prerequisites verified.
- [x] Original GPOs backed up before mutation; PSO and exact OU links created and asserted.
- [x] Default Domain Policy saved/effective password policy verified: 14/True/24/90 days.
- [x] PSO-Admins-Strong verified for adm-lhuff: precedence 10, length 16, history 24,
  maximum age 60 days, minimum age one day, threshold five, ten-minute duration/window,
  reversible encryption disabled, accidental-deletion protection enabled.
- [x] Workstation baseline and HR-targeted preference saved and verified; final GPO reports/backups exported.
- [x] CL02 effective computer settings and applied baseline RSOP verified.
- [x] Visible banner and normal hr.jones H: target/access/applied user GPO recorded.
- [x] Fresh finalizer PASS and standard pre-phase-06 checkpoints on DC01 and CL02.
- [x] Native GPMC link and HR-target screenshot evidence captured, including final-gate capture.

## Portable evidence

See [Phase 05 verification](../phase-05-configuration-verification.txt) and
[portable evidence](../evidence/phase-05/README.md). The evidence includes the latest successful
configuration transcript, summarized computer RSOP assertions, the operator-pasted normal HR
console output and banner screenshot. Full RSOP, GPMC exports, manifests and backups stay local
under the publication boundary verified against merged PRs #3–#5.

The normal HR test proves hufflab\hr.jones, H: to \\DC01\HRShare, accessible True, the applied
GPO-U-IT-DriveMaps, CONSOLE LOGON, and Medium Mandatory Level. The finalizer adds fresh saved
user RSOP and direct applied-GPO assertions before it creates the checkpoint boundary.

The operator approves either a regular hyphen or an em dash in the banner title. Do not change
punctuation merely to satisfy a verifier. Physical USB and timed inactivity behavior are not
recorded as exercised. Screenshot capture/rendering limitations are documented with the exports.

## Completion record

Do not rerun initialization, recovery, or the finalizer simply to recreate evidence. The finalizer
already records the required source and resultant policy assertions, DC01 service state, CL02
domain/DNS/secure-channel state, fresh computer and user RSOP, and the checkpoint boundary. Use
the retained `pre-phase-05` checkpoints only for a deliberate wholesale rollback.

## Publication checklist

The operator authorizes matching the prior public categories: reviewed scripts/docs, concise
verification text, curated screenshots and scoped project memory. Full report/backup artifacts
are excluded from every reachable unpushed commit before retrying the push. The rejected initial
commit is superseded locally; it is not published through another transport.

- [x] Verify latest configuration pass and saved finalizer status.
- [x] Create publication branch while preserving unrelated local work.
- [x] Curate portable evidence; exclude raw recovery/session artifacts and local tools.
- [x] Windows PowerShell 5.1 parser and 24 inheritance-guard regression cases pass.
- [x] Commit the precedent-matched payload; excluded raw exports are absent from branch history.
- [x] Published [PR #6](https://github.com/lh1207/ad-pxe-lab/pull/6) from the reviewed branch.
- [x] Save the publication outcome to project memory and write the local completion receipt.
  Phase 05 final gate is complete; the receipt remains local under the publication boundary.

# Phase 05 execution plan

## Current boundary — 2026-10-28

Operator requests branch and PR publication after reporting a pass. The latest saved
configuration verifier (18:20 EDT) passes. The latest saved finalizer remains the 04:25 FAIL
at its Drive Maps targeting assertion; no newer finalizer PASS or pre-phase-06 checkpoint
record is available. A configuration pass is not a checkpoint-creation record.
Publication branch: `codex/phase-05-gpo-suite`. Publish as draft with the remaining gate explicit.

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
- [ ] Fresh finalizer PASS and standard pre-phase-06 checkpoints on DC01 and CL02.
- [ ] Complete remaining native GPMC link/target screenshot evidence.

## Portable evidence

See [Phase 05 verification](../phase-05-configuration-verification.txt) and
[portable evidence](../evidence/phase-05/README.md). The evidence includes the latest successful
configuration transcript, summarized computer RSOP assertions, the operator-pasted normal HR
console output and banner screenshot. Full RSOP, GPMC exports, manifests and backups stay local
under the publication boundary verified against merged PRs #3–#5.

The normal HR test proves hufflab\hr.jones, H: to \\DC01\HRShare, accessible True, the applied
GPO-U-IT-DriveMaps, CONSOLE LOGON, and Medium Mandatory Level. Its timestamp is 03:54 EDT;
it is preserved historical user-session evidence, not a fresh finalizer session.

The operator approves either a regular hyphen or an em dash in the banner title. Do not change
punctuation merely to satisfy a verifier. Physical USB and timed inactivity behavior are not
recorded as exercised. Screenshot capture/rendering limitations are documented with the exports.

## Resume the remaining gate

1. Keep the existing pre-phase-05 checkpoints and configuration. Do not rerun initialization,
   reset accounts, or use the old pending-script runner.
2. Inspect current Drive Maps targeting if finalization still rejects it. Verify the positive
   RG-HR-Staff membership target; do not loosen checks or recreate GPOs blindly.
3. Follow [operator steps](phase-05-operator-steps.md), especially the attended finalizer in
   Administrator Windows PowerShell on WOLF. It uses only in-memory prompted credentials.
4. Inspect the finalizer transcript and fresh computer/user RSOP. It must prove the required
   GPO applications, domain/DNS/secure channel, service readiness, and exact VM boundary.
5. Only then create/verify standard pre-phase-06 checkpoints. The finalizer refuses duplicates
   and non-standard checkpoint configuration, and preserves partial state on failure.
6. Update notebook, canonical final gate, and persistence receipt from actual evidence.

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
- [ ] Push and create/attach draft PR; automatic review requires exact commit/public-destination approval.
- [ ] Save the publication outcome and receipt. Phase 05 final gate remains pending.

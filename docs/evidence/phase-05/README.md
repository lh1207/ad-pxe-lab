# Phase 05 portable evidence

Phase 05 final gate passes on 2026-10-28 at 20:40 EDT. The finalizer verifies source/effective
policy, fresh computer/user RSOP, CL02 domain/DNS/secure channel, DC01 services, host boundary,
and Standard pre-phase-06 checkpoints.

- configuration-verifier.txt: nested run 203958007; its partial result is superseded by final-gate-verification.txt.
- computer-rsop-verification.txt and user-rsop-verification.txt: fresh local XML assertion summaries.
- hr-user-verification.txt: operator-provided normal hr.jones console test, H: share access and applied GPO.
- cl02-logon-banner.png: observed approved banner; regular hyphen explicitly accepted.
- gpmc-workstations-link.png and gpmc-users-link.png: enabled, non-enforced links.
- hr-drive-map-item.png, hr-drive-map-properties.png, hr-drive-map-common.png and
  hr-drive-map-targeting.png: H: Update mapping and positive RG-HR-Staff user targeting.
- configuration-verifier-pass.png: earlier 20:38 configuration pass.
- phase-05-final-gate-and-checkpoints.png: final PASS and checkpoint records.

Standard pre-phase-06 checkpoints: DC01 69c63c35-f7aa-4dec-add4-37358ef7b111 at 20:40:21;
CL02 56d7c809-6470-4737-a610-8477a10e4eb1 at 20:40:29.
Script assertions verify Standard configuration and resulting snapshot type.
Only DC01/CL02 run using 7.5 GB; automatic checkpoints remain disabled.

Physical USB denial and timed 900-second inactivity behavior were not exercised under the
runbook safety qualifier. Source/effective settings pass.
Raw RSOP/GPMC exports, manifests, backups, recovery material and receipts remain local and ignored.
Publication follows prior reviewed text/screenshot categories: https://github.com/lh1207/ad-pxe-lab/pull/6.

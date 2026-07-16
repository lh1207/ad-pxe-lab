---
type: decision
title: "Phase 1 Handoff — AD Foundation"
created: 2026-07-15
updated: 2026-07-15
tags:
  - meta
  - handoff
  - execution
  - active-directory
decision_date: 2026-07-15
status: active
related:
  - "[[Modules Index]]"
  - "[[Overview]]"
  - "[[Flows Index]]"
---

# Phase 1 Handoff — AD Foundation

A per-phase **execution handoff** artifact now lives in the repo at
`docs/handoffs/phase-01-handoff.md`. It is the pickup point for an operator (or a future session)
to run the AD-foundation stage of the lab end to end. This establishes `docs/handoffs/` as a new
artifact family alongside `docs/`, `runbooks/`, and `scripts/`.

## The two phase-numberings converge

The project uses "phase" in two senses that must not be conflated:

- **Repo-development phase** — the git meta-label. Commit `2b6111a` "(Phase 0) Add AD PXE lab
  runbooks and provisioning scripts" treats *authoring all runbooks/scripts/docs* as Phase 0,
  which is complete and merged to `main` (PR #1).
- **Runbook execution phase** — the operational sequence `00`–`10` inside `runbooks/`
  (`00` Conventions, `01` Host prep, … `10` OSD/PXE handoff). See [[Modules Index]].

Both readings converge on the same starting point: **executing the lab begins at runbook `01`**.
So "Phase 1 handoff" = the handoff to begin execution, and repo-Phase-0 groundwork (conventions,
media, host readiness) is assumed complete.

## Scope decision: Stage 1 = runbooks 01–03

The handoff covers **runbooks 01–03**, the AD foundation, chosen over a host-prep-only or a
full-lab (01–10) handoff:

1. **`01` Host prep** — `LabSwitch`/`LabNAT`, the read-only `WS2025-parent.vhdx`, and six stopped
   Gen 2 VMs (via `scripts/00`–`03-*.ps1`). All VMs off at the boundary.
2. **`02` DC01 AD DS/DNS/DHCP** — patch (KB5060842+) → promote `hufflab.internal` forest (FL 10) →
   AD-integrated DNS (forwarders `1.1.1.1`/`9.9.9.9`, reverse zone) → authorized DHCP scope
   `10.0.100.100`–`.199` with options **003/006/015 only**.
3. **`03` AD structure** — `HUFFLAB` OU tree, nine accounts, role (Global) + access (Domain Local)
   groups, and an AGDLP chain to `\\DC01\HRShare`.

Downstream (WDS/PXE `04`, GPO `05`, golden image `06`, ConfigMgr `07`–`10`) is out of scope.

## Format decision: actionable execution brief

The doc is deliberately an *execution brief*, not a narrative state-transfer: a Phase-0
confirm-checklist, an environment quick-reference table sourced verbatim from
`scripts/lab.config.psd1`, per-phase *checkpoint → command spine → verify → 📸 evidence → exit
gate* blocks, safety rails, a checkpoint rollback map, a definition-of-done that unblocks Phase 04,
and a consolidated evidence checklist. Every concrete value (IPs, ISO filenames, KB, scope range,
DHCP option numbers, checkpoint names) is drawn from source with zero drift; every PowerShell line
is lifted verbatim from its runbook.

## Safety rails carried into the handoff

- **Single PXE responder** — never set DHCP options **60/66/67**; the same-subnet design relies on
  one live responder (WDS, later ConfigMgr), not DHCP options. The Phase 02 scope must stay clean.
  See [[Flows Index]] for the WDS→ConfigMgr handoff.
- **Patch gate** — KB5060842-or-later + reboot **before** promoting DC01 (WS2025 Public-profile bug).
- **Secrets hygiene** — delete `C:\Windows\Panther\unattend.xml` after first boot; secure-string
  prompts; never `LabP@ss2026!`.
- **AGDLP discipline** — users → role (Global) → access (Domain Local) → ACL; never grant users
  directly.

## Open follow-ups (not done)

- `docs/lab-notebook.md` is referenced by the README and runbooks but **does not yet exist** — the
  target for all 📸 evidence. Candidate to scaffold separately.
- The README repository index does not yet link `docs/handoffs/`.

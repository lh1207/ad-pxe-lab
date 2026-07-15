---
type: meta
title: "Modules Index"
created: 2026-07-14
updated: 2026-07-14
tags: [meta, modules]
---

# Modules Index

One entry per runbook phase. Source: `runbooks/*.md` (merged into `main` via PR #1). Entries
below are pre-seeded stubs from each runbook's header; full module notes (one page per phase,
using `_templates/module.md`) are pending ingestion.

| Phase | Runbook | Resume bullet | Est. time | VMs on |
|---|---|---|---|---|
| 00 | `runbooks/00-conventions.md` — Conventions | infra | 0.5–1 h | none |
| 01 | `runbooks/01-host-prep.md` — Host prep & lab foundation | infra | 2–4 h | none |
| 02 | `runbooks/02-dc01-adds-dns-dhcp.md` — DC01: AD DS, DNS, DHCP | #1 | 3–5 h | DC01 |
| 03 | `runbooks/03-ad-structure.md` — AD structure: OUs, users, groups, AGDLP | #1 | 2–4 h | DC01 |
| 04 | `runbooks/04-wds-pxe-deploy.md` — WDS standalone PXE → CL02 | #2 | 2–3 h | DC01+WDS01+CL02 |
| 05 | `runbooks/05-gpo-suite.md` — GPO suite | #1 | 2–3 h | DC01+CL02 |
| 06 | `runbooks/06-golden-image.md` — Golden image: REF01 → capture → CL01 | #2 | 3–5 h | DC01+WDS01+REF01+CL01 |
| 07 | `runbooks/07-cm01-prereqs.md` — CM01 prerequisites | #3 | 4–6 h | DC01+CM01 |
| 08 | `runbooks/08-sccm-site-install.md` — SCCM site install & client onboarding | #3 | 5–7 h | DC01+CM01+CL02 |
| 09 | `runbooks/09-sccm-operations.md` — SCCM ops: apps, patching, compliance | #3 | 5–7 h | DC01+CM01+one client |
| 10 | `runbooks/10-osd-pxe-handoff.md` — OSD & the WDS→ConfigMgr PXE handoff | #2+#3 | 4–6 h | DC01+CM01+CL01 (WDS01 off) |
| — | `runbooks/drills-ad-ops.md` — Recurring AD operations drills | #1 | — (monthly cadence) | DC01+one client |

## Status

Source files are on `main`. Full per-page ingestion into this wiki is still pending — say "ingest [file]" to do it.

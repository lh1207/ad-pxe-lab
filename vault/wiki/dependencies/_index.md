---
type: meta
title: "Dependencies Index"
created: 2026-07-14
updated: 2026-07-21T23:14:46-04:00
tags: [meta, dependencies]
---

# Dependencies Index

External dependencies the lab relies on. Pre-seeded from `docs/architecture.md` and
`docs/decisions.md` (merged into `main` via PR #1) — pending full ingestion via
`_templates/dependency.md`.

| Dependency | Used by | Notes |
|---|---|---|
| [[WOLF Hyper-V Host]] | Host | 64 GB nominal RAM, 16 logical processors, Hyper-V enabled; SSH control verified |
| Windows Server 2025 Evaluation ISO | DC01, WDS01, CM01 parent VHDX | Server Desktop Experience image |
| Windows 11 Enterprise Evaluation ISO | REF01, read-only Windows Setup share | Reference/golden image and Phase 04 setup source |
| Windows ADK 11 + WinPE add-on | WDS01 standalone PXE, CM01 | Custom ADK WinPE payload; see ADR-004 |
| SQL Server 2022 Evaluation | CM01 | ADR-005 — full SQL Server, not SQL Express |
| ConfigMgr (SCCM) current branch | CM01 | Primary site, MP, DP, SSRS, PXE responder |
| WSUS / SUP role | CM01 | Patch compliance workflow (phase 09) |

## Status

Source files are on `main`. Full per-page ingestion into this wiki is still pending — say "ingest [file]" to do it.

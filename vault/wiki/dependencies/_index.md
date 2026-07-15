---
type: meta
title: "Dependencies Index"
created: 2026-07-14
updated: 2026-07-14
tags: [meta, dependencies]
---

# Dependencies Index

External dependencies the lab relies on. Pre-seeded from `docs/architecture.md` and
`docs/decisions.md` on branch `claude/ad-pxe-lab-setup-ynkkcm` — pending full ingestion via
`_templates/dependency.md`.

| Dependency | Used by | Notes |
|---|---|---|
| Hyper-V (Windows host role) | Host | `#Requires -Modules Hyper-V` on all scripts |
| Windows Server 2025 Evaluation ISO | DC01, WDS01, CM01 parent VHDX | Server Desktop Experience image |
| Windows 11 Enterprise Evaluation ISO | REF01, WDS install image | Reference/golden image source |
| Server 2022 boot.wim | WDS01 standalone PXE | ADR-004 — do not substitute Win11/WS2025 boot.wim |
| SQL Server 2022 Evaluation | CM01 | ADR-005 — full SQL Server, not SQL Express |
| ConfigMgr (SCCM) current branch | CM01 | Primary site, MP, DP, SSRS, PXE responder |
| WSUS / SUP role | CM01 | Patch compliance workflow (phase 09) |

## Status

Pending ingestion — see [[Index]] and vault `CLAUDE.md` for the `main` vs.
`claude/ad-pxe-lab-setup-ynkkcm` caveat.

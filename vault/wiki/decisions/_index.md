---
type: meta
title: "Decisions Index"
created: 2026-07-14
updated: 2026-07-14
tags: [meta, decisions]
---

# Decisions Index

Architecture Decision Records. Source: `docs/decisions.md` on branch
`claude/ad-pxe-lab-setup-ynkkcm` (commit `04e24ec`) — **not present on `main` yet**. Full ADR
notes (using `_templates/decision.md`) are pending ingestion; titles/status below are accurate
summaries of that document.

| ADR | Title | Status |
|---|---|---|
| ADR-001 | Internal switch plus host NAT | Accepted |
| ADR-002 | WDS on its own VM | Accepted |
| ADR-003 | `.internal` domain suffix (`hufflab.internal` / `HUFFLAB`) | Accepted |
| ADR-004 | Server 2022 boot image for standalone WDS | Accepted |
| ADR-005 | Full SQL Server 2022 on CM01 (no SQL Express) | Accepted |
| ADR-006 | Phased PXE: WDS first, ConfigMgr second | Accepted |
| ADR-007 | Same-subnet PXE without DHCP options or IP helpers | Accepted |
| ADR-008 | No MDT (Microsoft Deployment Toolkit) | Accepted |
| ADR-009 | Hybrid script/manual boundary — scripts stop at base OS installed | Accepted |

## Status

Pending ingestion — see [[Index]] and vault `CLAUDE.md` for the `main` vs.
`claude/ad-pxe-lab-setup-ynkkcm` caveat.

---
type: meta
title: "Flows Index"
created: 2026-07-14
updated: 2026-07-14
tags: [meta, flows]
---

# Flows Index

Cross-cutting operational flows. Pre-seeded from `docs/architecture.md` (merged into `main`
via PR #1) — pending full ingestion via `_templates/flow.md`.

| Flow | Summary |
|---|---|
| PXE boot / WDS phase | Client broadcasts DHCPDISCOVER → DC01 leases IP (gateway `10.0.100.1`, DNS `10.0.100.10`) → WDS01 answers PXE and offers custom ADK WinPE → WinPE launches Setup or DISM from controlled SMB shares |
| WDS → ConfigMgr PXE handoff (phase 10) | WDS01's WDSServer is stopped, disabled, and powered off → DHCP still leases but no PXE reply (negative test) → CM01's ConfigMgr PXE responder (no WDS) is enabled → client boots to ConfigMgr WinPE and runs the Win11 Golden task sequence |
| Golden image build | REF01 (Win11 Enterprise Eval) is generalized, captured with DISM from custom PXE WinPE to an SMB share, then retired; custom WinPE applies the captured WIM to CL01 |

## Status

Source files are on `main`. Full per-page ingestion into this wiki is still pending — say "ingest [file]" to do it.

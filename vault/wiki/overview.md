---
type: meta
title: "Overview"
created: 2026-07-14
updated: 2026-07-14
tags: [meta]
---

# Overview

ad-pxe-lab is a home lab that builds an Active Directory domain controller plus a PXE-based
OS deployment pipeline, running entirely on one Hyper-V host. It teaches three workflows without
letting them collide: AD DS administration, standalone WDS imaging, and Configuration Manager
(SCCM) operations, including a deliberate WDS → ConfigMgr PXE responder handoff.

## Topology (as designed on `claude/ad-pxe-lab-setup-ynkkcm`)

- **Host** — Hyper-V host, `LabSwitch` (Internal vSwitch, `10.0.100.0/24`) + `LabNAT` for outbound-only internet access. The lab is isolated from the physical LAN.
- **DC01** (`10.0.100.10`) — AD DS, DNS, DHCP. Forest root `hufflab.internal` / `HUFFLAB`.
- **WDS01** (`10.0.100.20`) — standalone WDS PXE responder, used in phases 04–06 and 09, retired in phase 10.
- **CM01** (`10.0.100.30`) — SQL Server 2022, ConfigMgr primary site, WSUS/SUP, MP, DP, SSRS, ConfigMgr PXE (active only after WDS01 is off).
- **CL01 / CL02 / REF01** — blank OSD target, WDS-deployed client, and a Windows 11 golden-image reference VM (deleted after capture).

See [[Flows Index]] for the PXE boot sequence and the WDS→ConfigMgr handoff, and
[[Decisions Index]] for why the lab is built this way (ADR-001 through ADR-009).

## Status

Scaffolded 2026-07-14. Real content ingestion is pending — see the caveat in the vault
`CLAUDE.md` about `main` vs. `claude/ad-pxe-lab-setup-ynkkcm`.

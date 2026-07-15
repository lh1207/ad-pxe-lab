---
type: meta
title: "Components Index"
created: 2026-07-14
updated: 2026-07-14
tags: [meta, components]
---

# Components Index

Reusable scripts and artifacts. Source: `scripts/*` (merged into `main` via PR #1). Full
component notes (using `_templates/component.md`) are pending ingestion.

| Script | Purpose |
|---|---|
| `scripts/00-Test-HostReadiness.ps1` | Validates Hyper-V, RAM, free storage, firmware virtualization, and configured media before the lab foundation is built |
| `scripts/01-New-LabSwitch.ps1` | Creates/removes the isolated Hyper-V Internal switch (`LabSwitch`), host address, and NAT (`LabNAT`), idempotently |
| `scripts/02-New-LabParentDisk.ps1` | Builds the read-only Windows Server parent VHDX from the configured evaluation ISO |
| `scripts/03-New-LabVM.ps1` | Creates the six Generation 2 lab VMs and their disks from `lab.config.psd1`, idempotently |
| `scripts/99-Remove-Lab.ps1` | Stops and removes only the VMs declared in the config, then deletes their VHDX files |
| `scripts/lab.config.psd1` | Single source of truth for domain name, network/IP plan, VM sizing, and static addresses — runbooks own product configuration on top of this |
| `scripts/unattend/unattend-server-base.xml` | Unattended-install answer file for base Windows Server image |

## Status

Source files are on `main`. Full per-page ingestion into this wiki is still pending — say "ingest [file]" to do it.

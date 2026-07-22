---
type: dependency
title: "WOLF Hyper-V Host"
version: "Windows PowerShell 5.1.26100.8875"
risk: medium
used_by:
  - Phase 01 host foundation
  - Hyper-V lab VMs
tags:
  - dependency
  - hyper-v
  - windows
  - ssh
created: 2026-07-21
updated: 2026-07-21T23:38:16-04:00
status: active
related:
  - "[[Overview]]"
  - "[[Phase 1 Handoff — AD Foundation]]"
  - "[[Dependencies Index]]"
---

# WOLF Hyper-V Host

## What it is

`WOLF` is the physical Windows host for ad-pxe-lab. Its physical-LAN management address is
`192.168.50.10`; the remote administrative identity is `WOLF\sparrow`. Public-key SSH from the Mac
Codex environment is verified. No passwords or private-key material belong in the repository or
vault.

Verified remote inventory on 2026-07-21:

| Property | Verified value |
|---|---|
| Computer name | `WOLF` |
| Windows PowerShell | `5.1.26100.8875` |
| Administrator token | Yes |
| Installed RAM | 63.7 GB usable (64 GB nominal) |
| Logical processors | 16 |
| Hyper-V feature | Enabled |
| Hyper-V module / host API | Working |
| Current VM count | 0 |
| Default VHD path | `C:\ProgramData\Microsoft\Windows\Virtual Hard Disks` |
| Default VM path | `C:\ProgramData\Microsoft\Windows\Hyper-V` |

## Why it's needed

The Mac workspace authors and reviews the lab, while WOLF supplies the Windows-only Hyper-V,
PowerShell 5.1, DISM, AD, DNS, and DHCP execution environment. SSH is the primary repeatable control
plane for commands and evidence collection. Parsec is an operator-controlled visual fallback for GUI
steps; it is not the automation transport for the current CLI session.

## Risk / constraints

- WOLF's physical address is for management. The lab's `10.0.100.0/24` network remains an isolated
  internal Hyper-V switch behind `LabNAT`.
- Remote commands execute with administrator rights. Keep SSH key authentication scoped to the lab,
  preserve approval prompts, and avoid placing secrets in command arguments or transcripts.
- The host has enough RAM for the declared lab, but the runbook's phase-specific VM power and PXE
  responder rules still apply; extra memory does not authorize concurrent conflicting services.
- Static verification proves the host control plane, not Phase 01 readiness. Media, storage, firmware
  virtualization, parser checks, and configured paths remain to be verified on WOLF.
- WOLF has a matching checkout at `C:\HyperV\ad-pxe-lab` on branch `milestone/phase2`. Handoff can
  transfer the Mac task and Git state, but any direct Windows execution must still preserve review
  of the Mac worktree's uncommitted changes.

## Codex desktop handoff

The supported way to continue the current Mac task on WOLF is an SSH host handoff from the Mac
desktop app. Installing the desktop app on WOLF alone does not prepare the SSH execution path.

Current prerequisite check through WOLF's SSH login shell:

| Prerequisite | State |
|---|---|
| Public-key SSH from Mac | Ready |
| Concrete Mac SSH alias `wolf` | Ready |
| `codex` available on the SSH login `PATH` | Ready |
| Codex authenticated with ChatGPT | Ready |
| Git available on the SSH login `PATH` | Ready |
| Matching `ad-pxe-lab` repository on WOLF | Ready — `C:\HyperV\ad-pxe-lab` |
| Repository branch | `milestone/phase2` |

The host-side prerequisites are complete. Add or enable `wolf` under the Mac app's
**Settings > Connections**, save `C:\HyperV\ad-pxe-lab` as the remote project, and use the current
task footer's run-location menu to select WOLF and **Hand off**. Codex transfers the task and its Git
state because the destination now has a saved project for the same repository.

## Related

- [[Phase 1 Handoff — AD Foundation]]
- [[Dependencies Index]]
- `runbooks/01-host-prep.md`
- `scripts/00-Test-HostReadiness.ps1`

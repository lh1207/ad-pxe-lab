---
type: meta
title: "Hot Cache"
updated: 2026-07-21T23:38:16-04:00
---

# Recent Context

## Last Updated
2026-07-21. Verified WOLF as the live Windows Hyper-V execution host and mapped the supported Codex
desktop handoff path.

## Key Recent Facts
- [[WOLF Hyper-V Host]] is the live execution dependency. Management endpoint:
  `WOLF\sparrow@192.168.50.10`; public-key SSH from the Mac Codex environment works.
- Verified: elevated Windows PowerShell `5.1.26100.8875`, 63.7 GB usable RAM (64 GB nominal), 16
  logical processors, Hyper-V enabled, working Hyper-V module/host API, and zero current VMs.
- SSH is the primary repeatable automation and evidence channel. Parsec remains a user-controlled
  visual fallback. The current CLI session cannot directly operate the Parsec desktop.
- The current task is ready to move from the Mac desktop app to WOLF with an SSH host handoff. Live
  checks confirm the `wolf` Mac SSH alias, Git and authenticated Codex on WOLF's SSH `PATH`, and a
  matching `C:\HyperV\ad-pxe-lab` checkout on `milestone/phase2`.
- `docs/handoffs/phase-01-handoff.md` is the audited operator overview for Stage 1 (runbooks 01–03),
  and `docs/lab-notebook.md` is the evidence destination.
- WOLF's physical-LAN address is management-only. The future `10.0.100.0/24` lab network remains an
  isolated Hyper-V internal switch behind `LabNAT`.

## Open Follow-ups
- In the Mac app, enable `wolf` under **Settings > Connections**, save the WOLF repository as the
  remote project, and use the task footer to hand off this task.
- After handoff, run the Phase 01 readiness script on WOLF.
- Verify media, SHA-256 records, free lab storage, firmware virtualization, and configured lab paths.
- Execute Stage 1 and replace notebook placeholders with real evidence and variances.

## Active Threads
- The host control plane is proven. Phase 01 infrastructure creation has not started; WOLF reports
  `VMCount=0`.

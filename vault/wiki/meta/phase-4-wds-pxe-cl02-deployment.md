---
type: meta
title: "Phase 4 — WDS PXE and CL02 Deployment"
created: 2026-08-11
updated: 2026-08-11
tags: [phase-04, wds, pxe, winpe, windows-11, hyper-v]
status: complete
related: ["[[Phase 1 Handoff — AD Foundation]]", "[[Flows Index]]", "[[Decisions Index]]"]
---

# Phase 4 — WDS PXE and CL02 Deployment

## Outcome

Phase 04 is complete on WOLF. WDS01 is the sole AD-integrated PXE responder on
`10.0.100.0/24`. It delivers the enabled x64 image `HUFFLAB Custom WinPE (Windows 11 Setup)`.
WinPE launches Windows 11 Enterprise Evaluation Setup from the read-only
`\\WDS01\Win11Source` share; WDS contains zero install images.

CL02 is installed, named `CL02`, joined to `hufflab.internal`, and located at
`CN=CL02,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal`. It uses `10.0.100.10` for DNS,
has a healthy secure channel, and accepts an interactive `HUFFLAB\lhuff` sign-in.

## Supported deployment decision

The original Server 2022 `boot.wim` plus WDS install-image plan was replaced after checking the
current Microsoft WDS support matrix. Standalone WDS remains the observable PXE/TFTP transport;
custom ADK 11 WinPE launches Setup or DISM from controlled SMB shares. Phase 06 follows the same
design by capturing and applying the golden WIM with DISM instead of WDS capture/install images.

## UEFI and TFTP repair

The working Generation 2 boot path uses:

- x64 UEFI BootProgram: `Boot\x64\wdsmgfw.efi`
- x64 UEFI N12BootProgram: `Boot\x64\bootmgfw.efi`
- WDS TFTP variable-window extension disabled
- `ramdisktftpvarwindow No` in both relevant x64 BCD stores

Using `wdsmgfw.efi` for both programs caused `0xc0000704` (`STATUS_RECURSIVE_DISPATCH`). The
repository script `scripts/04-Repair-WdsPxe.ps1` now reproduces the successful split, signed-role
file synchronization, BCD repair, and verification.

## Acceptance evidence

`docs/phase-04-configuration-verification.txt` ends with `PHASE 04 FINAL GATE: PASS`. It proves:

- WDS installed and running; exact custom boot image enabled; zero install images
- `Win11Source` exists with read-only domain access and contains `setup.exe`
- DHCP has options 003/006/015/051 and no 060/066/067
- exact CL02 AD location, Windows edition, DNS, domain membership, and secure channel
- vTPM enabled, Secure Boot `MicrosoftWindows`, and an 80 GB disk
- standard `pre-phase-05` checkpoints on DC01, WDS01, and CL02

Screenshots live in `docs/evidence/phase-04/` and the canonical notebook is
`docs/lab-notebook.md`.

## Variances and follow-up

The nine Phase 03 lab users were reset to one operator-chosen temporary password because their
original generated values were intentionally never stored and cannot be retrieved from AD. No
password was recorded. Rotate the shared temporary value before service-account use or non-lab
reuse.

The Codex workspace helper required explicit repository-scoped ACL entries for the managed
sandbox group and the operator account. A Defender heuristic detection from an abandoned
PowerShell-based patch attempt was remediated successfully; repository editing resumed only with
the integrated patch helper.

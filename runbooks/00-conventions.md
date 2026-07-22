# Phase 00 — Conventions

> **Resume bullet:** infra · **Est. time:** 0.5–1 h · **VMs on:** none (0 GB / 28 GB budget)

## Objectives

- Establish the naming, credential, evidence, checkpoint, and rollback conventions used by every
  subsequent phase.
- Keep the lab within the 28 GB VM budget, preserving at least 4 GB for the Hyper-V host.
- Set the hybrid boundary: scripts create only the host foundation and base operating systems; all
  AD DS, GPO, WDS, and Configuration Manager work is performed manually in these runbooks.

## Prerequisites

- Read [the implementation plan](../README.md) when it is available and retain this runbook as the
  operating convention for the lab.
- Use an elevated Windows PowerShell session only for host or server administration. Do not put lab
  passwords in scripts, transcripts, screenshots, source control, or command history.
- Create a secure password record. `LabP@ss2026!` is an example only; substitute a unique password
  you control everywhere it is requested.

## Steps

1. Adopt the canonical names. The forest root is `hufflab.internal`, the NetBIOS name is `HUFFLAB`,
   and the primary servers are `DC01`, `WDS01`, and `CM01`. Use the `HUFFLAB-` prefix for lab
   artifacts, including `HUFFLAB-Win11-Golden.wim`.

   Console path: record these values in the lab notebook before building anything. PowerShell has no
   separate equivalent; scripts read the same values from `scripts/lab.config.psd1`.

2. Use this exact structure for every numbered runbook: **Objectives**, **Prerequisites**, **Steps**,
   **Verify**, **Rollback**, and **Troubleshoot**. Steps are numbered, name the GUI console path before
   the PowerShell equivalent where one exists, and mark screenshot-worthy outcomes with
   **📸 Evidence:**.

3. Use named Hyper-V checkpoints immediately before each execution phase that changes an existing VM:
   `pre-phase-02`, `pre-phase-03`, and so on. Phase 01 has no VMs to checkpoint, so use a host restore
   point or lab-directory backup instead. In **Hyper-V Manager**, select each affected VM, then
   **Action > Checkpoint** and rename it. Do not checkpoint while an installation is actively writing
   a large image.

   ```powershell
   Checkpoint-VM -Name DC01 -SnapshotName pre-phase-02
   ```

4. Follow the RAM master table. Start only the VMs for the active phase and power off retired or
   unnecessary systems before starting another role.

   | VM | Assigned RAM | Typical phase use |
   |---|---:|---|
   | DC01 | 4 GB static | 02–10 |
   | WDS01 | 2 GB static | 04–06; off in 10 |
   | CM01 | 16 GB static | 07–10 |
   | CL01 | 4 GB dynamic | 06, 10 |
   | CL02 | 4 GB dynamic | 04–05, 08–09 |
   | REF01 | 4 GB dynamic | 06 only |

5. Capture evidence at every line marked **📸 Evidence:**. Use a screenshot that includes the
   relevant console pane and the VM name where practical, then record the filename, date, phase,
   command/result, and any variance in `docs/lab-notebook.md`.

6. Use `adm-lhuff` only for delegated administration after it exists; use `lhuff` as the normal daily
   account. `adm-lhuff` is an administrative account and should be considered for Protected Users
   membership after validating the lab's authentication requirements. Service accounts belong in
   `OU=ServiceAccounts,OU=HUFFLAB,DC=hufflab,DC=internal`; they are not interactive admin accounts.

7. Preserve the PXE safety rule: only one PXE responder may be live on this subnet. WDS01 serves PXE
   in phases 04–06 and 09. In phase 10, disable WDS01 and power it off before enabling the CM01 PXE
   responder. The DHCP scope never uses options 60, 66, or 67, and this same-subnet lab uses no IP
   helpers.

## Verify

Confirm that the VM budget remains within the lab limit before a multi-VM phase.

```powershell
Get-VM | Select-Object Name, State, MemoryAssigned
```

Expected output: only the phase-required VMs are running, and their assigned memory is at or below
28 GB in aggregate.

Confirm a phase checkpoint exists before changing a VM.

```powershell
Get-VMSnapshot -VMName DC01 | Select-Object VMName, Name
```

Expected output:

```text
VMName Name
------ ----
DC01   pre-phase-02
```

## Rollback

Create `pre-phase-NN` before each phase, then revert only the VMs changed in that phase through
**Hyper-V Manager > VM > Checkpoints > Apply**, or with `Restore-VMSnapshot`. Reversion discards
changes made after the checkpoint; export evidence and note the reason first. Never use a checkpoint
as a substitute for a system-state backup once AD DS exists.

## Troubleshoot

1. **The host becomes sluggish or memory pressure is high.** Check active VM memory and power off
   VMs not named in the current phase. Do not exceed 28 GB of concurrently running VM allocation.

   ```powershell
   Get-VM | Where-Object State -eq Running | Select-Object Name, MemoryAssigned
   ```

2. **A checkpoint cannot be created.** Confirm the VM is not merging disks and that the lab volume
   has free space. Wait for merge activity to finish rather than forcing a shutdown.

   ```powershell
   Get-VMHardDiskDrive -VMName DC01 | Select-Object Path
   ```

3. **A password appeared in a console or screenshot.** Change it immediately, redact or delete the
   evidence, and use `Read-Host -AsSecureString` in interactive PowerShell rather than a literal.

4. **Two PXE services appear to answer a client.** Stop the unneeded responder and return to the
   phase boundary; do not attempt to tune DHCP options 60, 66, or 67 to mask the conflict.

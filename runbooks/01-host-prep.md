# Phase 01 — Host prep & lab foundation

> **Resume bullet:** infra · **Est. time:** 2–4 h · **VMs on:** none (0 GB / 28 GB budget)

## Objectives

- Validate the Hyper-V host, media, RAM, and storage for the isolated lab.
- Create the `LabSwitch` internal vSwitch and `LabNAT` host NAT for `10.0.100.0/24`.
- Build the never-booted `WS2025-parent.vhdx` and create the six Generation 2 lab VMs.

## Prerequisites

- Complete Phase 00 conventions. No lab VM needs to be powered on.
- Obtain the WS2025 evaluation ISO, Windows 11 Enterprise evaluation ISO, Server 2022 evaluation ISO,
  SQL Server 2022 evaluation media, ConfigMgr Current Branch 2509 evaluation media, ADK 11 24H2 plus
  WinPE add-on, SSMS, ODBC Driver 18, and KB5060842 or a later WS2025 cumulative update. See
  `docs/iso-checklist.md` when available.
- Use a host with Hyper-V enabled, at least 32 GB installed RAM, at least 500 GB free lab storage,
  hardware virtualization enabled, and an elevated Windows PowerShell 5.1 session.

## Steps

1. Place the downloaded media in the ISO directory defined in `scripts/lab.config.psd1`, verify their
   SHA-256 hashes against Microsoft-provided values where available, and run the readiness test.

   Console path: **Settings > System > About** confirms installed memory; **Windows Features** confirms
   Hyper-V. PowerShell equivalent:

   ```powershell
   Set-Location .\scripts
   .\00-Test-HostReadiness.ps1
   ```

   📸 Evidence: successful readiness output showing Hyper-V, virtualization, storage, media, and script
   parser checks.

2. Create the isolated internal switch and host NAT. This is a host NAT design; DC01 is not a gateway.
   The script assigns host vNIC `10.0.100.1/24` and creates `LabNAT` for `10.0.100.0/24`.

   Console path: **Hyper-V Manager > Virtual Switch Manager > New virtual network switch > Internal**;
   name it `LabSwitch`. Then use an elevated PowerShell prompt for the NAT.

   ```powershell
   .\01-New-LabSwitch.ps1
   ```

   📸 Evidence: Virtual Switch Manager showing `LabSwitch`, plus `Get-NetNat` output showing `LabNAT`.

3. Create the WS2025 parent disk once. The script applies the Server 2025 Standard Desktop Experience
   image into `WS2025-parent.vhdx`, creates its GPT/EFI/MSR/OS layout, adds boot files, marks the VHDX
   read-only, and never boots it. Child servers specialize independently through their injected
   unattend files.

   Console path: mount the ISO in **File Explorer > Mount** only if you need to inspect editions.
   PowerShell equivalent:

   ```powershell
   .\02-New-LabParentDisk.ps1
   ```

4. Create all VMs from the declared configuration. Do not start them yet. DC01 and WDS01 use 60 GB
   differencing disks from the parent; CM01 owns a 150 GB fixed VHDX; CL01 and CL02 have blank 60 GB
   dynamic disks; REF01 has a blank 60 GB dynamic disk with the Windows 11 ISO attached. All are Gen 2
   with UEFI Secure Boot using the `MicrosoftWindows` template.

   Console path: **Hyper-V Manager > New > Virtual Machine** exposes the equivalent settings; use the
   repeatable PowerShell implementation instead.

   ```powershell
   $adminPassword = Read-Host 'Local Administrator password' -AsSecureString
   .\03-New-LabVM.ps1 -AdminPassword $adminPassword
   ```

5. Inspect each VM's **Settings** in Hyper-V Manager. Confirm its processor, memory, disk, switch,
   media, and boot order match the following intent: DC01/WDS01/CM01 boot VHD; CL01/CL02 network boot
   first; REF01 boots DVD. Keep every VM powered off at the phase boundary.

## Verify

```powershell
Get-VMSwitch -Name LabSwitch
Get-NetNat -Name LabNAT
Get-VM | Select-Object Name, Generation, State
```

Expected output includes `LabSwitch`, `LabNAT` with internal prefix `10.0.100.0/24`, and six stopped
Generation 2 VMs: `DC01`, `WDS01`, `CM01`, `CL01`, `CL02`, and `REF01`.

```powershell
Get-VMFirmware -VMName CL01 | Select-Object -ExpandProperty BootOrder
```

Expected output: a network adapter precedes disk boot for CL01. CL02 is configured the same way.

```powershell
(Get-Item (Import-PowerShellDataFile .\scripts\lab.config.psd1).Paths.ParentVhdx).IsReadOnly
```

Expected output:

```text
True
```

## Rollback

Before this phase, create a host restore point or ensure the lab directory is backed up; there are no
VM checkpoints yet. Remove only the artifacts created here with `scripts\99-Remove-Lab.ps1 -WhatIf`
first, then rerun without `-WhatIf` after review. Do not delete the parent disk manually if child disks
exist. Record the ISO hashes and keep source media outside the teardown target.

## Troubleshoot

1. **Readiness reports that virtualization or Hyper-V is unavailable.** Enable VT-x/AMD-V in firmware,
   enable the Hyper-V Windows feature, and reboot the host.

   ```powershell
   Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
   ```

2. **The NAT overlaps another local network.** Inspect existing NAT objects. Keep this lab's unique
   `10.0.100.0/24` prefix; do not attach `LabSwitch` to the physical LAN.

   ```powershell
   Get-NetNat | Select-Object Name, InternalIPInterfaceAddressPrefix
   ```

3. **Parent disk creation cannot find the desired edition.** Mount the WS2025 ISO and list its WIM
   indexes, then correct the configured ISO path rather than booting the parent VHDX.

   ```powershell
   Get-WindowsImage -ImagePath 'D:\sources\install.wim'
   ```

4. **A differencing child fails because its parent moved.** Restore the parent to its configured path
   or recreate the child; do not use a differencing disk after its parent has been modified.

   ```powershell
   Get-VHD -Path 'C:\Lab\VHD\DC01.vhdx' | Select-Object Path, ParentPath
   ```

5. **The host has insufficient free RAM or disk.** Stop before creating VMs, free storage, and retain
   at least 4 GB for the host. Do not reduce CM01 below its planned 16 GB merely to proceed.

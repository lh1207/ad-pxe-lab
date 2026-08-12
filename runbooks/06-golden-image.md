# Phase 06 — Golden image: REF01 → capture → CL01

> **Resume bullet:** #2 · **Est. time:** 3–5 h · **VMs on:** DC01+WDS01+REF01+CL01 (14 GB / 28 GB budget)

## Objectives

- Build a generalized Windows 11 Enterprise reference image on REF01.
- PXE-boot the Phase 04 custom WinPE image and capture REF01 with DISM to an SMB share.
- Apply `HUFFLAB-Win11-Golden.wim` to CL01 with DISM, then remove the disposable reference VM.

## Prerequisites

- Complete Phase 04. DC01 (4 GB), WDS01 (2 GB), REF01 (4 GB), and blank CL01 (4 GB) use 14 GB
  of the 28 GB VM budget. WDS01 remains the one live PXE responder; CM01 is off.
- REF01 is Generation 2, has the Windows 11 Enterprise evaluation ISO attached, and is attached
  to `LabSwitch`. CL01 is blank, Generation 2, network-first, Secure Boot enabled with the
  `MicrosoftWindows` template, and has vTPM. WDS01 has the enabled
  `HUFFLAB Custom WinPE (Windows 11 Setup)` image from Phase 04.
- Create `pre-phase-06` checkpoints for WDS01, REF01, and CL01. The image is a lab artifact;
  never include personal data, secrets, a domain join, or the sample `LabP@ss2026!` password.

> **Supported design:** WDS remains only the PXE/TFTP transport. The custom ADK WinPE image uses
> DISM to capture and apply the generalized WIM through a controlled SMB share. Do not create a
> WDS capture image or import the golden WIM as a WDS install image.

## Steps

1. In Hyper-V Manager, start REF01 from its attached Windows 11 Enterprise evaluation ISO and
   install Windows 11 Enterprise Evaluation. Create a local reference administrator with a unique
   password. Keep REF01 in a workgroup—do not join it to `hufflab.internal`—and install Windows
   Updates before customization.

   PowerShell equivalent on the Hyper-V host for starting an existing VM:

   ```powershell
   Start-VM -Name 'REF01'
   ```

2. On REF01, apply only reusable baseline customizations: current Windows updates, regional
   settings, approved application prerequisites, and any lab desktop settings that should appear
   on every deployed client. Remove temporary installers and user files. Do not install SCCM
   client components, do not domain-join, and do not embed production credentials.

   PowerShell equivalent for update review (install updates through your approved update process):

   ```powershell
   Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10
   ```

3. On WDS01, create `D:\GoldenImages` and share it as `GoldenImages`. Grant Domain Admins
   Change for capture and Domain Users Read for deployment; match the NTFS permissions. Keep the
   Phase 04 custom WinPE image as the only enabled WDS boot image.

   ```powershell
   New-Item -ItemType Directory -Path 'D:\GoldenImages' -Force
   New-SmbShare -Name GoldenImages -Path 'D:\GoldenImages' `
     -ChangeAccess 'HUFFLAB\Domain Admins' -ReadAccess 'HUFFLAB\Domain Users'
   ```

4. On REF01, open an elevated Command Prompt and generalize it only after all customization is
   complete. The command shuts down REF01; do not reboot it into Windows afterward, because that
   invalidates the prepared capture state.

   PowerShell equivalent:

   ```powershell
   Start-Process "$env:WINDIR\System32\Sysprep\Sysprep.exe" -ArgumentList '/generalize /oobe /shutdown' -Wait
   ```

   ```text
   %WINDIR%\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown
   ```

5. In Hyper-V Manager, remove REF01's ISO attachment, place **Network Adapter** first in firmware
   order, and start REF01. PXE boot to `HUFFLAB Custom WinPE (Windows 11 Setup)`. Map the capture
   share with a secure prompt, use `diskpart`/`list volume` to confirm the offline Windows volume
   letter, and capture it with DISM. The example assumes the offline Windows volume is `C:`.

   ```cmd
   net use Z: \\10.0.100.20\GoldenImages /user:HUFFLAB\Administrator *
   diskpart
   list volume
   exit
   dism /Capture-Image /ImageFile:Z:\HUFFLAB-Win11-Golden.wim /CaptureDir:C:\ /Name:HUFFLAB-Win11-Golden /Description:"Generalized Windows 11 Enterprise Evaluation" /Compress:max /CheckIntegrity /Verify
   ```

   PowerShell equivalent on the host for the boot change and start:

   ```powershell
   Set-VMFirmware -VMName 'REF01' -FirstBootDevice (Get-VMNetworkAdapter -VMName 'REF01')
   Start-VM -Name 'REF01'
   ```

   📸 Evidence: Capture the enabled custom WDS boot image, the Sysprep shutdown state, and the
   successful DISM capture showing the exact golden-image name and SMB destination.

6. On WDS01, validate the captured image, record its SHA-256 hash, and copy it to the approved
   backup location. Do not import it into WDS.

   ```powershell
   Get-WindowsImage -ImagePath 'D:\GoldenImages\HUFFLAB-Win11-Golden.wim'
   Get-FileHash 'D:\GoldenImages\HUFFLAB-Win11-Golden.wim' -Algorithm SHA256
   ```

7. Start blank CL01 from the network and PXE boot the custom WinPE image. In WinPE, use DiskPart
   to create a GPT/UEFI layout, map `GoldenImages` read-only, apply image index 1, and create the
   UEFI boot files. Confirm the target disk number before `clean`; this erases the selected disk.

   ```text
   diskpart
   select disk 0
   clean
   convert gpt
   create partition efi size=260
   format quick fs=fat32 label=System
   assign letter=S
   create partition msr size=16
   create partition primary
   format quick fs=ntfs label=Windows
   assign letter=W
   exit
   ```

   ```cmd
   net use Z: \\10.0.100.20\GoldenImages /user:HUFFLAB\Administrator *
   dism /Apply-Image /ImageFile:Z:\HUFFLAB-Win11-Golden.wim /Index:1 /ApplyDir:W:\ /CheckIntegrity /Verify
   bcdboot W:\Windows /s S: /f UEFI
   wpeutil reboot
   ```

   Let the PXE prompt time out after reboot, complete OOBE, then join CL01 to
   `hufflab.internal` and move it to the Workstations OU.

   PowerShell equivalent after initial CL01 sign-in:

   ```powershell
   Add-Computer -DomainName 'hufflab.internal' -Credential 'HUFFLAB\Administrator' -Restart
   ```

8. On DC01, use **Active Directory Users and Computers** to move CL01 into **HUFFLAB** →
   **Workstations**. Confirm the deployment contains the intended customizations and no reference
   user profile or capture-only files. Then shut down and delete REF01 in Hyper-V Manager, keeping
   the captured WIM on WDS01 and its backup copy.

   PowerShell equivalent on DC01 and host respectively:

   ```powershell
   Get-ADComputer -Identity 'CL01' -Properties DistinguishedName | Select-Object Name, DistinguishedName
   Stop-VM -Name 'REF01' -Force
   Remove-VM -Name 'REF01' -Force
   ```

   📸 Evidence: Capture the validated WIM/hash, CL01 at the Windows desktop, and CL01 in the
   Workstations OU. Record that REF01 was retired after a successful capture and deployment.

## Verify

```powershell
Get-WdsBootImage | Select-Object ImageName
# Expected: HUFFLAB Custom WinPE (Windows 11 Setup) is enabled.
```

```powershell
Get-WindowsImage -ImagePath 'D:\GoldenImages\HUFFLAB-Win11-Golden.wim'
Get-FileHash 'D:\GoldenImages\HUFFLAB-Win11-Golden.wim' -Algorithm SHA256
# Expected: image name HUFFLAB-Win11-Golden and a recorded SHA-256 hash.
```

```powershell
Get-ADComputer -Identity CL01 -Properties DistinguishedName | Select-Object -ExpandProperty DistinguishedName
# Expected: CN=CL01,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal
```

```powershell
Test-ComputerSecureChannel
# Expected on CL01: True.
```

```powershell
Get-VM -Name 'REF01' -ErrorAction SilentlyContinue
# Expected after cleanup: no output.
```

## Rollback

Restore `pre-phase-06` checkpoints if Sysprep, capture, or deployment fails before a usable image
exists. If capture fails after Sysprep, restore REF01 rather than booting it normally. Remove a
bad WIM from `D:\GoldenImages` and delete the failed CL01 AD object before retrying. Retain the
Phase 04 Windows Setup source as the known-good clean-install fallback.

## Troubleshoot

- **Sysprep fails:** inspect `C:\Windows\System32\Sysprep\Panther\setuperr.log`; remove
  unsupported provisioned apps or pending updates, then restore the pre-Sysprep checkpoint.
- **REF01 does not PXE boot:** remove the ISO, put its network adapter first, verify `LabSwitch`,
  and check `Get-Service WDSServer` on WDS01. WDS01 must remain the sole PXE responder.
- **Custom WinPE does not appear:** confirm the exact Phase 04 boot image remains enabled and
  that WDS01 is the sole PXE responder.
- **Capture cannot find a volume:** REF01 must be shut down by `/generalize /oobe /shutdown` and
  never restarted into Windows before PXE capture.
- **DISM apply or boot fails:** confirm the WIM hash, GPT/UEFI partition layout, image index,
  target drive letters, and successful `bcdboot` output before rebooting.
- **CL01 deployment or domain join fails:** test `Resolve-DnsName dc01.hufflab.internal` and
  `Test-Path '\\DC01\HRShare'`; CL01 must use DC01 (`10.0.100.10`) for DNS.
- **Golden image is unexpectedly large or contains secrets:** remove local profiles and installers
  from the reference VM, restore `pre-phase-06`, and rebuild; do not attempt to sanitize a
  deployed image in place.

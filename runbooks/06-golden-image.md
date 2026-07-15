# Phase 06 — Golden image: REF01 → capture → CL01

> **Resume bullet:** #2 · **Est. time:** 3–5 h · **VMs on:** DC01+WDS01+REF01+CL01 (14 GB / 28 GB budget)

## Objectives

- Build a generalized Windows 11 Enterprise reference image on REF01.
- Create and use a WDS capture image sourced from the Server 2022 boot image.
- Capture `HUFFLAB-Win11-Golden.wim`, deploy it to CL01, and remove the disposable reference VM.

## Prerequisites

- Complete Phase 04. DC01 (4 GB), WDS01 (2 GB), REF01 (4 GB), and blank CL01 (4 GB) use 14 GB
  of the 28 GB VM budget. WDS01 remains the one live PXE responder; CM01 is off.
- REF01 is Generation 2, has the Windows 11 Enterprise evaluation ISO attached, and is attached
  to `LabSwitch`. CL01 is blank, Generation 2, and network-first. WDS01 has the Server 2022 boot
  image and the `Win11` install image group from Phase 04.
- Create `pre-phase-06` checkpoints for WDS01, REF01, and CL01. The image is a lab artifact;
  never include personal data, secrets, a domain join, or the sample `LabP@ss2026!` password.

> **Compatibility caveat:** WDS capture must originate from the **Server 2022 `boot.wim`**
> imported in Phase 04. Standalone WDS hard-blocks Windows 11 and Windows Server 2025 media
> `boot.wim` files. This temporary WDS workflow is intentionally replaced by ConfigMgr PXE only
> in Phase 10 after WDS01 has been disabled and powered off.

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

3. On WDS01, open **Windows Deployment Services** → **Servers** → WDS01 → **Boot Images**.
   Right-click `Server 2022 WinPE (WDS Boot and Capture Source)` → **Create Capture Image**.
   Name it `Win11 Golden Capture`, describe its purpose, and save it locally, for example
   `D:\WdsSource\Win11-Golden-Capture.wim`. When creation completes, right-click **Boot Images**
   → **Add Boot Image** and import that capture WIM.

   PowerShell equivalent:

   ```powershell
   New-Item -ItemType Directory -Path 'D:\WdsSource' -Force
   wdsutil /New-CaptureImage /Image:'Server 2022 WinPE (WDS Boot and Capture Source)' `
     /Architecture:x64 /DestinationImage:'D:\WdsSource\Win11-Golden-Capture.wim' `
     /Name:'Win11 Golden Capture' /Description:'Capture generalized Windows 11 reference images'
   Import-WdsBootImage -Path 'D:\WdsSource\Win11-Golden-Capture.wim' -NewImageName 'Win11 Golden Capture'
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
   order, and start REF01. PXE boot to `Win11 Golden Capture`. In the Capture Wizard, select the
   generalized Windows partition, set image name exactly `HUFFLAB-Win11-Golden`, describe it, and
   save a local copy such as `C:\Capture\HUFFLAB-Win11-Golden.wim`. Select **Upload image to a
   Windows Deployment Services server**, specify WDS01, create or select the `Golden` image group,
   and upload.

   PowerShell equivalent on the host for the boot change and start:

   ```powershell
   Set-VMFirmware -VMName 'REF01' -FirstBootDevice (Get-VMNetworkAdapter -VMName 'REF01')
   Start-VM -Name 'REF01'
   ```

   📸 Evidence: Capture the capture-image entry in WDS, the Sysprep command/shutdown state, and
   the WDS Capture Wizard showing the exact golden-image name.

6. If the capture wizard saved but did not upload, use the WDS console: right-click **Install
   Images** → **Add Install Image**, create group `Golden`, browse to the captured WIM, select
   `HUFFLAB-Win11-Golden`, and finish. Do not overwrite the original `Win11` group image.

   PowerShell equivalent:

   ```powershell
   Import-WdsInstallImage -ImageGroup 'Golden' -Path 'C:\Capture\HUFFLAB-Win11-Golden.wim'
   ```

7. Start blank CL01 from the network. In the interactive WDS wizard, choose the Server 2022
   WinPE boot image and then `HUFFLAB-Win11-Golden.wim` from group `Golden`. Complete Windows
   Setup, then join CL01 to `hufflab.internal` and move it to the Workstations OU.

   > **Interactive deployment note:** WDS unattend auto-deployment is disabled by 2026 hardening.
   > Selecting the image and completing setup manually is expected; it is not a failed unattended
   > configuration.

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

   📸 Evidence: Capture the `Golden` image group, CL01 at the Windows desktop, and CL01 in the
   Workstations OU. Record that REF01 was retired after a successful capture.

## Verify

```powershell
Get-WdsBootImage | Select-Object ImageName
# Expected: Server 2022 WinPE source and Win11 Golden Capture are listed.
```

```powershell
Get-WdsInstallImage -ImageGroup 'Golden' | Select-Object ImageName, ImageGroup
# Expected: HUFFLAB-Win11-Golden.wim in the Golden group.
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
bad image from the `Golden` group and delete the failed CL01 AD object before retrying. Keep the
original Windows 11 image in group `Win11` intact as a known-good fallback.

## Troubleshoot

- **Sysprep fails:** inspect `C:\Windows\System32\Sysprep\Panther\setuperr.log`; remove
  unsupported provisioned apps or pending updates, then restore the pre-Sysprep checkpoint.
- **REF01 does not PXE boot:** remove the ISO, put its network adapter first, verify `LabSwitch`,
  and check `Get-Service WDSServer` on WDS01. WDS01 must remain the sole PXE responder.
- **Capture image does not appear:** confirm it was created from Server 2022 `boot.wim`; standalone
  WDS blocks Windows 11/Server 2025 media boot images.
- **Capture cannot find a volume:** REF01 must be shut down by `/generalize /oobe /shutdown` and
  never restarted into Windows before PXE capture.
- **CL01 deployment or domain join fails:** test `Resolve-DnsName dc01.hufflab.internal` and
  `Test-Path '\\DC01\HRShare'`; CL01 must use DC01 (`10.0.100.10`) for DNS.
- **Golden image is unexpectedly large or contains secrets:** remove local profiles and installers
  from the reference VM, restore `pre-phase-06`, and rebuild; do not attempt to sanitize a
  deployed image in place.

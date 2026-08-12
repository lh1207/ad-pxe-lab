# Phase 04 — WDS standalone PXE → CL02

> **Resume bullet:** #2 · **Est. time:** 2–3 h · **VMs on:** DC01+WDS01+CL02 (10 GB / 28 GB budget)

## Objectives

- Configure WDS01 as the single, AD-integrated WDS PXE responder on `10.0.100.0/24`.
- PXE-boot a custom ADK WinPE image and launch Windows 11 Enterprise Setup from a read-only SMB share.
- Join CL02 to `hufflab.internal` in the Workstations OU and record the deployment evidence.

## Prerequisites

- Complete Phases 01–03. DC01 is healthy, DNS and AD-authorized DHCP are available, and the
  scope is `10.0.100.100–10.0.100.199`. DC01 (4 GB), WDS01 (2 GB), and blank CL02 (4 GB)
  total 10 GB, leaving 18 GB within the 28 GB VM budget.
- WDS01 has `10.0.100.20`, uses DNS `10.0.100.10`, is domain-joined, and has NTFS paths for
  `D:\RemoteInstall` and `D:\Win11Source`.
- CL02 is Generation 2 on `LabSwitch`, has two processors, an 80 GB disk, Secure Boot with the
  `MicrosoftWindows` template, an enabled virtual TPM, and Network Adapter first.
- Have Windows 11 Enterprise Evaluation media, Windows ADK 11 24H2, and the matching WinPE
  add-on. Before starting, create standard `pre-phase-04` checkpoints for DC01, WDS01, and CL02.
- Do not configure DHCP options 60, 66, or 67, and do not configure IP helpers: DHCP, WDS, and
  CL02 share the same subnet. WDS01 is the only live PXE responder in this phase.

> **Supported design:** Current Windows installation-media `boot.wim` files do not provide a
> supported end-to-end standalone-WDS deployment path for Windows 11. WDS is used only for
> PXE/TFTP: it delivers a custom ADK 11 WinPE image, and WinPE launches normal Windows Setup
> from a read-only SMB share. No Windows 11 install image is imported into WDS. See Microsoft's
> [WDS boot support matrix](https://learn.microsoft.com/en-us/windows/deployment/wds-boot-support)
> and [custom WinPE guidance](https://learn.microsoft.com/en-us/windows/deployment/customize-boot-image).

## Steps

1. On WDS01, open **Server Manager** → **Manage** → **Add Roles and Features** →
   **Role-based or feature-based installation** → select WDS01 → **Windows Deployment
   Services**. Select both **Deployment Server** and **Transport Server**, accept dependencies,
   and install. Reboot if requested.

   PowerShell equivalent:

   ```powershell
   Install-WindowsFeature -Name WDS -IncludeManagementTools
   ```

2. Open **Windows Deployment Services** from Server Manager → **Tools**. Expand **Servers**,
   right-click WDS01, and choose **Configure Server**. Choose **Integrated with Active Directory**,
   set RemoteInstall to `D:\RemoteInstall`, decline joining a multicast transmission, and finish.
   Start the server when prompted.

   PowerShell equivalent (run elevated on WDS01):

   ```powershell
   wdsutil /Initialize-Server /RemInst:"D:\RemoteInstall"
   Start-Service WDSServer
   ```

3. In the WDS console, right-click WDS01 → **Properties** → **PXE Response**. Select
   **Respond to all client computers (known and unknown)**. Leave the default approval behavior
   suitable for the lab, apply, and restart the WDS service.

   PowerShell equivalent:

   ```powershell
   wdsutil /Set-Server /AnswerClients:All
   Restart-Service WDSServer
   ```

   📸 Evidence: Capture the PXE Response tab showing WDS01 responds to all clients.

4. Install ADK Deployment Tools and the matching WinPE add-on on WDS01. Build an amd64 WinPE
   working directory. Add the WMI and SecureStartup optional components and matching language
   packages. Set `startnet.cmd` to run `wpeinit`, show the mapping command below, and open
   `cmd.exe`. Never embed credentials in the image.

   Import exactly one enabled x64 boot image with this stable name:

   ```powershell
   Import-WdsBootImage -Path 'C:\WinPE_amd64\media\sources\boot.wim' `
     -NewImageName 'HUFFLAB Custom WinPE (Windows 11 Setup)'
   ```

5. Copy the complete Windows 11 Enterprise Evaluation ISO contents to `D:\Win11Source`. Share
   it as `Win11Source` with read-only access for Domain Users and Domain Admins. Do not import
   an install image into WDS.

6. Confirm WDS is listening and that DHCP remains owned by DC01. On DC01, do not add PXE DHCP
   options; on WDS01, confirm only this server answers PXE requests. Start CL02 with **Network
   Adapter** first in Hyper-V firmware order, then press Enter at the PXE prompt when it boots.

   PowerShell checks:

   ```powershell
   Get-Service WDSServer
   Get-DhcpServerv4OptionValue -ComputerName DC01 -ScopeId 10.0.100.0
   ```

7. Boot `HUFFLAB Custom WinPE (Windows 11 Setup)`. Map the setup share using a secure password
   prompt and launch normal Windows Setup:

   ```cmd
   net use Z: \\10.0.100.20\Win11Source /user:HUFFLAB\Administrator *
   Z:\setup.exe
   ```

   Select Windows 11 Enterprise Evaluation and Drive 0 unallocated space. During later restarts,
   do not press Enter at the PXE prompt; allow it to time out and boot from disk. Complete OOBE
   with a temporary local administrator and do not record its password.

8. Complete Windows Setup on CL02. After first sign-in, set DNS to `10.0.100.10` if DHCP did not
   apply it, rename only if necessary, and join the domain through **Settings** → **System** →
   **About** → **Domain or workgroup** → **Change**. Use domain `hufflab.internal`, then in
   **Active Directory Users and Computers** on DC01, move CL02 to
   `OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal`.

   PowerShell equivalent from an elevated CL02 session:

   ```powershell
   Add-Computer -DomainName 'hufflab.internal' -Credential 'HUFFLAB\Administrator' -Restart
   ```

9. After CL02 restarts, sign in as `HUFFLAB\lhuff` to prove normal domain authentication. In
   **Active Directory Users and Computers**, refresh the Workstations OU and verify CL02 is in
   the intended location.

   PowerShell equivalent on DC01:

   ```powershell
   Get-ADComputer -Identity 'CL02' -Properties DistinguishedName | Select-Object Name, DistinguishedName
   ```

   📸 Evidence: Capture the custom WDS boot image, PXE WIM transfer, Windows Setup launched from
   the SMB source, CL02 in the Workstations OU, and a successful `HUFFLAB\lhuff` sign-in.

## Verify

Run these checks after deployment.

```powershell
Get-WindowsFeature WDS | Select-Object DisplayName, InstallState
# Expected: Windows Deployment Services is Installed.
```

```powershell
Get-WdsBootImage | Select-Object ImageName, Architecture, Enabled
# Expected: HUFFLAB Custom WinPE (Windows 11 Setup), x64, enabled.
```

```powershell
(Get-WdsInstallImage | Measure-Object).Count
Get-SmbShare Win11Source | Select-Object Name, Path
Test-Path 'D:\Win11Source\setup.exe'
# Expected: zero WDS install images; Win11Source exists; setup.exe is present.
```

```powershell
Get-ADComputer -Identity CL02 -Properties DistinguishedName | Select-Object -ExpandProperty DistinguishedName
# Expected: CN=CL02,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal
```

```powershell
Test-ComputerSecureChannel
# Expected on CL02: True.
```

```powershell
# Hyper-V host
Get-VMSecurity CL02 | Select-Object TpmEnabled
Get-VMFirmware CL02 | Select-Object SecureBoot, SecureBootTemplate
Get-VHD (Get-VMHardDiskDrive CL02 | Select-Object -First 1 -ExpandProperty Path) |
  Select-Object Path, @{N='SizeGB';E={[math]::Round($_.Size/1GB)}}
# Expected: TPM and Secure Boot enabled; MicrosoftWindows template; at least 80 GB.
```

The successful execution transcript is
[`docs/phase-04-configuration-verification.txt`](../docs/phase-04-configuration-verification.txt).

## Rollback

Restore DC01, WDS01, and CL02 together to `pre-phase-04` if server configuration needs a clean retry. If
only the client deployment failed, delete the failed CL02 computer account in AD Users and
Computers, recreate the empty CL02 VHDX if needed, and retry PXE. Do not roll back DC01 DHCP or
add DHCP PXE options as a workaround.

## Troubleshoot

- **CL02 gets no PXE offer:** confirm it is on `LabSwitch`, network-first, and that WDS01—not
  CM01—is the only PXE responder. Run `Get-Service WDSServer` on WDS01 and
  `Get-DhcpServerv4Lease -ScopeId 10.0.100.0` on DC01.
- **PXE gets an address but does not boot:** verify no options 60/66/67 are set with
  `Get-DhcpServerv4OptionValue -ScopeId 10.0.100.0`; check WDS01 firewall and
  `Get-WinEvent -LogName 'Microsoft-Windows-Deployment-Services-Diagnostics/Operational' -MaxEvents 30`.
- **UEFI says no boot image:** verify the default x64 image points to
  `Boot\x64\Images\boot.wim`. Use the WDS role's signed `wdsmgfw.efi` as the x64 UEFI prompt
  program and `bootmgfw.efi` as the non-prompt/N12 program.
- **WDS error `0xc0000704`:** this is recursive dispatch. Do not configure both UEFI program
  paths to `wdsmgfw.efi`; restore the prompt/N12 split above and restart WDS.
- **TFTP stalls or fails:** disable the WDS TFTP variable-window extension and ensure both x64
  BCD stores advertise `ramdisktftpvarwindow No`; retain backups before changing BCD files.
- **Setup share not found:** run `wpeinit`, verify the CL02 lease, and use
  `\\10.0.100.20\Win11Source`; enter credentials only at the secure prompt.
- **Setup reports no TPM:** power off CL02, set a local key protector, enable vTPM and Secure
  Boot with the `MicrosoftWindows` template, and verify with `Get-VMSecurity`.
- **Domain join fails:** on CL02 run `ipconfig /all` and `Resolve-DnsName dc01.hufflab.internal`.
  The DNS server must be `10.0.100.10`, not a public resolver.
- **CL02 does not land in Workstations:** WDS deployment does not select the OU. Move the object
  in ADUC or use `Move-ADObject` after confirming its distinguished name.

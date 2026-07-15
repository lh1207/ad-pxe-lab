# Phase 04 — WDS standalone PXE → CL02

> **Resume bullet:** #2 · **Est. time:** 2–3 h · **VMs on:** DC01+WDS01+CL02 (10 GB / 28 GB budget)

## Objectives

- Configure WDS01 as the single, AD-integrated WDS PXE responder on `10.0.100.0/24`.
- Import the supported boot image and Windows 11 Enterprise evaluation install image, then deploy CL02.
- Join CL02 to `hufflab.internal` in the Workstations OU and record the deployment evidence.

## Prerequisites

- Complete Phases 01–03. DC01 is healthy, DNS and AD-authorized DHCP are available, and the
  scope is `10.0.100.100–10.0.100.199`. DC01 (4 GB), WDS01 (2 GB), and blank CL02 (4 GB)
  total 10 GB, leaving 18 GB within the 28 GB VM budget.
- WDS01 has `10.0.100.20`, uses DNS `10.0.100.10`, is domain-joined, and has a data volume or
  free NTFS path for `D:\RemoteInstall`. CL02 is Generation 2 and network-first on `LabSwitch`.
- Have the Server 2022 evaluation ISO and Windows 11 Enterprise evaluation ISO mounted or
  copied locally. Before starting, create a named Hyper-V checkpoint such as `pre-phase-04` for
  WDS01 and CL02.
- Do not configure DHCP options 60, 66, or 67, and do not configure IP helpers: DHCP, WDS, and
  CL02 share the same subnet. WDS01 is the only live PXE responder in this phase.

> **Compatibility caveat:** standalone WDS is intentionally using **Server 2022 `boot.wim`**.
> Current standalone WDS accepts that WinPE image; `boot.wim` taken from Windows 11 or Windows
> Server 2025 media is hard-blocked. This is a learning-stage WDS pipeline, replaced by the
> ConfigMgr PXE responder only in Phase 10 after WDS01 is disabled and powered off.

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

4. Mount the Server 2022 ISO on WDS01. In the WDS console, expand WDS01 → **Boot Images**,
   right-click **Boot Images** → **Add Boot Image**, and browse to `sources\boot.wim` on the
   Server 2022 media. Name it `Server 2022 WinPE (WDS Boot and Capture Source)` and complete the
   wizard. Do not substitute Windows 11 or Server 2025 media here.

   PowerShell equivalent:

   ```powershell
   Import-WdsBootImage -Path 'E:\sources\boot.wim' -NewImageName 'Server 2022 WinPE (WDS Boot and Capture Source)'
   ```

5. Mount the Windows 11 Enterprise evaluation ISO. In the WDS console, right-click
   **Install Images** → **Add Install Image**. Create image group `Win11`; browse to
   `sources\install.wim`; select the **Windows 11 Enterprise Evaluation** edition; and complete
   the import.

   PowerShell equivalent:

   ```powershell
   Import-WdsInstallImage -ImageGroup 'Win11' -Path 'F:\sources\install.wim'
   ```

6. Confirm WDS is listening and that DHCP remains owned by DC01. On DC01, do not add PXE DHCP
   options; on WDS01, confirm only this server answers PXE requests. Start CL02 with **Network
   Adapter** first in Hyper-V firmware order, then press Enter at the PXE prompt when it boots.

   PowerShell checks:

   ```powershell
   Get-Service WDSServer
   Get-DhcpServerv4OptionValue -ComputerName DC01 -ScopeId 10.0.100.0
   ```

7. At the WDS client screen, choose `Server 2022 WinPE (WDS Boot and Capture Source)`, sign in
   with an authorized `HUFFLAB\Administrator` account, and choose the Windows 11 Enterprise
   evaluation install image in group `Win11`. Use a strong administrator password; if using the
   documentation example `LabP@ss2026!`, substitute your own value.

   > **Interactive deployment note:** 2026 WDS hardening disables WDS unattend auto-deployment.
   > The image-selection and setup wizard are deliberately interactive in this lab; that is
   > expected and preserves the learning evidence.

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

   📸 Evidence: Capture the WDS console with both image types, the PXE image-selection screen,
   and CL02 shown in the Workstations OU.

## Verify

Run these checks after deployment.

```powershell
Get-WindowsFeature WDS | Select-Object DisplayName, InstallState
# Expected: Windows Deployment Services is Installed.
```

```powershell
Get-WdsBootImage | Select-Object ImageName
# Expected: Server 2022 WinPE (WDS Boot and Capture Source).
```

```powershell
Get-WdsInstallImage -ImageGroup 'Win11' | Select-Object ImageName, ImageGroup
# Expected: Windows 11 Enterprise evaluation image in Win11.
```

```powershell
Get-ADComputer -Identity CL02 -Properties DistinguishedName | Select-Object -ExpandProperty DistinguishedName
# Expected: CN=CL02,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal
```

```powershell
Test-ComputerSecureChannel
# Expected on CL02: True.
```

## Rollback

Restore WDS01 and CL02 to `pre-phase-04` if image import or deployment needs a clean retry. If
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
- **Boot image is rejected or absent:** verify it was imported from Server 2022 `sources\boot.wim`;
  Windows 11 and Server 2025 media boot images are hard-blocked by standalone WDS.
- **Domain join fails:** on CL02 run `ipconfig /all` and `Resolve-DnsName dc01.hufflab.internal`.
  The DNS server must be `10.0.100.10`, not a public resolver.
- **CL02 does not land in Workstations:** WDS deployment does not select the OU. Move the object
  in ADUC or use `Move-ADObject` after confirming its distinguished name.

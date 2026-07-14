# Phase 10 — OSD & the WDS→ConfigMgr PXE handoff

> **Resume bullet:** #2+#3 · **Est. time:** 4–6 h · **VMs on:** DC01+CM01+CL01 (24 GB / 28 GB budget; WDS01 OFF)

## Objectives

- Retire WDS01 before enabling the ConfigMgr PXE responder.
- Prove the required no-responder PXE timeout, then enable PXE without WDS on CM01.
- Deploy `HUFFLAB-Win11-Golden.wim` through task sequence `Deploy Win11 Golden` to CL01.

## Prerequisites

- Phase 09 is complete and `HUFFLAB-Win11-Golden.wim` is available from the validated Phase 06
  capture. DC01 (4 GB), CM01 (16 GB), and blank CL01 (4 GB) consume 24 GB.
- Take checkpoints `Pre-Phase10-DC01`, `Pre-Phase10-CM01`, `Pre-Phase10-CL01`, and
  `Pre-Phase10-WDS01`. CL01 must be Generation 2, UEFI/Secure Boot with Microsoft Windows
  template, connected to `LabSwitch`, and network-first boot.
- There must be exactly one live PXE responder per subnet. DHCP remains on DC01 with no options
  60, 66, or 67 and no IP helpers because this is a same-subnet lab.

## Steps

1. On WDS01, stop and disable WDS before changing CM01. In **Server Manager** → **Tools** →
   **Services**, stop **Windows Deployment Services Server** and set **Startup type** to
   **Disabled**. Then use **Hyper-V Manager** → WDS01 → **Shut Down** and confirm it is **Off**.
   This phase starts with WDS disabled and powered off; do not merely stop it. 📸 Evidence: WDS01
   service disabled and Hyper-V state Off.

   PowerShell equivalent on WDS01, followed by host Hyper-V PowerShell:

   ```powershell
   Stop-Service WDSServer -Force
   Set-Service WDSServer -StartupType Disabled
   Stop-Computer -Force
   # On the Hyper-V host after it shuts down:
   Get-VM WDS01 | Select-Object Name,State
   ```

2. Before enabling PXE on CM01, start CL01 and boot it from network. Record that it obtains DHCP
   but receives no PXE offer and eventually times out/falls through. This is the mandatory negative
   test proving WDS01 is not still responding; leave the screenshot/log evidence in the lab
   notebook. Do not proceed if any PXE responder answers. 📸 Evidence: CL01 PXE timeout with WDS01
   Off and CM01 PXE not enabled.

   PowerShell equivalent on DC01 to corroborate the lease (the timeout itself is observed in CL01
   firmware):

   ```powershell
   Get-DhcpServerv4Lease -ScopeId 10.0.100.0 | Where-Object HostName -Match 'CL01' | Select-Object IPAddress,HostName,AddressState
   ```

3. On CM01, install the Distribution Point PXE responder in **Administration** → **Site
   Configuration** → **Servers and Site System Roles** → CM01 → **Distribution point** →
   **Properties** → **PXE**. Enable **Enable PXE support for clients** and select **Enable a PXE
   responder without Windows Deployment Service**. Enable unknown-computer support only after
   confirming the target deployment is restricted appropriately. Do not install or enable WDS on
   CM01. 📸 Evidence: PXE tab showing responder without WDS.

   PowerShell equivalent from the `HUF:` drive:

   ```powershell
   Set-Location HUF:
   Set-CMDistributionPoint -SiteSystemServerName 'CM01.hufflab.internal' -EnablePxe $true -EnablePxeRespondWithoutWds $true -EnableUnknownComputerSupport $true
   ```

4. In **Software Library** → **Operating Systems** → **Operating System Images**, add
   `HUFFLAB-Win11-Golden.wim`, select the appropriate image index, then distribute it to CM01 DP.
   In **Boot Images**, use an ADK 11 24H2 boot image; add the required optional components only,
   update the distribution point, and confirm it is PXE-enabled. Hyper-V synthetic NIC/storage
   drivers are inbox, so create no driver packages for this virtual deployment.

   PowerShell equivalent:

   ```powershell
   Set-Location HUF:
   New-CMOperatingSystemImage -Name 'HUFFLAB-Win11-Golden.wim' -Path '\\CM01\Sources\OSD\HUFFLAB-Win11-Golden.wim' -Version '1.0'
   ```

5. In **Software Library** → **Operating Systems** → **Task Sequences**, create `Deploy Win11
   Golden`. Add steps to partition and format disk for UEFI, apply `HUFFLAB-Win11-Golden.wim`,
   apply Windows settings, join `hufflab.internal` to the Workstations OU, install the 7-Zip
   application, and finish setup. Use a least-privileged domain-join account; never place the
   sample password `LabP@ss2026!` in the task sequence. Distribute referenced content to CM01 DP.

   PowerShell equivalent: use the task-sequence wizard for the initial authoring because it creates
   the step graph and package references; inspect available cmdlets with:

   ```powershell
   Set-Location HUF:
   Get-Command -Module ConfigurationManager *TaskSequence* | Select-Object Name
   ```

6. Deploy `Deploy Win11 Golden` to **All Unknown Computers** and `OSD-Targets` as **Available**
   PXE media for the lab. Use a staged/limited collection for any known computer. Start CL01 by
   network boot, select the task sequence, and watch `smsts.log` during WinPE and after the local
   disk transition. 📸 Evidence: PXE responder selection, completed task sequence, and domain
   membership in the Workstations OU.

   PowerShell equivalent for live log observation on CL01:

   ```powershell
   Get-Content 'X:\Windows\Temp\SMSTSLog\smsts.log' -Wait
   # After Setup Windows and ConfigMgr: C:\Windows\CCM\Logs\smsts.log
   ```

7. Keep WDS01 off for the remainder of ConfigMgr OSD work. For real hardware, import only
   vendor-supported, model-specific driver packages and apply them with driver-management steps;
   do not treat the no-driver Hyper-V result as proof a physical device needs no drivers.

## Verify

```powershell
# Hyper-V host and CM01 Configuration Manager console session
Get-VM WDS01 | Select-Object Name,State
Set-Location HUF:
Get-CMDistributionPoint | Select-Object NetworkOSPath,IsPxe
Get-CMTaskSequence -Name 'Deploy Win11 Golden' | Select-Object Name,PackageID
```

```text
Name  State
----  -----
WDS01 Off

IsPxe
-----
True

Name               PackageID
----               ---------
Deploy Win11 Golden HUF000xx
```

```powershell
# CL01 after OSD
(Get-CimInstance Win32_ComputerSystem).Domain
Get-ADComputer CL01 -Properties DistinguishedName | Select-Object Name,DistinguishedName
Get-Content 'C:\Windows\CCM\Logs\smsts.log' -Tail 10
```

```text
hufflab.internal
CL01  CN=CL01,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal
Task Sequence Manager successfully completed execution
```

## Rollback

If PXE configuration is wrong, disable PXE on the CM01 distribution point, leave WDS01 powered
off, and revert CM01/CL01 to their `Pre-Phase10-*` checkpoints. Restore WDS01 only by reverting
to `Pre-Phase10-WDS01`, re-enabling `WDSServer`, and powering it on after CM01 PXE is disabled;
never run both responders on `10.0.100.0/24`.

## Troubleshoot

- CL01 receives a PXE offer during the negative test: stop immediately; check `Get-VM WDS01` is
  Off, `Get-Service WDSServer` is Disabled when WDS01 is temporarily started for inspection, and
  ensure CM01 PXE is not already enabled.
- PXE times out after CM01 enablement: confirm CL01 has a DHCP lease, the `BG-Lab` IP range is
  `10.0.100.1-10.0.100.254`, CM01 DP is PXE-enabled without WDS, and inspect `SMSPXE.log`.
- No task sequence is offered: validate the deployment targets All Unknown Computers or the CL01
  record in `OSD-Targets`, is available to PXE media, and content is distributed to CM01 DP.
- Apply image fails: verify the WIM index, DP content status, disk UEFI partition step, and
  `smsts.log` path for the current execution phase.
- Domain join fails: test DNS against `10.0.100.10`, validate the Workstations OU DN and join
  account permissions, then read `smsts.log` around the Apply Network Settings step.

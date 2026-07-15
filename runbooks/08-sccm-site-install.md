# Phase 08 — SCCM site install & client onboarding

> **Resume bullet:** #3 · **Est. time:** 5–7 h · **VMs on:** DC01+CM01+CL02 (24 GB / 28 GB budget)

## Objectives

- Install the `HUF` primary site named `Hufflab Primary Site` on CM01.
- Configure MP, DP, Reporting Services Point, SUP, discovery, and the `BG-Lab` IP-range boundary.
- Push the ConfigMgr client to CL02 and create the required collections.

## Prerequisites

- Phase 07 checks pass. DC01 (4 GB), CM01 (16 GB), and domain-joined CL02 (4 GB) use 24 GB.
- Take checkpoints named `Pre-Phase08-DC01`, `Pre-Phase08-CM01`, and `Pre-Phase08-CL02`.
- CL02 resolves `CM01.hufflab.internal`, has a valid DHCP lease, and allows administrative client
  push. Use `svc-sccm-push` for client push; do not use `svc-sccm-na` as a client-push account.

## Steps

1. On CM01, run `splash.hta` from the ConfigMgr Current Branch 2509 evaluation media → **Install**
   → **Install a Configuration Manager primary site**. Select **Use typical installation options**
   only if every default is reviewed; otherwise choose custom settings. Set site code `HUF`, site
   name `Hufflab Primary Site`, install directory on a volume with ample free space, and SQL Server
   `CM01` default instance. Choose the local server for the management point and distribution point.
   📸 Evidence: completed setup summary with site code and name.

   PowerShell equivalent: ConfigMgr primary-site setup is performed by the supported setup wizard;
   no general PowerShell cmdlet replaces the initial interactive site installation. Launch it with:

   ```powershell
   Start-Process 'C:\Installers\ConfigMgr\splash.hta'
   ```

2. Open the **Configuration Manager console** → **Administration** → **Site Configuration** →
   **Sites** → `HUF - Hufflab Primary Site` → **Properties**. Confirm the site server and database.
   Install the console when prompted, then use **Administration** → **Site Configuration** →
   **Servers and Site System Roles** → CM01 to confirm **Management point** and **Distribution
   point**. Enable Enhanced HTTP for the site; the network access account is a legacy fallback,
   not the preferred modern path.

   PowerShell equivalent from the Configuration Manager console session:

   ```powershell
   Import-Module "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"
   Set-Location HUF:
   Get-CMSite
   Get-CMManagementPoint
   Get-CMDistributionPoint
   ```

3. Add reporting: **Administration** → **Site Configuration** → **Servers and Site System Roles**
   → CM01 → **Add Site System Roles** → **Reporting Services Point**. Select the local SSRS server
   and create/use the ConfigMgr report folder. Verify **Monitoring** → **Reporting** → **Reports**
   loads. 📸 Evidence: reporting role and a rendered report.

   PowerShell equivalent:

   ```powershell
   Add-CMReportingServicePoint -SiteSystemServerName 'CM01.hufflab.internal' -ReportingServiceInstanceName 'SSRS'
   ```

4. Add the Software Update Point: CM01 → **Add Site System Roles** → **Software update point**.
   Use WSUS on CM01 and its SQL-backed configuration, synchronize from Microsoft Update, initially
   select Windows 11 products and a small classification set such as Critical Updates, Security
   Updates, and Updates. Synchronize once and watch `wsyncmgr.log`; do not use WID.

   PowerShell equivalent:

   ```powershell
   Add-CMSoftwareUpdatePoint -SiteSystemServerName 'CM01.hufflab.internal' -WsusIisPort 8530 -UseProxy $false
   ```

5. Configure Active Directory discovery in **Administration** → **Hierarchy Configuration** →
   **Discovery Methods**. Enable **Active Directory System Discovery**, **User Discovery**, and
   **Group Discovery**; scope each to the `HUFFLAB` OU tree and enable heartbeat discovery. Avoid
   broad production-style root discovery in this lab. 📸 Evidence: discovery methods and scopes.

   PowerShell equivalent:

   ```powershell
   Set-CMDiscoveryMethod -Name 'SMS_AD_SYSTEM_DISCOVERY_AGENT' -Enable $true
   Set-CMDiscoveryMethod -Name 'SMS_AD_USER_DISCOVERY_AGENT' -Enable $true
   Set-CMDiscoveryMethod -Name 'SMS_AD_SECURITY_GROUP_DISCOVERY_AGENT' -Enable $true
   ```

6. Create the network boundary: **Administration** → **Hierarchy Configuration** → **Boundaries**
   → **Create Boundary** → Type **IP range**, start `10.0.100.1`, end `10.0.100.254`, description
   `Hufflab internal subnet`. Create boundary group `BG-Lab`, add that boundary, enable **Use this
   boundary group for site assignment**, assign site `HUF`, and add CM01 as a site system. This is
   an IP range—not an AD site or subnet boundary.

   PowerShell equivalent:

   ```powershell
   $boundary = New-CMBoundary -Name 'Hufflab IP Range' -Type IPRange -Value '10.0.100.1-10.0.100.254'
   $group = New-CMBoundaryGroup -Name 'BG-Lab' -DefaultSiteCode 'HUF'
   Add-CMBoundaryToGroup -BoundaryGroupName 'BG-Lab' -BoundaryName $boundary.DisplayName
   Set-CMBoundaryGroup -Name 'BG-Lab' -AddSiteSystemServerName 'CM01.hufflab.internal'
   ```

7. In **Administration** → **Site Configuration** → **Sites** → **Client Installation Settings** →
   **Client Push Installation**, enable automatic client push for workstations. Add
   `HUFFLAB\svc-sccm-push` on the **Accounts** tab. Alternatively, right-click CL02 under
   **Assets and Compliance** → **Devices** → **Install Client** and use the wizard. Monitor
   `\\CM01\SMS_HUF\Client\ccmsetup.exe` activity and `ccmsetup.log` on CL02.

   PowerShell equivalent:

   ```powershell
   Start-Process '\\CM01\SMS_HUF\Client\ccmsetup.exe' -ArgumentList 'SMSSITECODE=HUF' -Wait
   ```

8. Create device collections in **Assets and Compliance** → **Device Collections**. Create
   `WKS-All` with a query rule for systems whose System OU equals the Workstations OU. Create
   `OSD-Targets` as a direct-membership collection; add targets only when intentionally approved.
   📸 Evidence: collection membership and query criteria.

   PowerShell equivalent (replace the distinguished name if the domain changes):

   ```powershell
   New-CMDeviceCollection -Name 'WKS-All' -LimitingCollectionName 'All Systems'
   New-CMDeviceCollection -Name 'OSD-Targets' -LimitingCollectionName 'All Systems'
   ```

## Verify

```powershell
# CM01 Configuration Manager console PowerShell drive
Set-Location HUF:
Get-CMSite | Select-Object SiteCode,SiteName
Get-CMBoundaryGroup -Name 'BG-Lab' | Select-Object Name,DefaultSiteCode
Get-CMDevice -Name CL02 | Select-Object Name,Client,ClientVersion
```

```text
SiteCode SiteName
-------- --------
HUF      Hufflab Primary Site

Name   DefaultSiteCode
----   ---------------
BG-Lab HUF

Name Client ClientVersion
---- ------ -------------
CL02 True   5.00.xxxx.xxxx
```

```powershell
# CL02
Get-Service CcmExec | Select-Object Status,Name
Get-Content 'C:\Windows\CCM\Logs\LocationServices.log' -Tail 20
```

```text
Status  Name
------  ----
Running CcmExec
Assigned to site HUF
```

## Rollback

For a failed site setup, use ConfigMgr Setup maintenance/uninstall only when following its logged
failure state; do not delete SQL databases manually. For a clean lab retry, revert all three
VMs to their `Pre-Phase08-*` checkpoints. This also discards the pushed client and discovered
records; repeat discovery after restoration.

## Troubleshoot

- Setup fails prerequisite checks: review `C:\ConfigMgrSetup.log`, verify SQL collation/memory,
  ADK plus WinPE, and the System Management container delegation from Phase 07.
- CL02 client push returns access denied: test `\\CL02\admin$` using `svc-sccm-push`, verify local
  Administrator rights and firewall rules, then inspect `C:\Program Files\Microsoft Configuration Manager\Logs\ccm.log`.
- Client is unassigned: query `ipconfig /all` on CL02 and confirm `BG-Lab` contains the exact IP
  range and assigns site `HUF`; check `LocationServices.log`.
- SUP synchronization fails: inspect `wsyncmgr.log`, confirm WSUS is SQL-backed and listening on
  8530 with `Get-NetTCPConnection -LocalPort 8530`.
- Reporting role is unhealthy: open the SSRS Web Portal locally and inspect
  `srsrp.log` and SSRS service status before recreating the role.

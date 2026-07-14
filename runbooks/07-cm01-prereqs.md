# Phase 07 — CM01 prerequisites

> **Resume bullet:** #3 · **Est. time:** 4–6 h · **VMs on:** DC01+CM01 (20 GB / 28 GB budget)

## Objectives

- Prepare CM01 for a Current Branch 2509 evaluation primary site without installing the site.
- Extend the `hufflab.internal` schema and delegate the System Management container to `CM01$`.
- Install ADK 11 24H2 with WinPE, SQL Server 2022 Evaluation, WSUS, SSRS, and required firewall rules.

## Prerequisites

- Phase 06 is complete; DC01 is healthy and CM01 is joined to `hufflab.internal` with static
  address `10.0.100.30`, DNS `10.0.100.10`, and current Windows updates.
- Take Hyper-V checkpoints named `Pre-Phase07-DC01` and `Pre-Phase07-CM01`. DC01 (4 GB) plus
  CM01 (16 GB) consumes 20 GB, leaving 8 GB within the 28 GB VM budget.
- Stage the ConfigMgr Current Branch 2509 evaluation, SQL Server 2022 Evaluation, SSMS, ODBC
  Driver 18, ADK 11 24H2 (`10.1.26100.x`), WinPE add-on, and SQL Server Reporting Services
  installers on CM01. Use the media checklist in [../docs/iso-checklist.md](../docs/iso-checklist.md).
- Sign in with an account that is Enterprise Admin and local administrator on CM01. The example
  password `LabP@ss2026!` is documentation only; substitute a unique lab password.

## Steps

1. On DC01, open **Active Directory Users and Computers** → **View** → **Advanced Features** →
   right-click the domain → **New** → **Object** → **container**. Create `System Management`.
   Open its **Properties** → **Security** → **Advanced**, add `HUFFLAB\CM01$`, and grant **Full
   Control** applying to **This object and all descendant objects**. 📸 Evidence: the delegation
   entry and inheritance scope.

   PowerShell equivalent on DC01 (run once; it creates the container only when absent):

   ```powershell
   $base = (Get-ADDomain).DistinguishedName
   $dn = "CN=System Management,CN=System,$base"
   if (-not (Get-ADObject -LDAPFilter "(distinguishedName=$dn)" -ErrorAction SilentlyContinue)) {
       New-ADObject -Name 'System Management' -Type container -Path "CN=System,$base"
   }
   $acl = Get-Acl "AD:$dn"
   $sid = (Get-ADComputer CM01).SID
   $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
       $sid, 'GenericAll', 'Allow', [Guid]::Empty, 'All')
   $acl.AddAccessRule($rule)
   Set-Acl "AD:$dn" $acl
   ```

2. On CM01, mount or extract the ConfigMgr 2509 evaluation media. In an elevated command prompt,
   run `extadsch.exe` from the media root. It must run before setup, using an Enterprise Admin
   token. Review `C:\ExtADSch.log` and do not proceed if it reports an error. 📸 Evidence: the
   successful schema-extension log entry.

   PowerShell equivalent:

   ```powershell
   Start-Process -FilePath 'D:\SMSSETUP\BIN\X64\extadsch.exe' -Wait
   Get-Content C:\ExtADSch.log -Tail 20
   ```

3. On CM01, install **Windows Assessment and Deployment Kit** from the ADK installer: select
   **Deployment Tools** and **User State Migration Tool**. Run the separate WinPE add-on installer
   and select **Windows Preinstallation Environment (Windows PE)**. Do not use the Server 2022
   WDS boot image here; ConfigMgr uses its ADK boot image.

   PowerShell equivalent (replace installer paths with staged files and accept the license):

   ```powershell
   Start-Process 'C:\Installers\adksetup.exe' -ArgumentList '/quiet /features OptionId.DeploymentTools OptionId.UserStateMigrationTool /ceip off' -Wait
   Start-Process 'C:\Installers\adkwinpesetup.exe' -ArgumentList '/quiet /features OptionId.WindowsPreinstallationEnvironment /ceip off' -Wait
   ```

4. Run SQL Server 2022 Setup on CM01. Choose **New SQL Server stand-alone installation** →
   **Database Engine Services**; accept the default instance, set collation to
   `SQL_Latin1_General_CP1_CI_AS`, and use a dedicated SQL service account or the supported lab
   default. Add the installer administrator and `HUFFLAB\Administrator` as SQL administrators.
   Install SSMS separately. SQL Express is not supported for this primary site.

   PowerShell equivalent for unattended setup (review account choices before use):

   ```powershell
   Start-Process 'C:\Installers\SQL2022\setup.exe' -ArgumentList '/Q /ACTION=Install /FEATURES=SQLENGINE /INSTANCENAME=MSSQLSERVER /SQLCOLLATION=SQL_Latin1_General_CP1_CI_AS /SQLSYSADMINACCOUNTS="HUFFLAB\Administrator" /IACCEPTSQLSERVERLICENSETERMS' -Wait
   ```

5. In SSMS, connect to `CM01` using Windows Authentication. Right-click the server →
   **Properties** → **Memory**, set **Maximum server memory** to `8192` MB, then restart the SQL
   Server service during this maintenance window. ConfigMgr will create its database with
   compatibility level 150.

   PowerShell equivalent:

   ```powershell
   Invoke-Sqlcmd -ServerInstance CM01 -Query "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'max server memory (MB)', 8192; RECONFIGURE;"
   ```

6. In **Server Manager** → **Manage** → **Add Roles and Features**, install **Windows Server
   Update Services** with **WSUS Services** and **Database**. Point WSUS at the default SQL
   instance on CM01, not Windows Internal Database. Choose a content directory such as
   `D:\WSUS`. Complete post-installation after SQL is ready. 📸 Evidence: WSUS role and content
   path.

   PowerShell equivalent:

   ```powershell
   Install-WindowsFeature -Name UpdateServices,UpdateServices-Services,UpdateServices-DB -IncludeManagementTools
   & 'C:\Program Files\Update Services\Tools\WsusUtil.exe' postinstall SQL_INSTANCE_NAME='CM01' CONTENT_DIR='D:\WSUS'
   ```

7. Install SQL Server Reporting Services using the SSRS installer, configure the report server
   database on the local default SQL instance, and verify the Web Portal opens. In **Windows
   Defender Firewall with Advanced Security**, create inbound TCP rules for SQL 1433, WSUS 8530,
   HTTP 80, HTTPS 443, and later ConfigMgr client/PXE roles as required. Keep the profile scoped
   to the isolated lab network.

   PowerShell equivalent:

   ```powershell
   1433,8530,80,443 | ForEach-Object {
       New-NetFirewallRule -DisplayName "Lab CM01 TCP $_" -Direction Inbound -Protocol TCP -LocalPort $_ -Action Allow
   }
   ```

## Verify

Run these checks from CM01 or DC01 as indicated. Expected results demonstrate every prerequisite.

```powershell
# DC01: CM01 delegation and schema extension
Get-ADObject -Identity "CN=System Management,CN=System,$((Get-ADDomain).DistinguishedName)"
Get-Content C:\ExtADSch.log -Tail 5
```

```text
Name              ObjectClass
----              -----------
System Management container
Successfully extended the Active Directory schema.
```

```powershell
# CM01: ADK, SQL collation/memory, WSUS service, and SSRS service
Test-Path 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit'
Invoke-Sqlcmd -ServerInstance CM01 -Query "SELECT SERVERPROPERTY('Collation') AS Collation, value_in_use AS MaxMemoryMB FROM sys.configurations WHERE name='max server memory (MB)'"
Get-Service WsusService,SQLServerReportingServices | Select-Object Name,Status
```

```text
True
Collation                          MaxMemoryMB
---------                          -----------
SQL_Latin1_General_CP1_CI_AS       8192
WsusService                        Running
SQLServerReportingServices         Running
```

## Rollback

If a prerequisite install fails or the configuration becomes inconsistent, uninstall only the
failed component before retrying. For a clean retry, revert CM01 to `Pre-Phase07-CM01` and DC01
to `Pre-Phase07-DC01`; this removes the schema extension only if the DC checkpoint is restored
before any later directory work. Never restore a DC checkpoint casually after subsequent AD
changes—rebuild the lab instead when directory rollback safety is uncertain.

## Troubleshoot

- `extadsch.exe` reports access denied: confirm the token is Enterprise Admin and inspect
  `C:\ExtADSch.log` with `Get-Content C:\ExtADSch.log -Tail 50`.
- ConfigMgr setup later cannot publish to AD: inspect the `System Management` ACL with
  `Get-Acl "AD:CN=System Management,CN=System,$((Get-ADDomain).DistinguishedName)"`; confirm
  `CM01$` has Full Control on this object and descendants.
- SQL setup fails collation validation: query `SELECT SERVERPROPERTY('Collation')`; reinstall the
  lab SQL instance with `SQL_Latin1_General_CP1_CI_AS`, not a different default.
- WSUS post-install fails: verify SQL is running with `Get-Service MSSQLSERVER`, free space on
  `D:`, and review `%ProgramFiles%\Update Services\LogFiles`.
- ADK/WinPE is absent from ConfigMgr prerequisites: verify both installers completed and that the
  installed ADK is 11 24H2 (`10.1.26100.x`), then repair the missing component.

# Phase 02 — DC01: AD DS, DNS, DHCP

> **Resume bullet:** #1 · **Est. time:** 3–5 h · **VMs on:** DC01 (4 GB / 28 GB budget)

## Objectives

- Configure and patch DC01, including the WS2025 Public-profile fix at KB5060842 or later, before
  promoting it to `hufflab.internal`.
- Create the AD DS forest, AD-integrated forward and reverse DNS zones, forwarders, and scavenging.
- Install and authorize DHCP on DC01 with the canonical 8-hour scope and no PXE DHCP options.

## Prerequisites

- Phase 01 is verified. Start only DC01 (4 GB); WDS01, CM01, clients, and REF01 remain off.
- Create Hyper-V checkpoint `pre-phase-02`. Have a WS2025 cumulative update at KB5060842 or later
  available, and retain the local Administrator password securely.
- On first boot, delete the one-time unattend answer file after confirming that the computer name and
  local Administrator configuration completed. Do not leave a password-bearing answer file on disk.

## Steps

1. Start DC01 and sign in as its local Administrator. Configure its adapter to static
   `10.0.100.10/24` with default gateway `10.0.100.1`. Use the external resolvers `1.1.1.1` and
   `9.9.9.9` only during the pre-promotion patch step; DC01 cannot resolve through itself until DNS is
   installed. Set the computer name to `DC01` if needed and reboot.

   Console path: **Server Manager > Local Server > Ethernet > Properties > Internet Protocol Version 4
   (TCP/IPv4)**. PowerShell equivalent:

   ```powershell
   Get-NetAdapter
   New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 10.0.100.10 -PrefixLength 24 -DefaultGateway 10.0.100.1
   Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses 1.1.1.1, 9.9.9.9
   Rename-Computer -NewName DC01 -Restart
   ```

2. After the reboot, remove the injected answer file and patch the server before promotion. In
   **Settings > Windows Update**, install KB5060842 or later and restart until fully current. This avoids
   the WS2025 post-reboot Public-profile bug that can block expected firewall behavior.

   ```powershell
   Remove-Item 'C:\Windows\Panther\unattend.xml' -Force
   Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10 HotFixID, InstalledOn
   Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses 10.0.100.10
   ```

   Do not promote until the update has installed, the server has rebooted, and its only configured DNS
   server is `10.0.100.10`.

   📸 Evidence: DC01 static IPv4 settings and installed KB5060842 or a later cumulative update.

3. Install AD DS and DNS, then promote DC01 as the new `hufflab.internal` forest. In **Server Manager
   > Manage > Add Roles and Features**, add **Active Directory Domain Services** and **DNS Server**;
   choose the post-deployment notification, **Add a new forest**, enter `hufflab.internal`, select
   Windows Server 2025 forest/domain functional levels (level 10), set the DSRM password, and install.

   ```powershell
   Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
   $dsrmPassword = Read-Host 'DSRM password' -AsSecureString
   Install-ADDSForest -DomainName 'hufflab.internal' -DomainNetbiosName 'HUFFLAB' `
     -ForestMode Win2025 -DomainMode Win2025 -SafeModeAdministratorPassword $dsrmPassword -Force
   ```

   Note: use the GUI's displayed Windows Server 2025 functional level. On builds where the cmdlet
   exposes a newer level name, select level 10; do not intentionally choose an older functional level.

4. After promotion and reboot, configure Internet DNS forwarders, create the reverse zone, and enable
   scavenging. The forward `hufflab.internal` zone is AD-integrated from promotion.

   Console path: **Server Manager > Tools > DNS**. Under the server, open **Properties > Forwarders**
   and add `1.1.1.1` and `9.9.9.9`; use **Reverse Lookup Zones > New Zone** for the AD-integrated
   `100.0.10.in-addr.arpa` zone; enable aging/scavenging in server properties.

   ```powershell
   Set-DnsServerForwarder -IPAddress 1.1.1.1, 9.9.9.9
   Add-DnsServerPrimaryZone -NetworkId '10.0.100.0/24' -ReplicationScope Domain
   Set-DnsServerScavenging -ScavengingState $true -ApplyOnAllZones
   ```

5. Install DHCP, authorize it in AD, and create the scope. In **Server Manager > Manage > Add Roles and
   Features**, add **DHCP Server**, complete post-install configuration, and authorize DC01. In the DHCP
   console, create scope `Lab-10.0.100.0`, range `10.0.100.100`–`10.0.100.199`, `/24` mask, and an
   8-hour lease. The reserved `.1`–`.99` addresses are already outside the pool, so no exclusion is
   needed for them. Set only scope options 003 Router
   (`10.0.100.1`), 006 DNS Servers (`10.0.100.10`), and 015 DNS Domain Name (`hufflab.internal`).

   ```powershell
   Install-WindowsFeature DHCP -IncludeManagementTools
   Add-DhcpServerInDC -DnsName 'DC01.hufflab.internal' -IPAddress 10.0.100.10
   Add-DhcpServerv4Scope -Name 'Lab-10.0.100.0' -StartRange 10.0.100.100 -EndRange 10.0.100.199 `
     -SubnetMask 255.255.255.0 -LeaseDuration (New-TimeSpan -Hours 8) -State Active
   Set-DhcpServerv4OptionValue -ScopeId 10.0.100.0 -Router 10.0.100.1 -DnsServer 10.0.100.10 `
     -DnsDomain 'hufflab.internal'
   ```

   Do not set DHCP options 60, 66, or 67. This is a same-subnet broadcast design; WDS and later
   Configuration Manager PXE are deliberately handled by a single live responder, not DHCP options.

   📸 Evidence: DHCP authorization, active scope range, and scope options 003/006/015.

6. Create or confirm checkpoint `pre-phase-03` after all verification passes. DC01 remains powered on
   for the next phase. Run this from the Hyper-V host, not inside DC01.

   ```powershell
   Checkpoint-VM -Name DC01 -SnapshotName pre-phase-03
   ```

## Verify

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode
Get-ADForest | Select-Object RootDomain, ForestMode
```

Expected output includes `hufflab.internal`, `HUFFLAB`, and Windows Server 2025 functional level
(level 10) for both domain and forest.

```powershell
Resolve-DnsName DC01.hufflab.internal
Get-DnsServerZone | Where-Object ZoneName -in 'hufflab.internal', '100.0.10.in-addr.arpa' |
  Select-Object ZoneName, IsDsIntegrated, ReplicationScope
Get-DnsServerForwarder | Select-Object -ExpandProperty IPAddress
Get-DnsServerScavenging | Select-Object ScavengingState
Get-NetIPConfiguration -InterfaceAlias Ethernet
Get-DnsClientServerAddress -InterfaceAlias Ethernet -AddressFamily IPv4
Test-Path 'C:\Windows\Panther\unattend.xml'
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10 HotFixID, InstalledOn
Get-ComputerInfo | Select-Object WindowsProductName, OsVersion, OsBuildNumber
```

Expected output resolves DC01 to `10.0.100.10`, lists both zones as AD-integrated, lists `1.1.1.1`
and `9.9.9.9`, and shows scavenging enabled. DC01 retains static `10.0.100.10/24`, gateway
`10.0.100.1`, and itself as its only DNS server. The answer-file test returns `False`; the installed
updates show KB5060842 or a later cumulative update and its build has been recorded.

```powershell
Get-DhcpServerInDC
Get-DhcpServerv4Scope -ScopeId 10.0.100.0 | Select-Object ScopeId, StartRange, EndRange, LeaseDuration, State
$scopeOptions = @(Get-DhcpServerv4OptionValue -ScopeId 10.0.100.0 -All)
$serverOptions = @(Get-DhcpServerv4OptionValue -All)
$scopeOptions
$serverOptions
$allOptions = $scopeOptions + $serverOptions
if ($allOptions | Where-Object OptionId -in 60,66,67) { throw 'PXE DHCP option 60, 66, or 67 is configured.' }
```

Expected output shows authorized DC01, active range `10.0.100.100`–`10.0.100.199`, an 8-hour lease,
and scope options 003, 006, and 015 only. Options 60, 66, and 67 must be absent at server and scope
levels; the command throws if it finds one.

## Rollback

Apply `pre-phase-02` to DC01 to discard the promotion and DHCP/DNS configuration, then verify no
unwanted AD DNS records remain before retrying. If the failure is limited to Phase 03 work, apply
`pre-phase-03` instead. A reverted DC must not be reintroduced beside an unreverted copy of the same
domain controller. Do not roll back after other domain members have joined without planning AD recovery.

## Troubleshoot

1. **The network profile remains Public after reboot.** Confirm KB5060842 or later is installed, then
   inspect profile and firewall state. Patch and reboot before continuing with AD DS.

   ```powershell
   Get-HotFix -Id KB5060842 -ErrorAction SilentlyContinue
   Get-NetConnectionProfile
   ```

2. **Promotion fails DNS prerequisite checks.** Ensure the only preferred DNS is `10.0.100.10`, the
   static address is correct, and no external resolver is configured on DC01.

   ```powershell
   Get-DnsClientServerAddress -AddressFamily IPv4
   Test-NetConnection 10.0.100.1
   ```

3. **Clients can resolve Internet names but not lab names, or the reverse.** Confirm the AD-integrated
   zone, reverse zone, and forwarders; clear stale resolver cache after correction.

   ```powershell
   Get-DnsServerZone
   Clear-DnsClientCache
   ```

4. **DHCP authorization or scope activation fails.** Sign in with a domain administrator after
   promotion, confirm DC01 resolves to its own address, and inspect DHCP authorization.

   ```powershell
   Get-DhcpServerInDC
   Get-DhcpServerv4Scope
   ```

5. **A PXE client does not receive an offer later.** Do not add options 60/66/67. First verify that the
   client and DC01 are on `LabSwitch` and that the active scope contains free leases.

   ```powershell
   Get-DhcpServerv4Lease -ScopeId 10.0.100.0
   ```

6. **An unattended-install password remains on disk.** Delete `C:\Windows\Panther\unattend.xml`, rotate
   the local Administrator password if exposed, and do not capture it in evidence.

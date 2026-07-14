# IP plan and naming

## Network allocation

The lab is one isolated IPv4 subnet on the Hyper-V Internal vSwitch `LabSwitch`.
The Hyper-V host provides NAT only through `LabNAT`; it is not an AD DS, DNS, or DHCP server.

| Item | Value | Notes |
|---|---|---|
| Network | `10.0.100.0/24` | Single isolated lab subnet |
| Hyper-V vSwitch | `LabSwitch` | Internal switch |
| Host vNIC / gateway | `10.0.100.1` | NAT gateway created by `New-NetNat -Name LabNAT` |
| Reserved static range | `10.0.100.1–10.0.100.99` | Infrastructure and future reservations |
| DHCP pool | `10.0.100.100–10.0.100.199` | Eight-hour lease |
| Unallocated range | `10.0.100.200–10.0.100.254` | Keep available for later experiments |

| Host / VM | IPv4 address | DNS registration / purpose |
|---|---|---|
| Hyper-V host | `10.0.100.1` | Gateway; not a domain member requirement |
| DC01 | `10.0.100.10` | AD DS, DNS, and authorized DHCP |
| WDS01 | `10.0.100.20` | Standalone WDS PXE during WDS phases |
| CM01 | `10.0.100.30` | ConfigMgr, SQL, WSUS/SUP, MP, DP, SSRS, later PXE |
| CL01 / CL02 / REF01 | DHCP | Client, test, and reference workloads |

## DHCP and DNS

DC01 hosts an AD-authorized DHCP scope for `10.0.100.100–10.0.100.199` with a `/24` mask,
router `10.0.100.1`, DNS server `10.0.100.10`, and an eight-hour lease. The DNS server hosts
the AD-integrated forward zone `hufflab.internal` and reverse zone `100.0.10.in-addr.arpa`;
configure `1.1.1.1` and `9.9.9.9` as forwarders and enable scavenging after the lab is stable.

The PXE clients and their responder are on the same broadcast domain. Keep that topology
simple during the lab: validate DHCP leases and the selected responder during each PXE phase,
then move to ConfigMgr only through the documented Phase 10 handoff.

## Identity names

| Setting | Value |
|---|---|
| Forest-root domain | `hufflab.internal` |
| NetBIOS name | `HUFFLAB` |
| Forest and domain functional level | Windows Server 2025 (level 10) |
| SCCM site | `HUF` — Hufflab Primary Site |
| Golden WIM | `HUFFLAB-Win11-Golden.wim` |

The `.internal` suffix is special-use and avoids claiming a public DNS namespace. Its
designation is maintained in the [IANA Special-Use Domain Name registry](https://www.iana.org/assignments/special-use-domain-names/special-use-domain-names.xhtml).

## Rename the lab

Choose the final domain name before creating the forest. A domain rename is a recovery-tested,
planned change—not an early-lab shortcut—and it affects DNS, SPNs, certificates, service
accounts, Group Policy paths, ConfigMgr integration, and any deployed clients.

If a rename becomes necessary, use this procedure during a maintenance window before adding
SCCM-managed clients or rebuilding them is cheaper:

1. Record the current topology, export GPO backups, take a system-state backup of DC01, and
   take named Hyper-V checkpoints of affected VMs. Confirm that AD replication and DNS are
   healthy with `dcdiag` and `repadmin /replsummary`.
2. Read Microsoft's [Active Directory domain rename guidance](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-forest-root-domain-rename)
   and confirm every workload in the lab supports a domain rename. If ConfigMgr or another
   dependency is already installed, prefer rebuilding the small lab unless its documented
   support statement explicitly permits the change.
3. On the domain controller, use the supported `rendom` workflow to generate the forest-list
   XML, edit the target DNS and NetBIOS names, upload the plan, prepare, execute, and end the
   rename. Restart each member computer when prompted by the procedure.
4. Recreate or verify forward and reverse DNS zones, DHCP DNS registration behavior, service
   principal names, certificates, UNC paths, GPO links, and static DNS settings. Re-authorize
   DHCP only if the post-rename validation identifies a problem.
5. Verify `nltest /dsgetdc:<new-domain>`, `dcdiag`, `repadmin /replsummary`, a client logon,
   name resolution, and Group Policy processing. Update `scripts/lab.config.psd1`, this file,
   and every runbook before proceeding.

For this disposable learning environment, a fresh forest and rebuilt clients are usually less
risky than a rename after phase 07. Keep the original `hufflab.internal` plan unless there is
a concrete reason to change it.

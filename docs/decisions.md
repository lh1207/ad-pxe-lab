# Architecture decisions

These records are intentionally concise. They document the choices that make the lab both
reproducible and honest about its boundaries.

## ADR-001 — Internal switch plus host NAT

**Status:** Accepted

**Decision:** Use the Hyper-V Internal switch `LabSwitch` and host-side `LabNAT` for
`10.0.100.0/24`. DC01 supplies AD DS DNS and DHCP, but is not a network gateway; do not use
an external switch for this lab.

**Rationale:** This gives VMs controlled outbound access through `10.0.100.1` while preventing
the lab DHCP/DNS services from leaking onto the physical network. It also makes the address
plan and packet captures repeatable.

**Consequences:** The host must retain a NAT rule and at least 4 GB RAM outside the VM budget.
Internet-dependent installs require the host's NAT path. See [Hyper-V virtual switch overview](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v-virtual-switch)
and [New-NetNat](https://learn.microsoft.com/en-us/powershell/module/netnat/new-netnat).

## ADR-002 — WDS on its own VM

**Status:** Accepted

**Decision:** Put standalone WDS PXE on WDS01, distinct from DC01 and CM01.

**Rationale:** The separation makes the WDS-to-ConfigMgr transition an observable service and
power-state change. It avoids teaching a same-box DHCP/PXE port-sharing configuration and
keeps WDS service state from confusing later ConfigMgr PXE troubleshooting.

**Consequences:** WDS01 costs 2 GB RAM during WDS phases. Microsoft notes special port-67
handling when WDS and DHCP occupy the same computer; the separate-VM layout avoids that
condition. See [WDS server may not start](https://learn.microsoft.com/en-us/troubleshoot/windows-server/setup-upgrade-and-drivers/wds-server-may-not-start).

## ADR-003 — `.internal` domain suffix

**Status:** Accepted

**Decision:** Create the forest root as `hufflab.internal` with NetBIOS name `HUFFLAB`.

**Rationale:** `.internal` is a special-use domain name reserved for private-use naming. It is
clearer than legacy `.local` or an invented public-looking suffix and is suitable for a
disposable isolated forest.

**Consequences:** The name is a lab identity, not an internet namespace. Changing it later is
possible only through a planned domain-rename workflow; a rebuild is usually cheaper after
ConfigMgr deployment. See the [IANA registry](https://www.iana.org/assignments/special-use-domain-names/special-use-domain-names.xhtml)
and [Active Directory domain rename guidance](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-forest-root-domain-rename).

## ADR-004 — Server 2022 boot image for standalone WDS

**Status:** Accepted

**Decision:** Use Server 2022 `boot.wim` for WDS boot and capture images; use Windows 11
Enterprise Evaluation `install.wim` for installation images.

**Rationale:** The standalone WDS portion needs a workable WinPE path while retaining an honest
learning arc toward ConfigMgr OSD. The server's WDS PXE and TFTP functions provide the network
boot path, while the client experience runs in WinPE.

**Consequences:** Do not import Win11/WS2025 media `boot.wim` into the standalone WDS workflow;
use the Server 2022 source explicitly. This is a constrained lab workaround, not a claim that
WDS is a modern end-state. See [WDS API overview](https://learn.microsoft.com/en-us/windows/win32/wds/about-the-windows-deployment-services-api)
and [Windows deployment scenarios and tools](https://learn.microsoft.com/en-us/windows/deployment/windows-deployment-scenarios-and-tools).

## ADR-005 — Full SQL Server 2022 on CM01

**Status:** Accepted

**Decision:** Install SQL Server 2022 Evaluation, default instance, on CM01 with the ConfigMgr
primary site. Use `SQL_Latin1_General_CP1_CI_AS`, compatibility level 150, and an 8192 MB SQL
memory cap. Do not use SQL Express.

**Rationale:** A ConfigMgr primary site requires a full SQL Server installation. Co-locating it
on CM01 is appropriate for this constrained lab and leaves DC01 dedicated to directory services.

**Consequences:** CM01 receives 16 GB static RAM and a 150 GB fixed VHDX. SQL Server 2022 is
supported for primary sites, and Microsoft's current guidance recommends compatibility level
150 for SQL Server 2022. See [supported SQL Server versions](https://learn.microsoft.com/en-us/intune/configmgr/core/plan-design/configs/support-for-sql-server-versions)
and [plan the site database](https://learn.microsoft.com/en-us/intune/configmgr/core/plan-design/hierarchy/plan-for-the-site-database).

## ADR-006 — Phased PXE: WDS first, ConfigMgr second

**Status:** Accepted

**Decision:** Run exactly one PXE responder on the subnet: WDS01 during WDS phases, then CM01's
ConfigMgr PXE responder without WDS after WDS01 is stopped, disabled, and powered off.

**Rationale:** PXE responders are a shared boot-path control plane. A physical handoff produces
a clear negative test—no responder means network boot times out—before CM01 begins answering.

**Consequences:** Phase 10 cannot begin until WDS01 is off. WDS01 remains available as a
checkpointed historical artifact but not as a running responder. Microsoft supports a PXE
responder without WDS on a distribution point; see [OSD infrastructure requirements](https://learn.microsoft.com/en-us/intune/configmgr/osd/plan-design/infrastructure-requirements-for-operating-system-deployment).

## ADR-007 — Same-subnet PXE without DHCP options or IP helpers

**Status:** Accepted

**Decision:** Keep DHCP on DC01 and the active PXE responder on the same `LabSwitch` subnet;
do not configure DHCP options 60, 66, or 67 and do not configure IP helpers.

**Rationale:** The lab's PXE broadcast traffic stays within one broadcast domain, so neither
cross-subnet relay configuration nor manually pinned boot-server settings adds learning value.

**Consequences:** This is deliberately not a routed enterprise topology. In a real routed
network, network teams normally use scoped relay/IP-helper design rather than copying this lab
unchanged. WDS documentation describes its PXE/TFTP role; see [Windows deployment scenarios and tools](https://learn.microsoft.com/en-us/windows/deployment/windows-deployment-scenarios-and-tools).

## ADR-008 — No MDT

**Status:** Accepted

**Decision:** Do not install or teach Microsoft Deployment Toolkit (MDT). Use WDS for the
introductory imaging phase and ConfigMgr OSD for the managed deployment phase.

**Rationale:** The lab should teach supported, observable operating-system deployment mechanics
instead of adding a retired automation layer.

**Consequences:** WDS client choices remain interactive and the later task sequence is authored
in ConfigMgr. The design keeps deployment concepts aligned with Microsoft's documented
deployment-tool landscape; see [Windows deployment scenarios and tools](https://learn.microsoft.com/en-us/windows/deployment/windows-deployment-scenarios-and-tools).

## ADR-009 — Hybrid script/manual boundary

**Status:** Accepted

**Decision:** Scripts stop at **base OS installed**. AD DS, DNS, DHCP, GPO, WDS, SQL, WSUS,
ConfigMgr, and PXE configuration are performed manually through runbooks.

**Rationale:** The lab is a skills portfolio, not an opaque provisioning framework. Manual
console paths and equivalent verification commands make each product decision inspectable.

**Consequences:** Rebuilds take longer, but every phase produces evidence and troubleshooting
practice. `scripts/lab.config.psd1` remains the single source for foundation names, addresses,
paths, and VM sizing; the runbooks own product configuration and validation.

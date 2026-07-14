#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
Creates or removes the isolated Hyper-V switch, host address, and NAT for the lab.

.DESCRIPTION
Creates the configured Internal switch and host NAT idempotently. Use -Remove to remove only
those configured network resources. Existing resources with conflicting settings are reported
instead of being replaced automatically.

.PARAMETER ConfigPath
Path to the lab PowerShell data file.

.PARAMETER Remove
Removes the configured NAT, host vNIC address, and internal switch after confirmation.

.EXAMPLE
.\01-New-LabSwitch.ps1

.EXAMPLE
.\01-New-LabSwitch.ps1 -Remove -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'lab.config.psd1'),
    [switch]$Remove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$config = Import-PowerShellDataFile -Path $ConfigPath
$network = $config.Network
$adapterAlias = 'vEthernet ({0})' -f $network.SwitchName

if ($Remove) {
    $nat = Get-NetNat -Name $network.NatName -ErrorAction SilentlyContinue
    if ($nat -and $PSCmdlet.ShouldProcess($network.NatName, 'Remove lab NAT')) {
        Remove-NetNat -Name $network.NatName -Confirm:$false
    }
    Get-NetIPAddress -InterfaceAlias $adapterAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -eq $network.HostIp } | ForEach-Object {
            if ($PSCmdlet.ShouldProcess($adapterAlias, "Remove host address $($network.HostIp)")) {
                Remove-NetIPAddress -InputObject $_ -Confirm:$false
            }
        }
    $switch = Get-VMSwitch -Name $network.SwitchName -ErrorAction SilentlyContinue
    if ($switch -and $PSCmdlet.ShouldProcess($network.SwitchName, 'Remove internal lab switch')) {
        Remove-VMSwitch -Name $network.SwitchName -Force
    }
    return
}

$switch = Get-VMSwitch -Name $network.SwitchName -ErrorAction SilentlyContinue
if (-not $switch) {
    if ($PSCmdlet.ShouldProcess($network.SwitchName, 'Create internal lab switch')) {
        New-VMSwitch -Name $network.SwitchName -SwitchType Internal | Out-Null
    }
} elseif ($switch.SwitchType -ne 'Internal') {
    throw "The existing switch '$($network.SwitchName)' is not Internal. Resolve the conflict manually."
}

$hostAddress = Get-NetIPAddress -InterfaceAlias $adapterAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -eq $network.HostIp }
if (-not $hostAddress) {
    if ($PSCmdlet.ShouldProcess($adapterAlias, "Assign host address $($network.HostIp)")) {
        New-NetIPAddress -InterfaceAlias $adapterAlias -IPAddress $network.HostIp -PrefixLength $network.PrefixLength | Out-Null
    }
}

$nat = Get-NetNat -Name $network.NatName -ErrorAction SilentlyContinue
if (-not $nat) {
    if ($PSCmdlet.ShouldProcess($network.NatName, "Create NAT for $($network.Subnet)")) {
        New-NetNat -Name $network.NatName -InternalIPInterfaceAddressPrefix $network.Subnet | Out-Null
    }
} elseif ($nat.InternalIPInterfaceAddressPrefix -ne $network.Subnet) {
    throw "The existing NAT '$($network.NatName)' does not use $($network.Subnet). Resolve the conflict manually."
}

#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
Removes lab VM definitions and their child disks.

.DESCRIPTION
Stops and removes only VMs declared in the configuration, then removes their VHDX files.
The read-only parent VHDX and ISO media are preserved by default. Add -IncludeParent only when
you intentionally want to rebuild all server children. Use -RemoveNetwork to invoke the
configured switch/NAT teardown after VM removal. Supports -WhatIf for a safe preview.

.PARAMETER ConfigPath
Path to the lab PowerShell data file.

.PARAMETER IncludeParent
Also removes the configured read-only parent VHDX. ISO files are never removed.

.PARAMETER RemoveNetwork
Removes the configured NAT, host address, and internal switch after VM teardown.

.EXAMPLE
.\99-Remove-Lab.ps1 -WhatIf

.EXAMPLE
.\99-Remove-Lab.ps1 -IncludeParent -RemoveNetwork -Confirm
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'lab.config.psd1'),
    [switch]$IncludeParent,
    [switch]$RemoveNetwork
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$config = Import-PowerShellDataFile -Path $ConfigPath

foreach ($specification in $config.VMs.Values) {
    $vm = Get-VM -Name $specification.Name -ErrorAction SilentlyContinue
    if ($vm) {
        if ($vm.State -ne 'Off' -and $PSCmdlet.ShouldProcess($specification.Name, 'Stop lab VM')) {
            Stop-VM -Name $specification.Name -TurnOff -Force
        }
        if ($PSCmdlet.ShouldProcess($specification.Name, 'Remove lab VM')) {
            Remove-VM -Name $specification.Name -Force
        }
    }
    $vhdPath = Join-Path -Path $config.Paths.VhdDir -ChildPath ('{0}.vhdx' -f $specification.Name)
    if ((Test-Path -LiteralPath $vhdPath -PathType Leaf) -and $PSCmdlet.ShouldProcess($vhdPath, 'Remove lab VM disk')) {
        Remove-Item -LiteralPath $vhdPath -Force
    }
}

if ($IncludeParent -and (Test-Path -LiteralPath $config.Paths.ParentVhdx -PathType Leaf)) {
    if ($PSCmdlet.ShouldProcess($config.Paths.ParentVhdx, 'Remove read-only parent VHDX')) {
        (Get-Item -LiteralPath $config.Paths.ParentVhdx).IsReadOnly = $false
        Remove-Item -LiteralPath $config.Paths.ParentVhdx -Force
    }
}

if ($RemoveNetwork) {
    $networkScript = Join-Path -Path $PSScriptRoot -ChildPath '01-New-LabSwitch.ps1'
    if (-not (Test-Path -LiteralPath $networkScript -PathType Leaf)) { throw "Network script was not found: $networkScript" }
    & $networkScript -ConfigPath $ConfigPath -Remove -WhatIf:$WhatIfPreference
}

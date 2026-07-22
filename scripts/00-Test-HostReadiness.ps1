#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
Tests whether a Hyper-V host meets the prerequisites for the lab foundation.

.DESCRIPTION
Validates Hyper-V, installed RAM, free storage, firmware virtualization, configured media,
and PowerShell syntax for all sibling scripts. This script changes no host configuration.

.PARAMETER ConfigPath
Path to the lab PowerShell data file. The default is lab.config.psd1 beside this script.

.EXAMPLE
.\00-Test-HostReadiness.ps1

.EXAMPLE
.\00-Test-HostReadiness.ps1 -ConfigPath C:\Lab\lab.config.psd1
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'lab.config.psd1')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-ReadinessResult {
    param([string]$Check, [bool]$Passed, [string]$Detail)
    [pscustomobject]@{ Check = $Check; Passed = $Passed; Detail = $Detail }
}

$config = Import-PowerShellDataFile -Path $ConfigPath
$results = @()

$isWindowsPowerShell51 = $PSVersionTable.PSEdition -eq 'Desktop' -and
    $PSVersionTable.PSVersion -ge [version]'5.1'
$results += New-ReadinessResult -Check 'Windows PowerShell 5.1' -Passed $isWindowsPowerShell51 -Detail (
    '{0} {1}' -f $PSVersionTable.PSEdition, $PSVersionTable.PSVersion
)

$feature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V-All'
$results += New-ReadinessResult -Check 'Hyper-V feature' -Passed ($feature.State -eq 'Enabled') -Detail $feature.State

$computer = Get-CimInstance -ClassName Win32_ComputerSystem
$installedRamGB = [math]::Floor($computer.TotalPhysicalMemory / 1GB)
$results += New-ReadinessResult -Check 'Installed memory' -Passed ($installedRamGB -ge $config.HostRequirements.MinimumMemoryGB) -Detail ("{0} GB installed; {1} GB minimum" -f $installedRamGB, $config.HostRequirements.MinimumMemoryGB)

$labRoot = $config.Paths.LabRoot
$driveRoot = [System.IO.Path]::GetPathRoot($labRoot)
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $driveRoot.TrimEnd('\'))
$freeGB = [math]::Floor($disk.FreeSpace / 1GB)
$results += New-ReadinessResult -Check 'Lab storage' -Passed ($freeGB -ge $config.HostRequirements.MinimumFreeDiskGB) -Detail ("{0} GB free on {1}; {2} GB minimum" -f $freeGB, $driveRoot, $config.HostRequirements.MinimumFreeDiskGB)

$processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$virtualizationEnabled = [bool]$processor.VirtualizationFirmwareEnabled
$results += New-ReadinessResult -Check 'CPU virtualization' -Passed $virtualizationEnabled -Detail ("Firmware virtualization enabled: {0}" -f $virtualizationEnabled)

foreach ($media in $config.Paths.IsoFiles.GetEnumerator()) {
    $mediaPath = Join-Path -Path $config.Paths.IsoDir -ChildPath $media.Value
    $results += New-ReadinessResult -Check ("Media: {0}" -f $media.Key) -Passed (Test-Path -LiteralPath $mediaPath -PathType Leaf) -Detail $mediaPath
}

Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
    $detail = if ($parseErrors.Count -eq 0) { 'No parser errors.' } else { ($parseErrors | ForEach-Object Message) -join '; ' }
    $results += New-ReadinessResult -Check ("Syntax: {0}" -f $_.Name) -Passed ($parseErrors.Count -eq 0) -Detail $detail
}

$results | Format-Table -AutoSize
if ($results.Where({ -not $_.Passed }).Count -gt 0) {
    Write-Error 'Host readiness did not pass. Correct the failed checks before creating lab resources.'
}

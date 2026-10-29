[CmdletBinding()]
param(
    [string]$ExpectedHostName = 'WOLF'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$isWindowsPlatform = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
if (-not $isWindowsPlatform) {
    throw 'Phase 05 must run on the Windows Hyper-V host. Linux, WSL, containers, and cloud shells are not valid execution environments.'
}

$expectedRepositoryRoot = 'C:\HyperV\ad-pxe-lab'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$workingDirectory = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\')
if ($repositoryRoot -ine $expectedRepositoryRoot -or
    ($workingDirectory -ine $expectedRepositoryRoot -and
     -not $workingDirectory.StartsWith($expectedRepositoryRoot + '\', [StringComparison]::OrdinalIgnoreCase))) {
    throw 'Run the repository copy of this preflight from C:\HyperV\ad-pxe-lab or one of its subdirectories.'
}

$actualHostName = [System.Net.Dns]::GetHostName()
if ($actualHostName -ine $ExpectedHostName) {
    throw "Expected Windows Hyper-V host '$ExpectedHostName'; current host is '$actualHostName'. Move the task to the WOLF local project before continuing."
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isElevated) {
    throw 'Open an elevated Windows PowerShell session on WOLF and rerun this preflight.'
}

$requiredCommands = @(
    'Get-VM'
    'Get-VMSnapshot'
    'Get-VMHost'
    'Get-VMFirmware'
    'Invoke-Command'
)

$missingCommands = @($requiredCommands | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
if ($missingCommands) {
    throw "Missing required Windows commands: $($missingCommands -join ', '). Use elevated Windows PowerShell with the Hyper-V module installed."
}

$invokeCommand = Get-Command Invoke-Command
if (-not $invokeCommand.Parameters.ContainsKey('VMName')) {
    throw 'PowerShell Direct is unavailable because Invoke-Command has no VMName parameter.'
}

$configPath = Join-Path $PSScriptRoot 'lab.config.psd1'
$config = Import-PowerShellDataFile -Path $configPath
$expectedVmNames = @($config.VMs.Keys | Sort-Object)
$vms = @(Get-VM -Name $expectedVmNames)

if ($vms.Count -ne $expectedVmNames.Count) {
    throw "Expected $($expectedVmNames.Count) lab VMs but found $($vms.Count)."
}

$requiredRunning = @('DC01', 'CL02')
$requiredOff = @('WDS01', 'CM01', 'CL01', 'REF01')
$wrongRunning = @($vms | Where-Object { $_.Name -in $requiredRunning -and $_.State -ne 'Running' })
$wrongOff = @($vms | Where-Object { $_.Name -in $requiredOff -and $_.State -ne 'Off' })

if ($wrongRunning -or $wrongOff) {
    $stateSummary = $vms | Select-Object Name, State | Format-Table -AutoSize | Out-String
    throw "Phase 05 requires only DC01 and CL02 running. Correct the VM boundary, then rerun.`n$stateSummary"
}

$automaticCheckpoints = @($vms | Where-Object AutomaticCheckpointsEnabled)
if ($automaticCheckpoints) {
    throw "Automatic checkpoints must remain disabled: $($automaticCheckpoints.Name -join ', ')"
}

$requiredSnapshots = foreach ($vmName in $requiredRunning) {
    $snapshots = @(Get-VMSnapshot -VMName $vmName -Name 'pre-phase-05' -ErrorAction Stop)
    if ($snapshots.Count -ne 1 -or $snapshots[0].SnapshotType -ne 'Standard') {
        throw "Expected exactly one standard pre-phase-05 checkpoint on $vmName. Inspect the existing checkpoints before continuing."
    }
    $snapshots[0]
}

$assignedGb = [math]::Round((($vms | Where-Object State -eq 'Running' | Measure-Object MemoryAssigned -Sum).Sum / 1GB), 2)
if ($assignedGb -gt 8) {
    throw "Phase 05 VM memory assignment is $assignedGb GB; expected at most 8 GB for DC01 and CL02."
}

[pscustomobject]@{
    HostName                  = $actualHostName
    IsWindows                 = $isWindowsPlatform
    IsElevated                = $isElevated
    PowerShellEdition         = $PSVersionTable.PSEdition
    PowerShellVersion         = $PSVersionTable.PSVersion.ToString()
    RepositoryRoot            = (Split-Path $PSScriptRoot -Parent)
    RunningVMs                = (($vms | Where-Object State -eq 'Running').Name -join ', ')
    RunningMemoryGB           = $assignedGb
    PrePhase05Checkpoints     = (($requiredSnapshots | ForEach-Object { "$($_.VMName):$($_.Name)" }) -join ', ')
    AutomaticCheckpoints      = 'Disabled on all lab VMs'
    PowerShellDirectAvailable = $true
    Result                    = 'PASS - Windows host boundary is ready for Phase 05'
}

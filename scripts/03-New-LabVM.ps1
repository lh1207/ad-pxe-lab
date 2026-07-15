#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
Creates the configured Generation 2 lab virtual machines and their disks.

.DESCRIPTION
Creates the six VM definitions idempotently from lab.config.psd1. Server children use the
read-only parent VHDX and receive a minimal unattend file. The supplied SecureString password
is converted to plaintext only while the XML is written; use a unique lab-only password.
Scripts stop at base OS installation: network, AD, WDS, and ConfigMgr configuration remain
manual runbook tasks.

.PARAMETER ConfigPath
Path to the lab PowerShell data file.

.PARAMETER LocalAdministratorPassword
SecureString used only for the local Administrator password in each differencing Server-child
unattend file. This value is not stored in the configuration or on disk outside the generated
unattend file; delete that file after each Server child's first boot.

.PARAMETER VMName
One or more configured VM names to create. By default, creates every configured VM.

.EXAMPLE
$password = Read-Host 'Lab-only local Administrator password' -AsSecureString
.\03-New-LabVM.ps1 -LocalAdministratorPassword $password

.EXAMPLE
.\03-New-LabVM.ps1 -VMName (Import-PowerShellDataFile .\lab.config.psd1).VMs.Keys
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'lab.config.psd1'),

    [Parameter()]
    [System.Security.SecureString]$LocalAdministratorPassword,

    [Parameter()]
    [string[]]$VMName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$config = Import-PowerShellDataFile -Path $ConfigPath
$configDirectory = Split-Path -Path (Resolve-Path -LiteralPath $ConfigPath) -Parent
$templatePath = Join-Path -Path $configDirectory -ChildPath $config.Paths.UnattendTemplate

function Get-LabVhdPath {
    param([hashtable]$Specification)
    Join-Path -Path $config.Paths.VhdDir -ChildPath ('{0}.vhdx' -f $Specification.Name)
}

function Set-LabUnattend {
    param([hashtable]$Specification, [string]$VhdPath)
    if (-not $LocalAdministratorPassword) {
        throw "-LocalAdministratorPassword is required before creating Server child '$($Specification.Name)'."
    }
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw "Unattend template was not found: $templatePath"
    }

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($LocalAdministratorPassword)
    $plainPassword = $null
    try {
        $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $xml = Get-Content -LiteralPath $templatePath -Raw
        $xml = $xml.Replace('{{COMPUTERNAME}}', [System.Security.SecurityElement]::Escape($Specification.Name))
        $xml = $xml.Replace('{{ADMIN_PASSWORD}}', [System.Security.SecurityElement]::Escape($plainPassword))
        $xml = $xml.Replace('{{TIMEZONE}}', [System.Security.SecurityElement]::Escape($config.TimeZone))
        Mount-VHD -Path $VhdPath | Out-Null
        try {
            $volume = Get-DiskImage -ImagePath $VhdPath | Get-Disk | Get-Partition |
                Get-Volume | Where-Object { $_.FileSystem -eq 'NTFS' } | Select-Object -First 1
            if (-not $volume -or -not $volume.DriveLetter) { throw "Could not locate the Windows volume in $VhdPath." }
            $pantherPath = Join-Path -Path ('{0}:\Windows' -f $volume.DriveLetter) -ChildPath 'Panther'
            New-Item -ItemType Directory -Path $pantherPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path -Path $pantherPath -ChildPath 'unattend.xml') -Value $xml -Encoding UTF8 -Force
        } finally {
            Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
        }
    } finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        Remove-Variable -Name plainPassword -ErrorAction SilentlyContinue
    }
}

function Set-LabBootDevice {
    param([hashtable]$Specification, [string]$VhdPath)
    switch ($Specification.BootDevice) {
        'VHD' {
            $device = Get-VMHardDiskDrive -VMName $Specification.Name | Where-Object { $_.Path -eq $VhdPath } | Select-Object -First 1
        }
        'Network' {
            $device = Get-VMNetworkAdapter -VMName $Specification.Name | Select-Object -First 1
        }
        'DVD' {
            $dvd = Get-VMDvdDrive -VMName $Specification.Name -ErrorAction SilentlyContinue
            if (-not $dvd) {
                $isoPath = Join-Path -Path $config.Paths.IsoDir -ChildPath $config.Paths.IsoFiles.Win11
                if (-not (Test-Path -LiteralPath $isoPath -PathType Leaf)) { throw "Configured client ISO was not found: $isoPath" }
                Add-VMDvdDrive -VMName $Specification.Name -Path $isoPath | Out-Null
            }
            $device = Get-VMDvdDrive -VMName $Specification.Name | Select-Object -First 1
        }
        default { throw "Unsupported BootDevice '$($Specification.BootDevice)' for $($Specification.Name)." }
    }
    if (-not $device) { throw "Could not resolve the $($Specification.BootDevice) boot device for $($Specification.Name)." }
    Set-VMFirmware -VMName $Specification.Name -FirstBootDevice $device
}

if (-not $VMName) { $VMName = @($config.VMs.Keys) }
New-Item -ItemType Directory -Path $config.Paths.VhdDir -Force | Out-Null
foreach ($requestedName in $VMName) {
    if (-not $config.VMs.ContainsKey($requestedName)) { throw "'$requestedName' is not a VM in $ConfigPath." }
    $specification = $config.VMs[$requestedName]
    $vhdPath = Get-LabVhdPath -Specification $specification
    $existingVm = Get-VM -Name $specification.Name -ErrorAction SilentlyContinue

    if ($existingVm) {
        if (-not (Test-Path -LiteralPath $vhdPath -PathType Leaf)) {
            throw "The existing VM '$($specification.Name)' does not have its configured disk at $vhdPath. Resolve the conflict manually."
        }
        Write-Verbose "VM already exists; no changes made: $($specification.Name)"
        continue
    }

    if (-not (Test-Path -LiteralPath $vhdPath -PathType Leaf)) {
        if (-not $PSCmdlet.ShouldProcess($vhdPath, "Create $($specification.DiskType) VHDX")) { continue }
        switch ($specification.DiskType) {
            'Differencing' {
                if (-not (Test-Path -LiteralPath $config.Paths.ParentVhdx -PathType Leaf)) { throw "Parent VHDX was not found: $($config.Paths.ParentVhdx)" }
                New-VHD -Path $vhdPath -ParentPath $config.Paths.ParentVhdx | Out-Null
                Set-LabUnattend -Specification $specification -VhdPath $vhdPath
            }
            'Fixed' { New-VHD -Path $vhdPath -Fixed -SizeBytes ($specification.DiskGB * 1GB) | Out-Null }
            'Dynamic' { New-VHD -Path $vhdPath -Dynamic -SizeBytes ($specification.DiskGB * 1GB) | Out-Null }
            default { throw "Unsupported DiskType '$($specification.DiskType)' for $($specification.Name)." }
        }
    }

    if (-not $PSCmdlet.ShouldProcess($specification.Name, 'Create Generation 2 VM')) { continue }
    New-VM -Name $specification.Name -Generation 2 -MemoryStartupBytes ($specification.MemoryGB * 1GB) -VHDPath $vhdPath -SwitchName $specification.SwitchName | Out-Null
    Set-VMProcessor -VMName $specification.Name -Count $specification.CPU
    if ($specification.MemoryType -eq 'Dynamic') {
        Set-VMMemory -VMName $specification.Name -DynamicMemoryEnabled $true -StartupBytes ($specification.MemoryGB * 1GB) -MinimumBytes ($specification.MemoryMinimumGB * 1GB) -MaximumBytes ($specification.MemoryMaximumGB * 1GB)
    } elseif ($specification.MemoryType -eq 'Static') {
        Set-VMMemory -VMName $specification.Name -DynamicMemoryEnabled $false -StartupBytes ($specification.MemoryGB * 1GB)
    } else {
        throw "Unsupported MemoryType '$($specification.MemoryType)' for $($specification.Name)."
    }
    Set-VMFirmware -VMName $specification.Name -EnableSecureBoot On -SecureBootTemplate $config.HostRequirements.SecureBootTemplate
    Set-LabBootDevice -Specification $specification -VhdPath $vhdPath
}

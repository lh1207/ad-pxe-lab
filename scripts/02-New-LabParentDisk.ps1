#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
Builds the read-only Windows Server parent VHDX directly from the configured evaluation ISO.

.DESCRIPTION
Lists the ISO editions, applies the configured Server Desktop Experience image to a GPT VHDX,
creates UEFI boot files, and marks the completed parent read-only. The parent is never booted.

.PARAMETER ConfigPath
Path to the lab PowerShell data file.

.EXAMPLE
.\02-New-LabParentDisk.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'lab.config.psd1')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$config = Import-PowerShellDataFile -Path $ConfigPath
$parentPath = $config.Paths.ParentVhdx
$isoPath = Join-Path -Path $config.Paths.IsoDir -ChildPath $config.Paths.IsoFiles.WS2025

if (Test-Path -LiteralPath $parentPath -PathType Leaf) {
    Write-Verbose "Parent disk already exists: $parentPath"
    return
}
if (-not (Test-Path -LiteralPath $isoPath -PathType Leaf)) {
    throw "Configured Server ISO was not found: $isoPath"
}

New-Item -ItemType Directory -Path (Split-Path -Path $parentPath -Parent) -Force | Out-Null
$mountedIso = $false
$mountedVhd = $false
try {
    Mount-DiskImage -ImagePath $isoPath -StorageType ISO | Out-Null
    $mountedIso = $true
    $isoVolume = Get-DiskImage -ImagePath $isoPath | Get-Volume
    $installWim = Join-Path -Path ("{0}:" -f $isoVolume.DriveLetter) -ChildPath 'sources\install.wim'
    if (-not (Test-Path -LiteralPath $installWim)) {
        throw "The configured ISO does not contain sources\\install.wim: $isoPath"
    }

    $images = Get-WindowsImage -ImagePath $installWim
    $images | Select-Object ImageIndex, ImageName, EditionId | Format-Table -AutoSize
    $image = $images | Where-Object { $_.ImageName -eq $config.ParentDisk.ImageName } | Select-Object -First 1
    if (-not $image) {
        throw "The configured parent image '$($config.ParentDisk.ImageName)' was not found in the ISO."
    }

    if (-not $PSCmdlet.ShouldProcess($parentPath, 'Create and apply read-only parent VHDX')) { return }
    New-VHD -Path $parentPath -Dynamic -SizeBytes ($config.ParentDisk.SizeGB * 1GB) | Out-Null
    Mount-VHD -Path $parentPath | Out-Null
    $mountedVhd = $true
    $disk = Get-DiskImage -ImagePath $parentPath | Get-Disk
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT | Out-Null
    $efi = New-Partition -DiskNumber $disk.Number -Size ($config.ParentDisk.EfiPartitionMB * 1MB) `
        -AssignDriveLetter -GptType '{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}'
    Format-Volume -Partition $efi -FileSystem FAT32 -NewFileSystemLabel 'SYSTEM' -Confirm:$false | Out-Null
    New-Partition -DiskNumber $disk.Number -Size ($config.ParentDisk.MsrPartitionMB * 1MB) -GptType '{E3C9E316-0B5C-4DB8-817D-F92DF00215AE}' | Out-Null
    $os = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
    Format-Volume -Partition $os -FileSystem NTFS -NewFileSystemLabel 'Windows' -Confirm:$false | Out-Null
    $osRoot = '{0}:\' -f $os.DriveLetter
    Expand-WindowsImage -ImagePath $installWim -Index $image.ImageIndex -ApplyPath $osRoot | Out-Null
    & bcdboot (Join-Path -Path $osRoot -ChildPath 'Windows') /s ('{0}:' -f $efi.DriveLetter) /f UEFI
    if ($LASTEXITCODE -ne 0) { throw "bcdboot failed with exit code $LASTEXITCODE." }
} finally {
    if ($mountedVhd) { Dismount-VHD -Path $parentPath -ErrorAction SilentlyContinue }
    if ($mountedIso) { Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue }
}

(Get-Item -LiteralPath $parentPath).IsReadOnly = $true
Write-Verbose "Created read-only parent disk: $parentPath"

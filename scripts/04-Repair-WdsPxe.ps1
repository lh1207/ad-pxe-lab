[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$outputPath = 'C:\tmp\phase04-wds-pxe-repair.txt'
$donePath = 'C:\tmp\phase04-wds-pxe-repair.done'
$failedPath = 'C:\tmp\phase04-wds-pxe-repair.failed'

Remove-Item -LiteralPath $donePath, $failedPath -Force -ErrorAction SilentlyContinue
Start-Transcript -Path $outputPath -Force

try {
    $credential = Get-Credential -UserName 'HUFFLAB\Administrator' -Message 'Enter the HUFFLAB domain Administrator password.'

    $repairResult = Invoke-Command -VMName 'WDS01' -Credential $credential -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $remoteInstall = 'D:\RemoteInstall'
        $imageDirectory = Join-Path $remoteInstall 'Boot\x64\Images'
        $bootImages = @(Get-WdsBootImage | Where-Object { $_.Architecture -eq 'X64' -and $_.Enabled })
        $wimFiles = @(Get-ChildItem -LiteralPath $imageDirectory -Filter '*.wim' -File)

        if ($bootImages.Count -ne 1) {
            throw "Expected one enabled x64 WDS boot image; found $($bootImages.Count)."
        }
        if ($wimFiles.Count -ne 1) {
            throw "Expected one x64 WIM in $imageDirectory; found $($wimFiles.Count)."
        }

        $relativeBootImage = 'Boot\x64\Images\' + $wimFiles[0].Name
        & wdsutil.exe /Set-Server "/BootImage:$relativeBootImage" /Architecture:x64
        if ($LASTEXITCODE -ne 0) {
            throw "wdsutil Set-Server BootImage failed with exit code $LASTEXITCODE."
        }

        & wdsutil.exe /Set-Server /BcdRefreshPolicy /Enabled:Yes /RefreshPeriod:1
        if ($LASTEXITCODE -ne 0) {
            throw "wdsutil BCD refresh policy failed with exit code $LASTEXITCODE."
        }

        & wdsutil.exe /Set-TransportServer /EnableTftpVariableWindowExtension:No
        if ($LASTEXITCODE -ne 0) {
            throw "wdsutil TFTP variable-window update failed with exit code $LASTEXITCODE."
        }

        $roleBootDirectory = 'C:\Windows\System32\RemInst\boot\x64'
        $wdsBootDirectory = Join-Path $remoteInstall 'Boot\x64'
        foreach ($name in 'bootmgfw.efi', 'bootmgr.exe', 'wdsmgfw.efi') {
            $source = Join-Path $roleBootDirectory $name
            $destination = Join-Path $wdsBootDirectory $name
            if (-not (Test-Path -LiteralPath $source)) {
                throw "The WDS role boot file is missing: $source"
            }
            if ($name -like '*.efi' -and
                (Get-AuthenticodeSignature -LiteralPath $source).Status -ne 'Valid') {
                throw "The Microsoft signature is not valid on $source."
            }
            if ((Test-Path -LiteralPath $destination) -and
                -not (Test-Path -LiteralPath "$destination.pre-phase04-repair.bak")) {
                Copy-Item -LiteralPath $destination `
                    -Destination "$destination.pre-phase04-repair.bak"
            }
            Copy-Item -LiteralPath $source -Destination $destination -Force
            if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
                (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash) {
                throw "Hash mismatch after copying $name."
            }
        }

        & wdsutil.exe /Set-Server /BootProgram:Boot\x64\wdsmgfw.efi /Architecture:x64uefi
        if ($LASTEXITCODE -ne 0) {
            throw "The x64 UEFI prompt boot-program update failed with exit code $LASTEXITCODE."
        }
        & wdsutil.exe /Set-Server /N12BootProgram:Boot\x64\bootmgfw.efi /Architecture:x64uefi
        if ($LASTEXITCODE -ne 0) {
            throw "The x64 UEFI N12 boot-program update failed with exit code $LASTEXITCODE."
        }

        $ramdiskOptionsId = '{68d9e51c-a129-4ee1-9725-2ab00a957daf}'
        $bcdStores = @(
            (Join-Path $wdsBootDirectory 'default.bcd'),
            (Join-Path $imageDirectory 'boot.wim.bcd')
        )
        foreach ($store in $bcdStores) {
            if (-not (Test-Path -LiteralPath $store)) {
                throw "The WDS BCD store is missing: $store"
            }
            if (-not (Test-Path -LiteralPath "$store.pre-phase04-repair.bak")) {
                Copy-Item -LiteralPath $store -Destination "$store.pre-phase04-repair.bak"
            }
            & bcdedit.exe /store $store /set $ramdiskOptionsId ramdisktftpvarwindow No
            if ($LASTEXITCODE -ne 0) {
                throw "BCD variable-window update failed for $store with exit code $LASTEXITCODE."
            }
        }

        wevtutil.exe sl 'Microsoft-Windows-Deployment-Services-Diagnostics/Operational' /e:true
        Restart-Service -Name 'WDSServer'
        Start-Sleep -Seconds 5

        [pscustomobject]@{
            ImageName = $bootImages[0].ImageName
            WimPath = $wimFiles[0].FullName
            RelativeBootImage = $relativeBootImage
            WdsService = (Get-Service -Name 'WDSServer').Status
            UefiBootProgram = 'Boot\x64\wdsmgfw.efi'
            UefiN12BootProgram = 'Boot\x64\bootmgfw.efi'
            TftpVariableWindowExtension = 'Disabled'
        }
        & wdsutil.exe /Get-Server /Show:Config
    }

    $repairResult
    $retryStart = Get-Date
    if ((Get-VM -Name 'CL02').State -ne 'Off') {
        Stop-VM -Name 'CL02' -Force -TurnOff
    }
    Start-VM -Name 'CL02' | Out-Null
    Start-Sleep -Seconds 30

    Invoke-Command -VMName 'WDS01' -Credential $credential -ScriptBlock {
        param([datetime]$StartTime)
        $logs = @(
            'Microsoft-Windows-Deployment-Services-Diagnostics/Operational',
            'Microsoft-Windows-Deployment-Services-Server/Operational'
        )
        foreach ($log in $logs) {
            "--- $log ---"
            Get-WinEvent -FilterHashtable @{ LogName = $log; StartTime = $StartTime } -ErrorAction SilentlyContinue |
                Select-Object TimeCreated, Id, LevelDisplayName, Message |
                Format-List
        }
    } -ArgumentList $retryStart

    Set-Content -LiteralPath $donePath -Value (Get-Date -Format o)
}
catch {
    Set-Content -LiteralPath $failedPath -Value ($_ | Out-String)
    throw
}
finally {
    Stop-Transcript
}

[CmdletBinding()]
param([System.Management.Automation.PSCredential]$Credential)

# Operator-attended Phase 05 post-GUI verifier. It applies computer policy on CL02,
# but does not create, modify, unlink, or delete any directory or GPO configuration.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location 'C:\HyperV\ad-pxe-lab'

$sessionRoot = 'C:\HyperV\ad-pxe-lab\docs\phase-05-session'
New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$logPath = Join-Path $sessionRoot "gpo-configuration-$stamp.txt"
$statusPath = Join-Path $sessionRoot "gpo-configuration-$stamp-status.txt"
if ((Test-Path -LiteralPath $logPath) -or (Test-Path -LiteralPath $statusPath)) {
    throw 'Timestamp collision; refusing to overwrite a session record.'
}

function Write-Stage {
    param([Parameter(Mandatory)][string]$Text)
    $Text | Tee-Object -FilePath $logPath -Append | Write-Host
}

function Invoke-HostPreflight {
    Write-Stage 'STAGE HOST_PREFLIGHT'
    & '.\scripts\05-Test-Phase05Environment.ps1' 2>&1 |
        Tee-Object -FilePath $logPath -Append | Out-Host
}

$domainAdmin = $null
$dc = $null
$cl = $null
$remoteEvidencePath = $null
$hostEvidencePath = Join-Path $sessionRoot "gpo-configuration-backup-$stamp"
$hostComputerGpResult = Join-Path $sessionRoot "CL02-computer-gpresult-$stamp.xml"

try {
    'STARTING' | Set-Content -LiteralPath $statusPath
    Invoke-HostPreflight

    Write-Stage 'STAGE CREDENTIAL_PROMPT'
    $domainAdmin = $Credential
    if ($null -eq $domainAdmin) {
        $domainAdmin = Get-Credential -UserName 'HUFFLAB\Administrator' -Message 'Phase 05 configuration verification. Password remains in memory only.'
    }
    if ($null -eq $domainAdmin) {
        throw 'Credential prompt canceled.'
    }

    Write-Stage 'STAGE OPEN_DC01_SESSION'
    $dc = New-PSSession -VMName DC01 -Credential $domainAdmin -ErrorAction Stop
    Write-Stage 'STAGE OPEN_CL02_SESSION'
    $cl = New-PSSession -VMName CL02 -Credential $domainAdmin -ErrorAction Stop

    Write-Stage 'STAGE DC01_CONFIGURATION_ASSERTIONS'
    $configuration = @(Invoke-Command -Session $dc -ScriptBlock {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        function Get-InfSection {
            param(
                [Parameter(Mandatory)][string]$Path,
                [Parameter(Mandatory)][string]$Section
            )
            if (-not (Test-Path -LiteralPath $Path)) {
                throw "Required security template is absent: $Path"
            }
            $values = @{}
            $inSection = $false
            foreach ($line in Get-Content -LiteralPath $Path -Encoding Unicode) {
                $trimmed = $line.Trim()
                if ($trimmed -match '^\[(.+)\]$') {
                    $inSection = ($matches[1] -ieq $Section)
                    continue
                }
                if ($inSection -and $trimmed -and -not $trimmed.StartsWith(';') -and $trimmed -match '^([^=]+)=(.*)$') {
                    $values[$matches[1].Trim()] = $matches[2].Trim()
                }
            }
            if ($values.Count -eq 0) {
                throw "Security template section [$Section] is absent or empty: $Path"
            }
            return $values
        }

        function Get-InfRegistryValue {
            param(
                [Parameter(Mandatory)][hashtable]$Values,
                [Parameter(Mandatory)][string]$Name
            )
            if (-not $Values.ContainsKey($Name)) {
                throw "Security template registry entry is absent: $Name"
            }
            $raw = [string]$Values[$Name]
            if ($raw -notmatch '^(?<Type>\d+)\s*,\s*(?<Data>.*)$') {
                throw "Security template registry entry has unexpected format: $Name=$raw"
            }
            $data = $matches['Data'].Trim()
            if ($data.Length -ge 2 -and $data.StartsWith('"') -and $data.EndsWith('"')) {
                $data = $data.Substring(1, $data.Length - 2)
            }
            [pscustomobject]@{
                Type = [int]$matches['Type']
                Data = $data
            }
        }

        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'DC01 administrator token required.'
        }
        Import-Module ActiveDirectory
        Import-Module GroupPolicy

        $domain = Get-ADDomain
        if ($domain.DNSRoot -ine 'hufflab.internal') {
            throw 'Domain mismatch.'
        }
        if (@(Get-Service NTDS,DNS,Netlogon | Where-Object Status -ne 'Running').Count) {
            throw 'Required DC service stopped.'
        }

        $expectedGpos = @{
            'Default Domain Policy' = '31b2f340-016d-11d2-945f-00c04fb984f9'
            'Default Domain Controllers Policy' = '6ac1786c-016f-11d2-945f-00c04fb984f9'
            'GPO-C-Workstation-Baseline' = $null
            'GPO-U-IT-DriveMaps' = $null
        }
        $allGpos = @(Get-GPO -All)
        if ($allGpos.Count -ne 4 -or @($allGpos | Where-Object { -not $expectedGpos.ContainsKey($_.DisplayName) -or $_.GpoStatus.ToString() -ne 'AllSettingsEnabled' }).Count) {
            throw 'GPO inventory is not exactly the four enabled Phase 05 GPOs.'
        }
        foreach ($name in $expectedGpos.Keys) {
            if (@($allGpos | Where-Object DisplayName -eq $name).Count -ne 1) {
                throw "Expected GPO is missing or duplicated: $name"
            }
        }
        foreach ($name in @('Default Domain Policy','Default Domain Controllers Policy')) {
            $actualId = (@($allGpos | Where-Object DisplayName -eq $name)[0]).Id.Guid.ToString().ToLowerInvariant()
            if ($actualId -ne $expectedGpos[$name]) {
                throw "Built-in GPO GUID mismatch: $name"
            }
        }
        $ddp = @($allGpos | Where-Object DisplayName -eq 'Default Domain Policy')[0]
        $baseline = @($allGpos | Where-Object DisplayName -eq 'GPO-C-Workstation-Baseline')[0]
        $driveMaps = @($allGpos | Where-Object DisplayName -eq 'GPO-U-IT-DriveMaps')[0]

        $workstationsDn = 'OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal'
        $usersDn = 'OU=Users,OU=HUFFLAB,DC=hufflab,DC=internal'
        foreach ($linkCheck in @(
            [pscustomobject]@{ Target = $workstationsDn; ExpectedId = $baseline.Id; Label = 'Workstations' },
            [pscustomobject]@{ Target = $usersDn; ExpectedId = $driveMaps.Id; Label = 'Users' }
        )) {
            $inheritance = Get-GPInheritance -Target $linkCheck.Target
            $links = @($inheritance.GpoLinks)
            if (([string]$inheritance.GpoInheritanceBlocked -notin @('No','False')) -or $links.Count -ne 1) {
                throw "$($linkCheck.Label) OU must have exactly one direct link and unblocked inheritance."
            }
            $link = $links[0]
            if ($link.GpoId -ne $linkCheck.ExpectedId -or ([string]$link.Enabled -notin @('Yes','True')) -or ([string]$link.Enforced -notin @('No','False'))) {
                throw "$($linkCheck.Label) OU link does not match the required enabled, non-enforced Phase 05 GPO."
            }
        }

        $cl02 = Get-ADComputer CL02
        if ($cl02.DistinguishedName -ine 'CN=CL02,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal') {
            throw 'CL02 OU mismatch.'
        }
        $hrMembers = @(Get-ADGroupMember RG-HR-Staff -Recursive | Select-Object -ExpandProperty SamAccountName)
        $agMembers = @(Get-ADGroupMember AG-Share-HR-Modify -Recursive | Select-Object -ExpandProperty SamAccountName)
        if ('hr.jones' -notin $hrMembers -or 'hr.jones' -notin $agMembers) {
            throw 'HR role or AGDLP membership chain mismatch.'
        }

        $ddpTemplate = Join-Path $env:windir ("SYSVOL\domain\Policies\{$($ddp.Id.Guid)}\Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf")
        $ddpSystemAccess = Get-InfSection -Path $ddpTemplate -Section 'System Access'
        $expectedDdpTemplate = @{
            MinimumPasswordLength = '14'
            PasswordComplexity = '1'
            PasswordHistorySize = '24'
            MaximumPasswordAge = '90'
        }
        foreach ($name in $expectedDdpTemplate.Keys) {
            if (-not $ddpSystemAccess.ContainsKey($name) -or [string]$ddpSystemAccess[$name] -ne $expectedDdpTemplate[$name]) {
                throw "Default Domain Policy security template mismatch: $name"
            }
        }
        $defaultPolicy = Get-ADDefaultDomainPasswordPolicy
        if ($defaultPolicy.MinPasswordLength -ne 14 -or -not $defaultPolicy.ComplexityEnabled -or $defaultPolicy.PasswordHistoryCount -ne 24 -or $defaultPolicy.MaxPasswordAge -ne (New-TimeSpan -Days 90)) {
            throw 'Default domain password policy has not refreshed to the GPMC values. Save the Default Domain Policy settings, run gpupdate /force on DC01, then rerun this verifier.'
        }
        'Default Domain Policy saved settings and effective password policy: PASS'

        $psoAll = @(Get-ADFineGrainedPasswordPolicy -Filter * -Properties *)
        if ($psoAll.Count -ne 1 -or $psoAll[0].Name -ne 'PSO-Admins-Strong') {
            throw 'PSO inventory is not exactly PSO-Admins-Strong.'
        }
        $pso = $psoAll[0]
        if ($pso.Precedence -ne 10 -or $pso.MinPasswordLength -ne 16 -or -not $pso.ComplexityEnabled -or $pso.PasswordHistoryCount -ne 24 -or $pso.MaxPasswordAge -ne (New-TimeSpan -Days 60) -or $pso.MinPasswordAge -ne (New-TimeSpan -Days 1) -or $pso.LockoutThreshold -ne 5 -or $pso.LockoutDuration -ne (New-TimeSpan -Minutes 10) -or $pso.LockoutObservationWindow -ne (New-TimeSpan -Minutes 10) -or $pso.ReversibleEncryptionEnabled -or -not $pso.ProtectedFromAccidentalDeletion) {
            throw 'PSO-Admins-Strong properties do not match the fixed Phase 05 values.'
        }
        $adm = Get-ADUser adm-lhuff
        if (-not $adm.Enabled) {
            throw 'adm-lhuff must be enabled.'
        }
        $rawSubjects = if ($pso.PSObject.Properties.Name -contains 'AppliesTo') { @($pso.AppliesTo) } else { @($pso.'msDS-PSOAppliesTo') }
        $subjectDns = @($rawSubjects | ForEach-Object {
            if ($_ -is [string]) { $_ }
            elseif ($null -ne $_.DistinguishedName) { [string]$_.DistinguishedName }
            else { [string]$_ }
        })
        if ($subjectDns.Count -ne 1 -or $subjectDns[0] -ine $adm.DistinguishedName) {
            throw 'PSO-Admins-Strong must directly apply only to adm-lhuff.'
        }
        $resultant = Get-ADUserResultantPasswordPolicy -Identity adm-lhuff -ErrorAction Stop
        if ($resultant.Name -ne 'PSO-Admins-Strong' -or $resultant.MinPasswordLength -ne 16 -or $resultant.LockoutThreshold -ne 5) {
            throw 'adm-lhuff resultant PSO mismatch.'
        }
        'Administrator PSO and resultant policy: PASS'

        $baselineTemplate = Join-Path $env:windir ("SYSVOL\domain\Policies\{$($baseline.Id.Guid)}\Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf")
        if (-not (Test-Path -LiteralPath $baselineTemplate)) {
            throw "GPO-C-Workstation-Baseline ($($baseline.Id)) has no Security Options template. In GPMC edit this GPO and save the approved logon title/text and 900-second machine inactivity limit under Computer Configuration > Policies > Windows Settings > Security Settings > Local Policies > Security Options. Do not create GptTmpl.inf manually. Missing path: $baselineTemplate"
        }
        $baselineRegistry = Get-InfSection -Path $baselineTemplate -Section 'Registry Values'
        $caption = Get-InfRegistryValue -Values $baselineRegistry -Name 'MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System\LegalNoticeCaption'
        $text = Get-InfRegistryValue -Values $baselineRegistry -Name 'MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System\LegalNoticeText'
        $inactivity = Get-InfRegistryValue -Values $baselineRegistry -Name 'MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System\InactivityTimeoutSecs'
        $acceptedCaptions = @('HUFFLAB - Authorized Lab Use', ('HUFFLAB ' + [char]0x2014 + ' Authorized Lab Use'))
        $expectedText = 'This system is for authorized HUFFLAB training and administration only. Activity may be monitored.'
        if ($caption.Type -ne 1 -or $caption.Data -cnotin $acceptedCaptions -or $text.Type -notin @(1,7) -or $text.Data -ne $expectedText -or $inactivity.Type -ne 4 -or $inactivity.Data -ne '900') {
            throw 'Workstation baseline security template registry values do not match the approved banner or inactivity limit.'
        }
        $denyAll = Get-GPRegistryValue -Guid $baseline.Id -Key 'HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices' -ValueName 'Deny_All' -ErrorAction Stop
        if ($denyAll.PolicyState.ToString() -ne 'Set' -or $denyAll.Type.ToString() -ne 'DWord' -or $denyAll.Value -ne 1) {
            throw 'Workstation baseline Deny_All policy must be DWORD 1.'
        }

        $drivesPath = Join-Path $env:windir ("SYSVOL\domain\Policies\{$($driveMaps.Id.Guid)}\User\Preferences\Drives\Drives.xml")
        if (-not (Test-Path -LiteralPath $drivesPath)) {
            throw "Drive Maps preferences file is absent: $drivesPath"
        }
        $drivesXml = New-Object System.Xml.XmlDocument
        $drivesXml.Load($drivesPath)
        $driveNodes = @($drivesXml.SelectNodes('/Drives/Drive'))
        $hNodes = @($driveNodes | Where-Object {
            $propertiesNode = $_.SelectSingleNode('./Properties')
            $null -ne $propertiesNode -and (($propertiesNode.GetAttribute('letter') -ieq 'H') -or ($_.GetAttribute('name') -ieq 'H'))
        })
        if ($hNodes.Count -ne 1) {
            throw 'Drive Maps must contain exactly one H: item, including disabled duplicates.'
        }
        [System.Xml.XmlElement]$h = $hNodes[0]
        [System.Xml.XmlElement]$properties = $h.SelectSingleNode('./Properties')
        if ($h.GetAttribute('disabled') -eq '1' -or $properties.GetAttribute('disabled') -eq '1') {
            throw 'H: drive map must be enabled.'
        }
        if ($properties.GetAttribute('action') -cne 'U' -or $properties.GetAttribute('path') -cne '\\DC01\HRShare' -or $properties.GetAttribute('label') -cne 'HRShare' -or $properties.GetAttribute('letter') -cne 'H' -or $properties.GetAttribute('useLetter') -ne '1') {
            throw 'H: drive map properties must be Update, \\DC01\HRShare, HRShare, and H:.'
        }
        $filterNodes = @($h.SelectNodes('./Filters/*'))
        if ($filterNodes.Count -ne 1 -or $filterNodes[0].LocalName -ne 'FilterGroup') {
            throw 'H: drive map must have exactly one simple security-group item-level target.'
        }
        $hrGroup = Get-ADGroup RG-HR-Staff
        [System.Xml.XmlElement]$filter = $filterNodes[0]
        $acceptedFilterNames = @('RG-HR-Staff','HUFFLAB\RG-HR-Staff')
        if ($filter.GetAttribute('name') -notin $acceptedFilterNames -or $filter.GetAttribute('sid') -ine $hrGroup.SID.Value -or $filter.GetAttribute('not') -ne '0' -or $filter.GetAttribute('userContext') -ne '1') {
            throw 'H: drive map item-level targeting must be a positive RG-HR-Staff SID filter in user context.'
        }

        [pscustomobject]@{
            DefaultDomainPolicyId = $ddp.Id.Guid.ToString()
            BaselineGpoId = $baseline.Id.Guid.ToString()
            DriveMapsGpoId = $driveMaps.Id.Guid.ToString()
            Result = 'DC01_CONFIGURATION_ASSERTIONS_PASS'
        }
    } | Tee-Object -FilePath $logPath -Append | Where-Object { $_ -isnot [string] })
    if ($configuration.Count -ne 1 -or $configuration[0].Result -ne 'DC01_CONFIGURATION_ASSERTIONS_PASS') {
        throw 'DC01 did not return exactly one validated GPO inventory result.'
    }
    $configuration[0] | Out-Host

    Write-Stage 'STAGE FINAL_GPO_REPORTS_AND_BACKUPS'
    $remoteEvidencePath = Invoke-Command -Session $dc -ArgumentList $stamp -ScriptBlock {
        param([string]$RunStamp)
        $ErrorActionPreference = 'Stop'
        Import-Module GroupPolicy
        $root = "C:\GPO-Backups\Phase05\post-gui-$RunStamp"
        New-Item -ItemType Directory -Path $root -ErrorAction Stop | Out-Null
        $gpos = @(Get-GPO -All)
        if ($gpos.Count -ne 4) {
            throw 'Final backup requires exactly four GPOs.'
        }
        $manifest = foreach ($gpo in $gpos) {
            $backup = Backup-GPO -Guid $gpo.Id -Path $root -Comment "Phase 05 post-GUI verification backup $RunStamp"
            Get-GPOReport -Guid $gpo.Id -ReportType Xml -Path (Join-Path $root ("{0}.xml" -f $gpo.Id.Guid))
            Get-GPOReport -Guid $gpo.Id -ReportType Html -Path (Join-Path $root ("{0}.html" -f $gpo.Id.Guid))
            [pscustomobject]@{
                DisplayName = $gpo.DisplayName
                Guid = $gpo.Id.Guid.ToString()
                BackupId = $backup.Id.ToString()
                BackupTime = Get-Date -Format o
            }
        }
        $manifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $root 'manifest.json')
        $root
    }
    if ([string]::IsNullOrWhiteSpace($remoteEvidencePath)) {
        throw 'DC01 did not return a final GPO evidence path.'
    }
    New-Item -ItemType Directory -Path $hostEvidencePath -ErrorAction Stop | Out-Null
    # Copy-Item's remote helper reads DirectoryInfo.Length, which does not exist
    # under strict mode. Relax only its transfer session, then restore validation mode.
    Invoke-Command -Session $dc -ScriptBlock { Set-StrictMode -Off } -ErrorAction Stop
    try {
        Copy-Item -FromSession $dc -LiteralPath $remoteEvidencePath -Destination $hostEvidencePath -Recurse -ErrorAction Stop
    } finally {
        Invoke-Command -Session $dc -ScriptBlock { Set-StrictMode -Version Latest } -ErrorAction Stop
    }
    Write-Stage "GPO_EVIDENCE_COPIED $hostEvidencePath"

    Write-Stage 'STAGE CL02_COMPUTER_GPRESULT_EXPORT'
    $clEvidence = Invoke-Command -Session $cl -ArgumentList $stamp -ScriptBlock {
        param([string]$RunStamp)
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'CL02 administrator token required.'
        }
        $computer = Get-CimInstance Win32_ComputerSystem
        if (-not $computer.PartOfDomain -or $computer.Domain -ine 'hufflab.internal' -or -not (Test-ComputerSecureChannel)) {
            throw 'CL02 domain membership or secure channel mismatch.'
        }
        $dns = @(Get-DnsClientServerAddress -AddressFamily IPv4 | ForEach-Object ServerAddresses)
        if ('10.0.100.10' -notin $dns) {
            throw 'CL02 lacks DC01 DNS.'
        }

        & "$env:SystemRoot\System32\gpupdate.exe" /target:computer /force /wait:120 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Computer gpupdate failed with exit code $LASTEXITCODE."
        }
        $gpResultPath = Join-Path $env:TEMP "phase05-computer-gpresult-$RunStamp.xml"
        & "$env:SystemRoot\System32\gpresult.exe" /scope computer /x $gpResultPath /f 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $gpResultPath)) {
            throw "Computer gpresult XML export failed with exit code $LASTEXITCODE."
        }
        [pscustomobject]@{
            GpResultPath = $gpResultPath
            Result = 'CL02_GPRESULT_EXPORTED'
        }
    }
    if ($null -eq $clEvidence -or [string]::IsNullOrWhiteSpace($clEvidence.GpResultPath)) {
        throw 'CL02 did not return a computer gpresult evidence path.'
    }
    Invoke-Command -Session $cl -ScriptBlock { Set-StrictMode -Off } -ErrorAction Stop
    try {
        Copy-Item -FromSession $cl -LiteralPath $clEvidence.GpResultPath -Destination $hostComputerGpResult -ErrorAction Stop
    } finally {
        Invoke-Command -Session $cl -ScriptBlock { Set-StrictMode -Version Latest } -ErrorAction Stop
    }
    $clEvidence | Format-List | Out-String | Tee-Object -FilePath $logPath -Append | Out-Host
    Write-Stage "CL02_COMPUTER_GPRESULT_COPIED $hostComputerGpResult"

    Write-Stage 'STAGE CL02_EFFECTIVE_REGISTRY_ASSERTIONS'
    Invoke-Command -Session $cl -ScriptBlock {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
        $systemPolicy = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LegalNoticeCaption,LegalNoticeText,InactivityTimeoutSecs
        $removablePolicy = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices' -Name Deny_All
        $acceptedCaptions = @('HUFFLAB - Authorized Lab Use', ('HUFFLAB ' + [char]0x2014 + ' Authorized Lab Use'))
        $expectedText = 'This system is for authorized HUFFLAB training and administration only. Activity may be monitored.'
        if ($systemPolicy.LegalNoticeCaption -cnotin $acceptedCaptions -or $systemPolicy.LegalNoticeText -cne $expectedText -or $systemPolicy.InactivityTimeoutSecs -ne 900 -or $removablePolicy.Deny_All -ne 1) {
            throw 'CL02 effective baseline registry values do not match the approved Phase 05 policy.'
        }
        'CL02_EFFECTIVE_REGISTRY_ASSERTIONS_PASS'
    } | Tee-Object -FilePath $logPath -Append | Out-Host

    'CONFIGURATION_AND_REGISTRY_PASS_RSOP_HR_INTERACTIVE_PENDING' | Set-Content -LiteralPath $statusPath
    Write-Stage 'CONFIGURATION_AND_REGISTRY_PASS_RSOP_HR_INTERACTIVE_PENDING'
    Write-Stage 'Remaining required evidence: inspect the copied CL02 RSOP XML to verify applied GPO structure; normal non-elevated HUFFLAB\hr.jones H: test after sign-out/sign-in; interactive logon-banner observation; screenshots required by the runbook. No Phase 06 checkpoint was created.'
    [pscustomobject]@{
        Result = 'CONFIGURATION_AND_REGISTRY_PASS_RSOP_HR_INTERACTIVE_PENDING'
        LogPath = $logPath
        ComputerGpResultPath = $hostComputerGpResult
        HostEvidencePath = $hostEvidencePath
        BaselineGpoId = $configuration[0].BaselineGpoId
        DriveMapsGpoId = $configuration[0].DriveMapsGpoId
    }
}
catch {
    ('FAIL: ' + $_.Exception.Message) | Tee-Object -FilePath $logPath -Append | Out-Host
    'FAIL' | Set-Content -LiteralPath $statusPath
    throw
}
finally {
    if ($dc) { Remove-PSSession -Session $dc -ErrorAction SilentlyContinue }
    if ($cl) { Remove-PSSession -Session $cl -ErrorAction SilentlyContinue }
    Remove-Variable domainAdmin -ErrorAction SilentlyContinue
}

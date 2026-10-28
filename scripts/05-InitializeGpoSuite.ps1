[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location 'C:\HyperV\ad-pxe-lab'
$sessionRoot = 'C:\HyperV\ad-pxe-lab\docs\phase-05-session'
New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$logPath = Join-Path $sessionRoot "gpo-initialize-$stamp.txt"
$statusPath = Join-Path $sessionRoot "gpo-initialize-$stamp-status.txt"
if ((Test-Path $logPath) -or (Test-Path $statusPath)) { throw 'Timestamp collision; refusing to overwrite a session record.' }

function Write-Stage([string]$Text) {
    $Text | Tee-Object -FilePath $logPath -Append | Write-Host
}
function Invoke-HostPreflight {
    Write-Stage 'STAGE HOST_PREFLIGHT'
    & '.\scripts\05-Test-Phase05Environment.ps1' 2>&1 | Tee-Object -FilePath $logPath -Append | Out-Host
}

$dc = $null
$cl = $null
$domainAdmin = $null
$remoteBackupPath = $null
$hostBackupPath = Join-Path $sessionRoot "gpo-backup-$stamp"
try {
    'STARTING' | Set-Content $statusPath
    Invoke-HostPreflight
    Write-Stage 'STAGE CREDENTIAL_PROMPT'
    $domainAdmin = Get-Credential -UserName 'HUFFLAB\Administrator' -Message 'Phase 05 GPO initialization. Password remains in memory only.'
    if ($null -eq $domainAdmin) { throw 'Credential prompt canceled.' }

    Write-Stage 'STAGE OPEN_DC01_SESSION'
    $dc = New-PSSession -VMName DC01 -Credential $domainAdmin -ErrorAction Stop
    Write-Stage 'STAGE OPEN_CL02_SESSION'
    $cl = New-PSSession -VMName CL02 -Credential $domainAdmin -ErrorAction Stop

    Write-Stage 'STAGE READONLY_ASSERTIONS'
    Invoke-Command -Session $dc -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'DC01 administrator token required.' }
        Import-Module ActiveDirectory; Import-Module GroupPolicy
        $domain = Get-ADDomain
        if ($domain.DNSRoot -ine 'hufflab.internal') { throw 'Domain mismatch.' }
        if (@(Get-Service NTDS,DNS,Netlogon | Where-Object Status -ne 'Running').Count) { throw 'Required DC service stopped.' }
        $cl02 = Get-ADComputer CL02
        if ($cl02.DistinguishedName -ine 'CN=CL02,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal') { throw 'CL02 OU mismatch.' }
        foreach ($name in @('hr.jones','adm-lhuff')) { if (-not (Get-ADUser $name -ErrorAction SilentlyContinue)) { throw "Missing user $name." } }
        $hrUser = Get-ADUser hr.jones
        if (-not $hrUser.Enabled -or $hrUser.DistinguishedName -notlike '*,OU=Users,OU=HUFFLAB,DC=hufflab,DC=internal') { throw 'hr.jones must be enabled in the HUFFLAB Users OU.' }
        $hr = @(Get-ADGroupMember RG-HR-Staff -Recursive | Select-Object -ExpandProperty SamAccountName)
        $ag = @(Get-ADGroupMember AG-Share-HR-Modify -Recursive | Select-Object -ExpandProperty SamAccountName)
        if ('hr.jones' -notin $hr -or 'hr.jones' -notin $ag) { throw 'HR AGDLP membership chain mismatch.' }
        $share = Get-SmbShare HRShare
        if ($null -eq $share) { throw 'HRShare missing.' }
        $smbAllow = @(Get-SmbShareAccess HRShare | Where-Object { $_.AccountName -ieq 'HUFFLAB\AG-Share-HR-Modify' -and $_.AccessControlType -eq 'Allow' -and $_.AccessRight -in @('Change','Full') })
        if (-not $smbAllow.Count) { throw 'HRShare SMB ACL must allow Change or Full to HUFFLAB\AG-Share-HR-Modify.' }
        $ntfsAllow = @((Get-Acl -LiteralPath $share.Path).Access | Where-Object { $_.IdentityReference -ieq 'HUFFLAB\AG-Share-HR-Modify' -and $_.AccessControlType -eq 'Allow' -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Modify) -eq [System.Security.AccessControl.FileSystemRights]::Modify) })
        if (-not $ntfsAllow.Count) { throw 'HRShare NTFS ACL must allow Modify to HUFFLAB\AG-Share-HR-Modify.' }
        $expected = @('31b2f340-016d-11d2-945f-00c04fb984f9','6ac1786c-016f-11d2-945f-00c04fb984f9')
        $all = @(Get-GPO -All)
        if ($all.Count -ne 2 -or @($all | Where-Object { $_.Id.Guid.ToString().ToLower() -notin $expected -or $_.GpoStatus.ToString() -ne 'AllSettingsEnabled' }).Count) { throw 'GPO inventory is not exactly the two enabled built-ins.' }
        foreach ($ou in @('Workstations','Users')) {
            $i = Get-GPInheritance -Target "OU=$ou,OU=HUFFLAB,DC=hufflab,DC=internal"
            if (@($i.GpoLinks).Count -ne 0 -or [string]$i.GpoInheritanceBlocked -notin @('No','False')) {
                throw "$ou OU state is unexpected: directLinks=$(@($i.GpoLinks).Count); blocked=$($i.GpoInheritanceBlocked); links=$($i.GpoLinks | Out-String)"
            }
        }
        $pso = @(Get-ADFineGrainedPasswordPolicy -Filter *)
        if ($pso.Count -ne 0) { throw 'Unexpected fine-grained password policy exists.' }
        $adm = Get-ADUser adm-lhuff
        if (-not $adm.Enabled) { throw 'adm-lhuff must be enabled.' }
        if (Get-ADUserResultantPasswordPolicy -Identity adm-lhuff -ErrorAction SilentlyContinue) { throw 'Unexpected resultant PSO for adm-lhuff.' }
        $d = Get-ADDefaultDomainPasswordPolicy
        if ($d.MinPasswordLength -ne 7 -or -not $d.ComplexityEnabled -or $d.PasswordHistoryCount -ne 24 -or $d.MaxPasswordAge -ne (New-TimeSpan -Days 42) -or $d.MinPasswordAge -ne (New-TimeSpan -Days 1) -or $d.LockoutDuration -ne (New-TimeSpan -Minutes 10) -or $d.LockoutObservationWindow -ne (New-TimeSpan -Minutes 10) -or $d.LockoutThreshold -ne 0 -or $d.ReversibleEncryptionEnabled) { throw 'Default domain password policy does not match approved starting values.' }
        'DC01 readonly assertions: PASS'
    } | Tee-Object -FilePath $logPath -Append | Out-Host
    Invoke-Command -Session $cl -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'CL02 administrator token required.' }
        $c = Get-CimInstance Win32_ComputerSystem
        if (-not $c.PartOfDomain -or $c.Domain -ine 'hufflab.internal' -or -not (Test-ComputerSecureChannel)) { throw 'CL02 domain or secure channel mismatch.' }
        $dns = @(Get-DnsClientServerAddress -AddressFamily IPv4 | ForEach-Object ServerAddresses)
        if ('10.0.100.10' -notin $dns) { throw 'CL02 lacks DC01 DNS.' }
        'CL02 readonly assertions: PASS'
    } | Tee-Object -FilePath $logPath -Append | Out-Host

    Write-Stage 'STAGE HOST_PREFLIGHT_BEFORE_MUTATION'
    Invoke-HostPreflight
    Write-Stage 'STAGE BACKUP_AND_REPORTS'
    $remoteBackupPath = Invoke-Command -Session $dc -ArgumentList $stamp -ScriptBlock {
        param($runStamp)
        $ErrorActionPreference = 'Stop'
        Import-Module ActiveDirectory; Import-Module GroupPolicy
        $root = "C:\GPO-Backups\Phase05\$runStamp"
        New-Item -ItemType Directory -Path $root -ErrorAction Stop | Out-Null
        $builtins = @(Get-GPO -All | Where-Object { $_.Id.Guid.ToString().ToLower() -in @('31b2f340-016d-11d2-945f-00c04fb984f9','6ac1786c-016f-11d2-945f-00c04fb984f9') })
        if ($builtins.Count -ne 2) { throw 'Backup requires exactly two built-in GPOs.' }
        $manifest = foreach ($g in $builtins) {
            $b = Backup-GPO -Guid $g.Id -Path $root -Comment "Phase 05 pre-mutation backup $runStamp"
            Get-GPOReport -Guid $g.Id -ReportType Xml -Path (Join-Path $root ("{0}.xml" -f $g.Id.Guid))
            Get-GPOReport -Guid $g.Id -ReportType Html -Path (Join-Path $root ("{0}.html" -f $g.Id.Guid))
            [pscustomobject]@{ DisplayName=$g.DisplayName; GUID=$g.Id.Guid.ToString(); BackupID=$b.Id.ToString(); BackupTime=(Get-Date -Format o) }
        }
        $manifest | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $root 'manifest.json')
        $after = @(Get-GPO -All)
        if ($after.Count -ne 2 -or @($after | Where-Object { $_.Id.Guid.ToString().ToLower() -notin @('31b2f340-016d-11d2-945f-00c04fb984f9','6ac1786c-016f-11d2-945f-00c04fb984f9') -or $_.GpoStatus.ToString() -ne 'AllSettingsEnabled' }).Count) { throw 'GPO inventory changed during backup.' }
        foreach ($ou in @('Workstations','Users')) {
            $i = Get-GPInheritance -Target "OU=$ou,OU=HUFFLAB,DC=hufflab,DC=internal"
            if (@($i.GpoLinks).Count -ne 0 -or [string]$i.GpoInheritanceBlocked -notin @('No','False')) {
                throw "$ou OU changed during backup: directLinks=$(@($i.GpoLinks).Count); blocked=$($i.GpoInheritanceBlocked); links=$($i.GpoLinks | Out-String)"
            }
        }
        $root
    } | Tee-Object -FilePath $logPath -Append | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($remoteBackupPath)) { throw 'Remote backup path was not returned.' }
    New-Item -ItemType Directory -Path $hostBackupPath -ErrorAction Stop | Out-Null
    Copy-Item -FromSession $dc -Path $remoteBackupPath -Destination $hostBackupPath -Recurse -ErrorAction Stop
    Write-Stage "BACKUP_COPIED $hostBackupPath"

    Write-Stage 'STAGE POST_BACKUP_DC_INVENTORY_ASSERTIONS'
    Invoke-Command -Session $dc -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'DC01 administrator token required after backup.' }
        Import-Module ActiveDirectory; Import-Module GroupPolicy
        if ((Get-ADDomain).DNSRoot -ine 'hufflab.internal' -or @(Get-Service NTDS,DNS,Netlogon | Where-Object Status -ne 'Running').Count) { throw 'DC01 domain/services changed after backup.' }
        if ((Get-ADComputer CL02).DistinguishedName -ine 'CN=CL02,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal') { throw 'CL02 OU changed after backup.' }
        $hrUser = Get-ADUser hr.jones
        if (-not $hrUser.Enabled -or $hrUser.DistinguishedName -notlike '*,OU=Users,OU=HUFFLAB,DC=hufflab,DC=internal') { throw 'hr.jones changed after backup.' }
        if ('hr.jones' -notin @(Get-ADGroupMember RG-HR-Staff -Recursive | Select-Object -ExpandProperty SamAccountName) -or 'hr.jones' -notin @(Get-ADGroupMember AG-Share-HR-Modify -Recursive | Select-Object -ExpandProperty SamAccountName)) { throw 'HR membership changed after backup.' }
        $share = Get-SmbShare HRShare
        $smbAllow = @(Get-SmbShareAccess HRShare | Where-Object { $_.AccountName -ieq 'HUFFLAB\AG-Share-HR-Modify' -and $_.AccessControlType -eq 'Allow' -and $_.AccessRight -in @('Change','Full') })
        $ntfsAllow = @((Get-Acl -LiteralPath $share.Path).Access | Where-Object { $_.IdentityReference -ieq 'HUFFLAB\AG-Share-HR-Modify' -and $_.AccessControlType -eq 'Allow' -and (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Modify) -eq [System.Security.AccessControl.FileSystemRights]::Modify) })
        if (-not $smbAllow.Count -or -not $ntfsAllow.Count) { throw 'HR share ACL changed after backup.' }
        $expected = @('31b2f340-016d-11d2-945f-00c04fb984f9','6ac1786c-016f-11d2-945f-00c04fb984f9')
        $all = @(Get-GPO -All)
        if ($all.Count -ne 2 -or @($all | Where-Object { $_.Id.Guid.ToString().ToLower() -notin $expected -or $_.GpoStatus.ToString() -ne 'AllSettingsEnabled' }).Count) { throw 'GPO inventory changed after backup.' }
        foreach ($ou in @('Workstations','Users')) {
            $i = Get-GPInheritance -Target "OU=$ou,OU=HUFFLAB,DC=hufflab,DC=internal"
            if (@($i.GpoLinks).Count -ne 0 -or [string]$i.GpoInheritanceBlocked -notin @('No','False')) {
                throw "$ou OU changed after backup: directLinks=$(@($i.GpoLinks).Count); blocked=$($i.GpoInheritanceBlocked); links=$($i.GpoLinks | Out-String)"
            }
        }
        if (@(Get-ADFineGrainedPasswordPolicy -Filter *).Count -ne 0 -or (Get-ADUserResultantPasswordPolicy -Identity adm-lhuff -ErrorAction SilentlyContinue)) { throw 'PSO inventory changed after backup.' }
        $adm = Get-ADUser adm-lhuff
        if (-not $adm.Enabled) { throw 'adm-lhuff disabled after backup.' }
        $d = Get-ADDefaultDomainPasswordPolicy
        if ($d.MinPasswordLength -ne 7 -or -not $d.ComplexityEnabled -or $d.PasswordHistoryCount -ne 24 -or $d.MaxPasswordAge -ne (New-TimeSpan -Days 42) -or $d.MinPasswordAge -ne (New-TimeSpan -Days 1) -or $d.LockoutDuration -ne (New-TimeSpan -Minutes 10) -or $d.LockoutObservationWindow -ne (New-TimeSpan -Minutes 10) -or $d.LockoutThreshold -ne 0 -or $d.ReversibleEncryptionEnabled) { throw 'Default policy changed after backup.' }
        'DC01 post-backup inventory assertions: PASS'
    } | Tee-Object -FilePath $logPath -Append | Out-Host

    Write-Stage 'STAGE HOST_PREFLIGHT_IMMEDIATE_BEFORE_MUTATION'
    Invoke-HostPreflight
    Write-Stage 'STAGE REMOTE_MUTATIONS'
    Invoke-Command -Session $dc -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        Import-Module ActiveDirectory; Import-Module GroupPolicy
        Write-Output 'STAGE CREATE_PSO'
        $pso = New-ADFineGrainedPasswordPolicy -Name 'PSO-Admins-Strong' -Precedence 10 -MinPasswordLength 16 -ComplexityEnabled $true -PasswordHistoryCount 24 -MaxPasswordAge (New-TimeSpan -Days 60) -MinPasswordAge (New-TimeSpan -Days 1) -LockoutThreshold 5 -LockoutDuration (New-TimeSpan -Minutes 10) -LockoutObservationWindow (New-TimeSpan -Minutes 10) -ReversibleEncryptionEnabled $false -ProtectedFromAccidentalDeletion $true -PassThru
        $adm = Get-ADUser adm-lhuff
        Add-ADFineGrainedPasswordPolicySubject -Identity $pso -Subjects $adm
        Write-Output 'STAGE CREATE_GPOS'
        $computer = New-GPO -Name 'GPO-C-Workstation-Baseline' -Comment 'Phase 05 GUI_REQUIRED: removable storage deny, approved logon banner, 900 second inactivity limit.'
        $user = New-GPO -Name 'GPO-U-IT-DriveMaps' -Comment 'Phase 05 GUI_REQUIRED: H: \\DC01\HRShare, Update, item-level target RG-HR-Staff.'
        New-GPLink -Guid $computer.Id -Target 'OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal' -LinkEnabled Yes -Enforced No | Out-Null
        New-GPLink -Guid $user.Id -Target 'OU=Users,OU=HUFFLAB,DC=hufflab,DC=internal' -LinkEnabled Yes -Enforced No | Out-Null
        Write-Output 'GUI_REQUIRED: edit Default Domain Policy password settings; edit three workstation baseline settings; edit HR drive map and RG-HR-Staff targeting.'
        $result = Get-ADUserResultantPasswordPolicy -Identity adm-lhuff
        $psoCheck = Get-ADFineGrainedPasswordPolicy -Identity 'PSO-Admins-Strong' -Properties ProtectedFromAccidentalDeletion
        if ($psoCheck.Precedence -ne 10 -or -not $psoCheck.ProtectedFromAccidentalDeletion -or $result.Name -ne 'PSO-Admins-Strong' -or $result.MinPasswordLength -ne 16 -or $result.PasswordHistoryCount -ne 24 -or -not $result.ComplexityEnabled -or $result.MaxPasswordAge -ne (New-TimeSpan -Days 60) -or $result.MinPasswordAge -ne (New-TimeSpan -Days 1) -or $result.LockoutThreshold -ne 5 -or $result.LockoutDuration -ne (New-TimeSpan -Minutes 10) -or $result.LockoutObservationWindow -ne (New-TimeSpan -Minutes 10) -or $result.ReversibleEncryptionEnabled) { throw 'Resultant PSO assertion failed.' }
        $subjects = @(Get-ADFineGrainedPasswordPolicySubject -Identity 'PSO-Admins-Strong')
        if ($subjects.Count -ne 1 -or $subjects[0].DistinguishedName -ine $adm.DistinguishedName) { throw 'PSO direct subject assertion failed.' }
        $wl = @((Get-GPInheritance -Target 'OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal').GpoLinks)
        $ul = @((Get-GPInheritance -Target 'OU=Users,OU=HUFFLAB,DC=hufflab,DC=internal').GpoLinks)
        if ($wl.Count -ne 1 -or @($wl | Where-Object { $_.GpoId -ne $computer.Id -or $_.Enabled -ne $true -or $_.Enforced -ne $false }).Count) { throw 'Computer GPO link assertion failed.' }
        if ($ul.Count -ne 1 -or @($ul | Where-Object { $_.GpoId -ne $user.Id -or $_.Enabled -ne $true -or $_.Enforced -ne $false }).Count) { throw 'User GPO link assertion failed.' }
        'REMOTE MUTATIONS COMPLETE; GUI settings remain required.'
    } | Tee-Object -FilePath $logPath -Append | Out-Host
    'GUI_REQUIRED' | Set-Content $statusPath
    Write-Stage 'COMPLETE: PSO and OU links created; GUI settings remain required.'
} catch {
    ('FAIL: ' + $_.Exception.Message) | Tee-Object -FilePath $logPath -Append | Out-Host
    'FAIL' | Set-Content $statusPath
    throw
} finally {
    if ($dc) { Remove-PSSession $dc -ErrorAction SilentlyContinue }
    if ($cl) { Remove-PSSession $cl -ErrorAction SilentlyContinue }
    Remove-Variable domainAdmin -ErrorAction SilentlyContinue
}

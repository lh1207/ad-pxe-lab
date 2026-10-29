[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location 'C:\HyperV\ad-pxe-lab'
$sessionRoot = 'C:\HyperV\ad-pxe-lab\docs\phase-05-session'
$hrEvidence = 'C:\HyperV\ad-pxe-lab\docs\evidence\phase-05\hr-user-verification.txt'
$banner = 'C:\HyperV\ad-pxe-lab\docs\evidence\phase-05\cl02-logon-banner.png'
New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$logPath = Join-Path $sessionRoot "gpo-finalize-$stamp.txt"
$statusPath = Join-Path $sessionRoot "gpo-finalize-$stamp-status.txt"
$hostUserRsop = Join-Path $sessionRoot "CL02-user-gpresult-$stamp.xml"
if ((Test-Path $logPath) -or (Test-Path $statusPath)) { throw 'Timestamp collision; refusing to overwrite a session record.' }

function Write-Stage([string]$Text) { $Text | Tee-Object -FilePath $logPath -Append | Write-Host }
function Invoke-HostPreflight { Write-Stage 'STAGE HOST_PREFLIGHT'; & '.\scripts\05-Test-Phase05Environment.ps1' 2>&1 | Tee-Object -FilePath $logPath -Append | Out-Host }
function Assert-RsopGpo([object]$Node,[string]$Name,[string]$Guid,[string]$SomPath) {
    if ($null -eq $Node) { throw "Missing RSOP GPO $Name." }
    if (@($Node).Count -ne 1) { throw "Expected one RSOP GPO $Name." }
    $id = $Node.SelectSingleNode('./*[local-name()="Path"]/*[local-name()="Identifier"]')
    $link = $Node.SelectSingleNode('./*[local-name()="Link"]')
    if ($null -eq $id -or $id.InnerText.Trim('{}').ToLower() -ne $Guid.ToLower() -or $Node.Enabled.ToString().ToLower() -ne 'true' -or $Node.IsValid.ToString().ToLower() -ne 'true' -or $Node.FilterAllowed.ToString().ToLower() -ne 'true' -or $Node.AccessDenied.ToString().ToLower() -ne 'false' -or $null -eq $link -or $link.SOMPath -ne $SomPath -or $link.Enabled.ToString().ToLower() -ne 'true' -or [int]$link.AppliedOrder -le 0) { throw "RSOP assertion failed for $Name." }
    $Node
}

$domainAdmin = $null
$cl = $null
$dc = $null
try {
    'STARTING' | Set-Content -LiteralPath $statusPath
    Invoke-HostPreflight
    if (-not (Test-Path -LiteralPath $hrEvidence)) { throw "Required HR evidence is missing: $hrEvidence" }
    if (-not (Test-Path -LiteralPath $banner)) { throw "Required logon-banner evidence is missing: $banner" }
    $hrText = Get-Content -LiteralPath $hrEvidence -Raw
    foreach ($needle in @('HUFFLAB\hr.jones','\\DC01\HRShare','True','Applied Group Policy Objects','GPO-U-IT-DriveMaps')) { if ($hrText -notmatch [regex]::Escape($needle)) { throw "HR evidence is missing required text: $needle" } }
    Write-Stage 'STAGE CREDENTIAL_PROMPT'
    $domainAdmin = Get-Credential -UserName 'HUFFLAB\Administrator' -Message 'Phase 05 finalization. Password remains in memory only.'
    if ($null -eq $domainAdmin) { throw 'Credential prompt canceled.' }

    Write-Stage 'STAGE RUN_CONFIGURATION_VERIFIER'
    $verification = @(& '.\scripts\05-Test-GpoConfiguration.ps1' -Credential $domainAdmin)
    if ($verification.Count -ne 1 -or $verification[0].Result -ne 'CONFIGURATION_AND_REGISTRY_PASS_RSOP_HR_INTERACTIVE_PENDING') { throw 'Configuration verifier did not return the expected pending result.' }
    $v = $verification[0]
    foreach ($id in @($v.BaselineGpoId,$v.DriveMapsGpoId)) {
        if ([string]::IsNullOrWhiteSpace($id) -or [guid]$id -eq [guid]::Empty) { throw 'Verifier returned an invalid custom GPO identifier.' }
    }
    foreach ($path in @($v.LogPath,$v.ComputerGpResultPath,$v.HostEvidencePath)) { if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) { throw "Verifier evidence path is missing: $path" } }
    Write-Stage 'VERIFIER_RESULT_ACCEPTED'

    Write-Stage 'STAGE COMPUTER_RSOP_ASSERTIONS'
    $cx = New-Object System.Xml.XmlDocument
    $cx.Load($v.ComputerGpResultPath)
    $cg = @($cx.SelectNodes('//*[local-name()="ComputerResults"]/*[local-name()="GPO"]') | Where-Object { $_.Name -eq 'GPO-C-Workstation-Baseline' })
    if ($cg.Count -ne 1) { throw 'Expected exactly one computer baseline GPO in RSOP.' }
    Assert-RsopGpo $cg[0] 'GPO-C-Workstation-Baseline' $v.BaselineGpoId 'hufflab.internal/HUFFLAB/Workstations' | Out-Null
    $cv = $cg[0]
    if ([string]::IsNullOrWhiteSpace([string]$cv.VersionDirectory) -or $cv.VersionDirectory -ne $cv.VersionSysvol) { throw 'Computer RSOP AD/SYSVOL versions differ or are missing.' }

    Write-Stage 'STAGE CL02_USER_RSOP_AND_LIVE_ASSERTIONS'
    $cl = New-PSSession -VMName CL02 -Credential $domainAdmin -ErrorAction Stop
    $u = Invoke-Command -Session $cl -ArgumentList $stamp -ScriptBlock {
        param([string]$RunStamp)
        $ErrorActionPreference = 'Stop'
        $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'CL02 administrator token required.' }
        $c = Get-CimInstance Win32_ComputerSystem
        if (-not $c.PartOfDomain -or $c.Domain -ine 'hufflab.internal' -or -not (Test-ComputerSecureChannel)) { throw 'CL02 domain or secure channel failed.' }
        if ('10.0.100.10' -notin @(Get-DnsClientServerAddress -AddressFamily IPv4 | ForEach-Object ServerAddresses)) { throw 'CL02 DC01 DNS missing.' }
        if (@(Get-Process -Name gpupdate,gpresult -ErrorAction SilentlyContinue).Count) { throw 'A policy process is already running on CL02.' }
        $path = Join-Path $env:TEMP "phase05-user-gpresult-$RunStamp.xml"
        & "$env:SystemRoot\System32\gpresult.exe" /user HUFFLAB\hr.jones /scope user /x $path /f 1>$null 2>$null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $path)) { throw "User gpresult failed with exit code $LASTEXITCODE." }
        if (@(Get-Process -Name gpupdate,gpresult -ErrorAction SilentlyContinue).Count) { throw 'A policy process remained on CL02.' }
        [pscustomobject]@{ UserGpResultPath=$path; Domain=$c.Domain; SecureChannel=(Test-ComputerSecureChannel); DNS='10.0.100.10' }
    }
    Invoke-Command -Session $cl -ScriptBlock { Set-StrictMode -Off } | Out-Null
    try { Copy-Item -FromSession $cl -LiteralPath $u.UserGpResultPath -Destination $hostUserRsop -ErrorAction Stop } finally { Invoke-Command -Session $cl -ScriptBlock { Set-StrictMode -Version Latest } | Out-Null }
    Write-Stage "USER_RSOP_COPIED $hostUserRsop"
    $ux = New-Object System.Xml.XmlDocument
    $ux.Load($hostUserRsop)
    $ur = $ux.SelectSingleNode('//*[local-name()="UserResults"]')
    if ($null -eq $ur) { throw 'User RSOP UserResults is missing.' }
    if ($ur.InnerText -match '(?i)hr\.jones') { Write-Stage 'USER_RSOP_IDENTITY: HUFFLAB\hr.jones' } else { Write-Stage 'USER_RSOP_IDENTITY_LIMITATION: schema has no explicit user identity; pasted HR evidence required'; if ($hrText -notmatch '(?i)HUFFLAB\\hr\.jones') { throw 'HR identity is absent from both RSOP and pasted evidence.' } }
    $ug = @($ur.SelectNodes('./*[local-name()="GPO"]') | Where-Object { $_.Name -eq 'GPO-U-IT-DriveMaps' })
    if ($ug.Count -ne 1) { throw 'Expected exactly one user drive-map GPO in RSOP.' }
    Assert-RsopGpo $ug[0] 'GPO-U-IT-DriveMaps' $v.DriveMapsGpoId 'hufflab.internal/HUFFLAB/Users' | Out-Null
    if ([string]::IsNullOrWhiteSpace([string]$ug[0].VersionDirectory) -or $ug[0].VersionDirectory -ne $ug[0].VersionSysvol) { throw 'User RSOP AD/SYSVOL versions differ or are missing.' }
    Write-Stage 'CL02 LIVE_ASSERTIONS_PASS'
    Remove-PSSession $cl; $cl = $null

    Write-Stage 'STAGE DC01_FINAL_LIVE_ASSERTIONS'
    $dc = New-PSSession -VMName DC01 -Credential $domainAdmin -ErrorAction Stop
    Invoke-Command -Session $dc -ScriptBlock { if (@(Get-Process -Name gpupdate,gpresult -ErrorAction SilentlyContinue).Count -or @(Get-Service NTDS,DNS,Netlogon | Where-Object Status -ne 'Running').Count) { throw 'DC01 policy process or required service state invalid.' }; 'DC01_FINAL_ASSERTIONS_PASS' } | Tee-Object -FilePath $logPath -Append | Out-Host
    Remove-PSSession $dc; $dc = $null
    Write-Stage 'STAGE FINAL_HOST_PREFLIGHT_AND_CHECKPOINTS'
    Invoke-HostPreflight
    if (@(Get-Job | Where-Object State -eq 'Running').Count -or @(Get-VM -Name DC01,CL02,WDS01,CM01,CL01,REF01 | Where-Object State -notin @('Running','Off')).Count) { throw 'Host jobs or lab VM busy state detected.' }
    $vms = @(Get-VM -Name DC01,CL02)
    if (@(Get-VM | Where-Object State -eq 'Running').Name -notcontains 'DC01' -or @(Get-VM | Where-Object State -eq 'Running').Name -notcontains 'CL02' -or @(Get-VM | Where-Object State -eq 'Running').Count -ne 2) { throw 'Only DC01 and CL02 may be running.' }
    foreach ($vm in $vms) {
        if ($vm.CheckpointType.ToString() -ne 'Standard') { throw "Standard checkpoint configuration is required on $($vm.Name); inspect before proceeding." }
        if (@(Get-VMSnapshot -VMName $vm.Name | Where-Object Name -eq 'pre-phase-06').Count) { throw "pre-phase-06 already exists on $($vm.Name)." }
    }
    foreach ($vm in @('DC01','CL02')) { Checkpoint-VM -Name $vm -SnapshotName 'pre-phase-06' -ErrorAction Stop; $s = @(Get-VMSnapshot -VMName $vm -Name 'pre-phase-06'); if ($s.Count -ne 1 -or $s[0].SnapshotType -ne 'Standard') { throw "Invalid pre-phase-06 checkpoint on $vm." }; Write-Stage ("CHECKPOINT {0} ID={1} CreationTime={2} State={3}" -f $vm,$s[0].Id,$s[0].CreationTime,(Get-VM -Name $vm).State) }
    'PHASE05FINALGATE_PASS' | Set-Content -LiteralPath $statusPath
    Write-Stage 'PHASE 05 FINAL GATE: PASS'
} catch { ('FAIL: ' + $_.Exception.Message) | Tee-Object -FilePath $logPath -Append | Out-Host; 'FAIL' | Set-Content -LiteralPath $statusPath; throw }
finally { if ($cl) { Remove-PSSession $cl -ErrorAction SilentlyContinue }; if ($dc) { Remove-PSSession $dc -ErrorAction SilentlyContinue }; Remove-Variable domainAdmin -ErrorAction SilentlyContinue }

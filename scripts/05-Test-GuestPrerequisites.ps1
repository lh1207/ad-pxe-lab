# Operator-attended, read-only Phase 05 prerequisites. No pending-job runner.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location 'C:\HyperV\ad-pxe-lab'
$sessionRoot = 'C:\HyperV\ad-pxe-lab\docs\phase-05-session'
New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null
$log = Join-Path $sessionRoot 'guest-prerequisites.txt'
$status = Join-Path $sessionRoot 'guest-prerequisites-status.txt'
try {
    'READ-ONLY PHASE 05 GUEST PREREQUISITES' | Set-Content $log
    Get-Date -Format o | Add-Content $log
    & .\scripts\05-Test-Phase05Environment.ps1 | Format-List | Out-String | Add-Content $log
    'WAITING_CREDENTIAL' | Set-Content $status
    $domainAdmin = Get-Credential -UserName 'HUFFLAB\Administrator' -Message 'Enter the saved lab password. It remains in memory only.'
    if ($null -eq $domainAdmin) { throw 'Credential prompt canceled.' }
    'CHECKING' | Set-Content $status
    # One attempt per guest. No guessed passwords or automatic authentication retry.
    Invoke-Command -VMName DC01 -Credential $domainAdmin -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'DC01 administrator token required.' }
        Import-Module ActiveDirectory
        Import-Module GroupPolicy
        if ((Get-ADDomain).DNSRoot -ine 'hufflab.internal') { throw 'Domain mismatch.' }
        $services = @(Get-Service NTDS,DNS,Netlogon)
        if (@($services | Where-Object Status -ne 'Running').Count) { throw 'Required domain service not running.' }
        $services | Select-Object Name,Status
        $computer = Get-ADComputer CL02
        if ($computer.DistinguishedName -ine 'CN=CL02,OU=Workstations,OU=HUFFLAB,DC=hufflab,DC=internal') { throw 'CL02 OU mismatch.' }
        $user = Get-ADUser hr.jones
        if ($user.DistinguishedName -notlike '*,OU=Users,OU=HUFFLAB,DC=hufflab,DC=internal') { throw 'HR user is outside Users OU.' }
        if ('hr.jones' -notin @(Get-ADGroupMember RG-HR-Staff -Recursive | Select-Object -ExpandProperty SamAccountName)) { throw 'Missing HR role membership.' }
        if ('hr.jones' -notin @(Get-ADGroupMember AG-Share-HR-Modify -Recursive | Select-Object -ExpandProperty SamAccountName)) { throw 'Missing AGDLP membership.' }
        Get-ADGroup AG-WKS-LocalAdmin | Select-Object Name,DistinguishedName
        Get-ADUser adm-lhuff | Select-Object SamAccountName,Enabled
        $computer | Select-Object Name,DistinguishedName
        $user | Select-Object Name,DistinguishedName
        Get-SmbShareAccess HRShare | Format-Table -AutoSize
        $share = Get-SmbShare HRShare
        (Get-Acl -LiteralPath $share.Path).Access | Format-Table -AutoSize
        Get-ADDefaultDomainPasswordPolicy | Format-List
        Get-ADFineGrainedPasswordPolicy -Filter * | Format-List Name,Precedence,MinPasswordLength,AppliesTo
        Get-GPO -All | Select-Object DisplayName,Id,GpoStatus,ModificationTime | Format-Table -AutoSize
        foreach ($ou in @('Workstations','Users')) {
            Get-GPInheritance -Target "OU=$ou,OU=HUFFLAB,DC=hufflab,DC=internal" | Format-List
        }
        'DC01 prerequisite assertions: PASS'
    } -ErrorAction Stop | Out-String -Width 240 | Add-Content $log
    Invoke-Command -VMName CL02 -Credential $domainAdmin -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'CL02 administrator token required.' }
        $system = Get-CimInstance Win32_ComputerSystem
        if (-not $system.PartOfDomain -or $system.Domain -ine 'hufflab.internal') { throw 'CL02 domain membership mismatch.' }
        if (-not (Test-ComputerSecureChannel)) { throw 'CL02 secure channel failed.' }
        $dns = @(Get-DnsClientServerAddress -AddressFamily IPv4 | ForEach-Object ServerAddresses)
        if ('10.0.100.10' -notin $dns) { throw 'CL02 lacks DC01 DNS.' }
        $system | Select-Object Name,Domain,PartOfDomain,UserName
        Get-DnsClientServerAddress -AddressFamily IPv4 | Format-Table -AutoSize
        'CL02 prerequisite assertions: PASS'
    } -ErrorAction Stop | Out-String -Width 240 | Add-Content $log
    'PASS' | Set-Content $status
    'PHASE 05 GUEST PREREQUISITES: PASS' | Add-Content $log
    Write-Host 'Prerequisites passed. Return to Codex; no policies were changed.'
} catch {
    'FAIL' | Set-Content $status
    ('STOP: ' + $_.Exception.Message) | Add-Content $log
    Write-Host ('Prerequisites stopped: ' + $_.Exception.Message)
    exit 1
} finally {
    Remove-Variable domainAdmin -ErrorAction SilentlyContinue
}

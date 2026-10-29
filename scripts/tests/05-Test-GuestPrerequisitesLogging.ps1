[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptsRoot = Split-Path $PSScriptRoot -Parent
$source = Join-Path $scriptsRoot '05-Test-GuestPrerequisites.ps1'
$tokens = $null
$parseErrors = $null
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Production prerequisite script does not parse.' }
$newItem = @($sourceAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'New-Item' -and $n.Extent.Text -match '\$sessionRoot' -and $n.Extent.Text -match '(?i)-Force' }, $true))[0]
$logWrite = @($sourceAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Set-Content' -and $n.Extent.Text -match '\$log' }, $true))[0]
$statusWrite = @($sourceAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Set-Content' -and $n.Extent.Text -match '\$status' }, $true))[0]
if ($null -eq $newItem -or $null -eq $logWrite -or $null -eq $statusWrite) { throw 'Production bootstrap AST statements are missing or changed.' }
if ($newItem.Extent.StartOffset -ge $logWrite.Extent.StartOffset -or $newItem.Extent.StartOffset -ge $statusWrite.Extent.StartOffset) { throw 'Production sessionRoot creation must precede both log and status writes.' }

$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$root = Join-Path $tempRoot ('phase05-guest-log-' + [guid]::NewGuid().ToString('N'))
$rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\')
if (-not $rootFull.StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Resolved test root escaped the temporary directory.' }
$sessionRoot = Join-Path $root 'docs\phase-05-session'
$log = Join-Path $sessionRoot 'guest-prerequisites.txt'
$status = Join-Path $sessionRoot 'guest-prerequisites-status.txt'
try {
    if (Test-Path -LiteralPath $sessionRoot) { throw 'Isolated test directory unexpectedly exists.' }
    # Evaluate the actual production command ASTs against an isolated path.
    Invoke-Expression -Command ($newItem.Parent.Extent.Text)
    Invoke-Expression -Command ($logWrite.Parent.Extent.Text)
    Invoke-Expression -Command ($statusWrite.Parent.Extent.Text)
    if (-not (Test-Path -LiteralPath $log) -or -not (Test-Path -LiteralPath $status)) { throw 'Fresh-directory log/status bootstrap failed.' }
    if ((Get-Content -Raw -LiteralPath $log) -notmatch 'READ-ONLY PHASE 05 GUEST PREREQUISITES' -or (Get-Content -Raw -LiteralPath $status) -notmatch 'WAITING_CREDENTIAL') { throw 'Bootstrap content assertion failed.' }
    Invoke-Expression -Command ($newItem.Parent.Extent.Text)
    'REPEAT_OK' | Add-Content -LiteralPath $log
    if ((Get-Content -Raw -LiteralPath $log) -notmatch 'REPEAT_OK') { throw 'Existing-directory repeat assertion failed.' }
    'GUEST_PREREQUISITES_LOGGING_TEST_PASS'
} finally {
    if (Test-Path -LiteralPath $rootFull) {
        $resolved = (Resolve-Path -LiteralPath $rootFull).Path.TrimEnd('\')
        if ($resolved -ne $rootFull -or -not $resolved.StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing cleanup outside the isolated temp root.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

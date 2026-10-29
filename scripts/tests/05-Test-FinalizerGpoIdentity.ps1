# Regression test for dynamic custom-GPO identity flow. No guest or Hyper-V access.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsRoot = Split-Path -Parent $PSScriptRoot
$finalizerPath = Join-Path $scriptsRoot '05-FinalizeGpoSuite.ps1'
$verifierPath = Join-Path $scriptsRoot '05-Test-GpoConfiguration.ps1'

function Parse-Source([string]$Path) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw ($errors | Out-String) }
    $ast
}

function Assert-Throws([scriptblock]$Action, [string]$Label) {
    try { & $Action } catch { return }
    throw "Expected rejection: $Label"
}

function New-RsopGpoNode([string]$Guid, [string]$SomPath, [bool]$FilterAllowed = $true) {
    $xml = New-Object System.Xml.XmlDocument
    $filterText = $FilterAllowed.ToString().ToLowerInvariant()
    $xml.LoadXml(@"
<Rsop>
  <GPO>
    <Path><Identifier>{$Guid}</Identifier></Path>
    <Enabled>true</Enabled>
    <IsValid>true</IsValid>
    <FilterAllowed>$filterText</FilterAllowed>
    <AccessDenied>false</AccessDenied>
    <Link><SOMPath>$SomPath</SOMPath><Enabled>true</Enabled><AppliedOrder>1</AppliedOrder></Link>
  </GPO>
</Rsop>
"@)
    $xml.SelectSingleNode('/Rsop/GPO')
}

$finalizerAst = Parse-Source $finalizerPath
$assertionDefinitions = @($finalizerAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-RsopGpo'
}, $true))
if ($assertionDefinitions.Count -ne 1) { throw 'Expected one actual Assert-RsopGpo definition.' }

# Define the production assertion from its parsed source, rather than a test copy.
Invoke-Expression $assertionDefinitions[0].Extent.Text

$invocations = @($finalizerAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Assert-RsopGpo'
}, $true))
if ($invocations.Count -ne 2) { throw 'Expected exactly two actual Assert-RsopGpo invocations.' }

$baselineId = [guid]::NewGuid().ToString()
$driveMapsId = [guid]::NewGuid().ToString()
$baselineNode = New-RsopGpoNode $baselineId 'hufflab.internal/HUFFLAB/Workstations'
$driveMapsNode = New-RsopGpoNode $driveMapsId 'hufflab.internal/HUFFLAB/Users'
$v = [pscustomobject]@{ BaselineGpoId = $baselineId; DriveMapsGpoId = $driveMapsId }
$cg = @($baselineNode)
$ug = @($driveMapsNode)

foreach ($invocation in $invocations) {
    $text = $invocation.Extent.Text
    if ($text -match 'GPO-C-Workstation-Baseline') {
        if ($text -notmatch '\$v\.BaselineGpoId') { throw 'Baseline RSOP call must use $v.BaselineGpoId.' }
    } elseif ($text -match 'GPO-U-IT-DriveMaps') {
        if ($text -notmatch '\$v\.DriveMapsGpoId') { throw 'Drive-map RSOP call must use $v.DriveMapsGpoId.' }
    } else {
        throw 'Unexpected Assert-RsopGpo invocation.'
    }
    if ($text -match '3d5e8657-4b90-4364-b026-2bad36ea027f|07473a8a-8c5f-4296-b09a-c7e7f6149ef7') {
        throw 'Finalizer RSOP call retains a hard-coded custom GPO GUID.'
    }
    & ([scriptblock]::Create($text)) | Out-Null
}

Assert-Throws { Assert-RsopGpo $baselineNode 'GPO-C-Workstation-Baseline' '3d5e8657-4b90-4364-b026-2bad36ea027f' 'hufflab.internal/HUFFLAB/Workstations' | Out-Null } 'old baseline GUID'
Assert-Throws { Assert-RsopGpo $driveMapsNode 'GPO-U-IT-DriveMaps' '07473a8a-8c5f-4296-b09a-c7e7f6149ef7' 'hufflab.internal/HUFFLAB/Users' | Out-Null } 'old drive-map GUID'
Assert-Throws { Assert-RsopGpo $null 'GPO-C-Workstation-Baseline' $baselineId 'hufflab.internal/HUFFLAB/Workstations' | Out-Null } 'missing RSOP node'
Assert-Throws { Assert-RsopGpo (New-RsopGpoNode $baselineId 'hufflab.internal/HUFFLAB/Users') 'GPO-C-Workstation-Baseline' $baselineId 'hufflab.internal/HUFFLAB/Workstations' | Out-Null } 'wrong Workstations link'
Assert-Throws { Assert-RsopGpo (New-RsopGpoNode $driveMapsId 'hufflab.internal/HUFFLAB/Users' $false) 'GPO-U-IT-DriveMaps' $driveMapsId 'hufflab.internal/HUFFLAB/Users' | Out-Null } 'disallowed security filter'

$verifierAst = Parse-Source $verifierPath
$configurationAssignments = @($verifierAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
    $node.Left.VariablePath.UserPath -eq 'configuration' -and
    $node.Right.Extent.Text -match 'Invoke-Command' -and
    $node.Right.Extent.Text -match 'Tee-Object' -and
    $node.Right.Extent.Text -match 'Where-Object'
}, $true))
if ($configurationAssignments.Count -ne 1) { throw 'Expected one filtered DC configuration capture assignment.' }
$captureText = $configurationAssignments[0].Extent.Text
if ($captureText -notmatch '\$_\s+-isnot\s+\[string\]') {
    throw 'DC configuration capture must filter PASS strings from the structured result.'
}

# Exercise the parsed production assignment with a mixed remote stream. The mock ignores the
# embedded production script block, so this does not contact a guest or write a transcript.
$fixtureConfiguration = [pscustomobject]@{
    Result = 'DC01_CONFIGURATION_ASSERTIONS_PASS'
    BaselineGpoId = $baselineId
    DriveMapsGpoId = $driveMapsId
}
function Invoke-Command {
    param([object]$Session, [scriptblock]$ScriptBlock)
    'Default Domain Policy saved settings and effective password policy: PASS'
    $script:fixtureConfiguration
    'Administrator PSO and resultant policy: PASS'
}
function Tee-Object {
    param(
        [Parameter(ValueFromPipeline = $true)][object]$InputObject,
        [string]$FilePath,
        [switch]$Append
    )
    process { $InputObject }
}
$dc = [pscustomobject]@{ Name = 'fixture-dc' }
$logPath = 'fixture-log'
$configuration = $null
Invoke-Expression $captureText | Out-Null
if (@($configuration).Count -ne 1 -or $configuration[0] -is [string] -or $configuration[0].Result -ne 'DC01_CONFIGURATION_ASSERTIONS_PASS' -or $configuration[0].BaselineGpoId -ne $baselineId -or $configuration[0].DriveMapsGpoId -ne $driveMapsId) {
    throw 'DC configuration capture leaked PASS strings or lost the structured GPO identifiers.'
}

$resultObjects = @($verifierAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.ConvertExpressionAst] -and
    $node.Extent.Text -match '^\[pscustomobject\]' -and
    $node.Extent.Text -match "CONFIGURATION_AND_REGISTRY_PASS_RSOP_HR_INTERACTIVE_PENDING" -and
    $node.Extent.Text -match 'BaselineGpoId' -and $node.Extent.Text -match 'DriveMapsGpoId'
}, $true))
if ($resultObjects.Count -ne 1) { throw 'Expected one verifier final result object with custom GPO identifiers.' }
$resultText = $resultObjects[0].Extent.Text
if ($resultText -notmatch 'BaselineGpoId\s*=\s*\$configuration\[0\]\.BaselineGpoId' -or $resultText -notmatch 'DriveMapsGpoId\s*=\s*\$configuration\[0\]\.DriveMapsGpoId') {
    throw 'Verifier final result must wire custom GPO identifiers from the DC assertion result.'
}

$configuration = @([pscustomobject]@{
    Result = 'DC01_CONFIGURATION_ASSERTIONS_PASS'
    BaselineGpoId = $baselineId
    DriveMapsGpoId = $driveMapsId
})
$logPath = 'fixture-log'
$hostComputerGpResult = 'fixture-computer-rsop'
$hostEvidencePath = 'fixture-evidence'
$finalResult = & ([scriptblock]::Create($resultText))
if ($finalResult.BaselineGpoId -ne $baselineId -or $finalResult.DriveMapsGpoId -ne $driveMapsId) {
    throw 'Verifier final result did not preserve generated custom GPO identifiers.'
}

'PASS: actual finalizer RSOP calls accept generated GPO IDs and reject stale/missing/link/filter variants; verifier filters DC PASS strings and forwards DC assertion IDs.'

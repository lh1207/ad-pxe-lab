# Regression test of the initializer's actual OU guard expressions. No guest access.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path (Split-Path $PSScriptRoot -Parent) '05-InitializeGpoSuite.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$guards = @($ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.IfStatementAst] -and
    $node.Clauses[0].Item1.Extent.Text -match 'GpoInheritanceBlocked'
}, $true))
if ($guards.Count -ne 3) { throw 'Expected all three initializer inheritance guards.' }
$cases = @(
    [pscustomobject]@{ Label='Boolean false, no links'; Blocked=$false; Links=@(); Reject=$false },
    [pscustomobject]@{ Label='Formatted No, no links'; Blocked='No'; Links=@(); Reject=$false },
    [pscustomobject]@{ Label='String False, no links'; Blocked='False'; Links=@(); Reject=$false },
    [pscustomobject]@{ Label='Boolean true'; Blocked=$true; Links=@(); Reject=$true },
    [pscustomobject]@{ Label='Formatted Yes'; Blocked='Yes'; Links=@(); Reject=$true },
    [pscustomobject]@{ Label='Unexpected value'; Blocked='unknown'; Links=@(); Reject=$true },
    [pscustomobject]@{ Label='Missing value'; Blocked=$null; Links=@(); Reject=$true },
    [pscustomobject]@{ Label='Existing direct link'; Blocked=$false; Links=@('fixture'); Reject=$true }
)
foreach ($guard in $guards) {
    $condition = [scriptblock]::Create('(' + $guard.Clauses[0].Item1.Extent.Text + ')')
    foreach ($case in $cases) {
        $i = [pscustomobject]@{ GpoInheritanceBlocked=$case.Blocked; GpoLinks=$case.Links }
        $actual = & $condition
        if ($actual -ne $case.Reject) { throw "Guard failed case: $($case.Label)" }
    }
}
'PASS: 3 actual OU guards x 8 regression cases; no guest access.'

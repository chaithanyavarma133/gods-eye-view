<#
.SYNOPSIS
    Installs ECC agent definitions into Claude Code's agents directory.

.DESCRIPTION
    Copies every agents/*.md file from a local ECC checkout into the Claude Code
    agents folder, creating the destination directory when it does not exist yet.

    This is the Windows equivalent of the documented manual install:

        mkdir -p ~/.claude/agents
        cp agents/*.md ~/.claude/agents/

    WHY THIS SCRIPT EXISTS
    ----------------------
    PowerShell's Copy-Item (alias: cp) never creates the destination folder.
    When %USERPROFILE%\.claude\agents does not exist, the copy fails with:

        cp : The directory name is invalid.
        + CategoryInfo : NotSpecified: (:) [Copy-Item], IOException

    Creating the destination first is therefore mandatory - this script does it
    for you, then copies, verifies, and reports what happened.

.PARAMETER Source
    Folder containing the ECC agent .md files.
    Defaults to .\agents in the current directory.

.PARAMETER Destination
    Where to install the agents. Defaults to $HOME\.claude\agents
    (i.e. %USERPROFILE%\.claude\agents).

.PARAMETER Project
    Install into .\.claude\agents of the current directory (project-local
    agents) instead of the user-level folder.

.PARAMETER Force
    Overwrite agent files that already exist. Without this switch, existing
    files are skipped rather than replaced.

.EXAMPLE
    .\install-ecc-agents.ps1 -Source .\everything-claude-code\agents
    Copies all agents into %USERPROFILE%\.claude\agents.

.EXAMPLE
    .\install-ecc-agents.ps1 -Source .\ECC\agents -Force
    Re-installs and overwrites any existing agent files.

.EXAMPLE
    .\install-ecc-agents.ps1 -Source .\ECC\agents -Project
    Installs into .\.claude\agents of the current repository.

.NOTES
    For a full install prefer the official installer or the plugin:
        .\install.ps1 --target claude
        /plugin install ecc@ecc
    Do NOT stack a manual agent copy on top of either one - duplicate agent
    definitions across scopes cause conflicting/duplicated agents.
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Source = '.\agents',

    [Parameter(Mandatory = $false)]
    [string]$Destination = (Join-Path $HOME '.claude\agents'),

    [Parameter(Mandatory = $false)]
    [switch]$Project,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Helpers ------------------------------------------------------------------

function Resolve-ExistingFolder {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$What
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$What not found: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-DefaultUserHome {
    if ($HOME -and (Test-Path -LiteralPath $HOME)) { return $HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    throw 'Could not determine the user home directory.'
}

# --- Resolve source -----------------------------------------------------------

$sourceFolder = Resolve-ExistingFolder -Path $Source -What 'Agent source folder'

$agentFiles = @(Get-ChildItem -LiteralPath $sourceFolder -Filter '*.md' -File | Sort-Object Name)
if ($agentFiles.Count -eq 0) {
    throw "No .md agent files found in: $sourceFolder"
}

# --- Resolve destination ------------------------------------------------------

if ($Project) {
    $destinationFolder = Join-Path (Get-Location).Path '.claude\agents'
}
elseif ($PSBoundParameters.ContainsKey('Destination')) {
    $destinationFolder = $Destination
}
else {
    $destinationFolder = Join-Path (Get-DefaultUserHome) '.claude\agents'
}

# --- The step the failing `cp` was missing: create the destination -------------

$destinationCreated = $false
if (-not (Test-Path -LiteralPath $destinationFolder)) {
    $null = New-Item -ItemType Directory -Path $destinationFolder -Force
    $destinationCreated = $true
    Write-Host "Created destination: $destinationFolder"
}

# --- Copy ---------------------------------------------------------------------

$copied  = 0
$skipped = 0
$failed  = @()

foreach ($file in $agentFiles) {
    $target = Join-Path $destinationFolder $file.Name

    if ((Test-Path -LiteralPath $target) -and (-not $Force)) {
        $skipped++
        continue
    }

    try {
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        $copied++
    }
    catch {
        $failed += $file.Name
        Write-Warning "Failed to copy '$($file.Name)': $_"
    }
}

# --- Verify + report ----------------------------------------------------------

$installed = @(Get-ChildItem -LiteralPath $destinationFolder -Filter '*.md' -File)

$createdNote = ''
if ($destinationCreated) { $createdNote = '  (created)' }

Write-Host ''
Write-Host "Source      : $sourceFolder ($($agentFiles.Count) agent files)"
Write-Host "Destination : $destinationFolder$createdNote"
Write-Host "Copied      : $copied"
if ($skipped -gt 0) {
    Write-Host "Skipped     : $skipped (already present - pass -Force to overwrite)"
}
Write-Host "Now present : $($installed.Count) agent file(s)"

if ($failed.Count -gt 0) {
    Write-Host "Failed      : $($failed.Count)" -ForegroundColor Red
    exit 1
}

# Light sanity check: Claude Code ignores agent files without YAML front matter.
$badFrontmatter = @(
    $installed | Where-Object {
        $firstLine = (Get-Content -LiteralPath $_.FullName -TotalCount 1)
        ($firstLine -eq $null) -or ($firstLine.Trim() -ne '---')
    }
)
if ($badFrontmatter.Count -gt 0) {
    Write-Warning "$($badFrontmatter.Count) installed file(s) are missing '---' front matter and will be ignored:"
    foreach ($bad in $badFrontmatter) { Write-Warning "  - $($bad.Name)" }
}

Write-Host ''
Write-Host 'Done. Restart Claude Code (or run /agents) so the new agents are picked up.'
exit 0

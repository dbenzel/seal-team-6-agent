#Requires -Version 5.1
<#
.SYNOPSIS
    Seal Team 6 — Agentic Best Practices Installer (Windows)
.DESCRIPTION
    Installs seal-team-6 agentic best practices into the current project directory.
.EXAMPLE
    irm https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1 -Lang typescript,python
#>

param(
    [string]$Lang = "",
    [string]$Version = "main",
    [switch]$Cursor,
    [switch]$Windsurf,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"

# --- Configuration ---
$Repo = "dbenzel/seal-team-6-agent"
$Branch = $Version
$BaseUrl = "https://raw.githubusercontent.com/$Repo/$Branch"
$DocsDir = "docs/seal-team-6"
$AllLanguages = @("typescript", "python", "go", "rust", "java", "csharp")
$MarkerBegin = "<!-- BEGIN seal-team-6 -->"
$MarkerEnd = "<!-- END seal-team-6 -->"

# --- UTF-8 without BOM (PS 5.1 Set-Content adds BOM) ---
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Resolve-PathSafe {
    param([string]$Path)
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Write-FileContent {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText(
        (Resolve-PathSafe $Path),
        $Content,
        $Utf8NoBom
    )
}

function Read-FileContent {
    param([string]$Path)
    [System.IO.File]::ReadAllText(
        (Resolve-PathSafe $Path),
        [System.Text.Encoding]::UTF8
    )
}

# --- Helpers ---
function Write-Info {
    param([string]$Message)
    Write-Host "[seal-team-6] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[seal-team-6] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[seal-team-6] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Download-File {
    param(
        [string]$Url,
        [string]$Dest
    )
    $dir = Split-Path -Parent $Dest
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to download ${Url}: $_"
        exit 1
    }
}

# Inject a seal-team-6 reference block at the top of a file.
# If the file already has a seal-team-6 block, replace it.
# If the file doesn't exist, create it with just the block.
function Inject-Reference {
    param(
        [string]$File,
        [string]$Block
    )
    $injected = "${MarkerBegin}`n${Block}`n${MarkerEnd}"

    if (-not (Test-Path $File)) {
        Write-FileContent $File "$injected`n"
        Write-Info "Created $File with seal-team-6 reference"
        return
    }

    $content = Read-FileContent $File

    if ($content -match [regex]::Escape($MarkerBegin)) {
        # Replace existing block between markers
        $pattern = [regex]::Escape($MarkerBegin) + "[\s\S]*?" + [regex]::Escape($MarkerEnd)
        $existingContent = ($content -replace $pattern, "").TrimStart("`r`n").TrimStart("`n")
        if ($existingContent) {
            $newContent = "$injected`n`n$existingContent"
        } else {
            $newContent = "$injected`n"
        }
        Write-FileContent $File $newContent
        Write-Info "Updated seal-team-6 reference in $File"
    }
    else {
        # No existing block — prepend to existing content
        $newContent = "$injected`n`n$content"
        Write-FileContent $File $newContent
        Write-Info "Injected seal-team-6 reference at top of $File"
    }
}

# --- Help ---
if ($Help) {
    Write-Host "Usage: install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Lang LANGS       Comma-separated list of language guides to install"
    Write-Host "                    Default: all (typescript,python,go,rust,java,csharp)"
    Write-Host "  -Version TAG      Pin to a specific git tag or commit hash (default: main)"
    Write-Host "  -Cursor           Generate .cursorrules with seal-team-6 reference"
    Write-Host "  -Windsurf         Generate .windsurfrules with seal-team-6 reference"
    Write-Host "  -Help             Show this help message"
    exit 0
}

# --- Parse Languages ---
if ($Lang) {
    $Languages = $Lang -split ","
} else {
    $Languages = $AllLanguages
}

# --- Pre-flight Checks ---
$projectMarkers = @(".git", "package.json", "pyproject.toml", "go.mod", "Cargo.toml", "pom.xml")
$isProject = $false
foreach ($marker in $projectMarkers) {
    if (Test-Path $marker) {
        $isProject = $true
        break
    }
}

if (-not $isProject) {
    Write-Warn "This doesn't look like a project root. Are you in the right directory?"
    $answer = Read-Host "Continue anyway? [y/N]"
    if ($answer -notmatch "^[yY]") {
        Write-Host "Aborted."
        exit 1
    }
}

Write-Info "Installing seal-team-6 agentic best practices..."

# --- Download canonical agents.md into docs/seal-team-6/ ---
Write-Info "Downloading canonical context file..."
Download-File "$BaseUrl/agents.md" "$DocsDir/agents.md"

# Rewrite docs/ paths in the canonical copy to be relative from docs/seal-team-6/
$agentsContent = Read-FileContent "$DocsDir/agents.md"
$agentsContent = $agentsContent -replace '`docs/agentic/', '`docs/seal-team-6/agentic/'
$agentsContent = $agentsContent -replace '`docs/engineering/', '`docs/seal-team-6/engineering/'
$agentsContent = $agentsContent -replace '`docs/languages/', '`docs/seal-team-6/languages/'

# Strip Operating Principles from canonical copy to avoid duplication with root agents.md
$opPrinciplesIndex = $agentsContent.IndexOf("## Operating Principles")
if ($opPrinciplesIndex -ge 0) {
    $agentsContent = $agentsContent.Substring(0, $opPrinciplesIndex).TrimEnd()
}

Write-FileContent "$DocsDir/agents.md" "$agentsContent`n"

# Verify path rewriting succeeded
$verifyContent = Read-FileContent "$DocsDir/agents.md"
if ($verifyContent -notmatch 'docs/seal-team-6/') {
    Write-Warn "Path rewriting may have failed — verify $DocsDir/agents.md manually"
}

# --- Inject reference into project root agents.md ---
$agentsBlock = @'
# Seal Team 6 — Agentic Best Practices

Read `docs/seal-team-6/agents.md` for foundational agentic principles,
engineering best practices, and language-specific conventions.

These guide new code toward alignment with proven standards.
Existing project patterns are respected for established code —
seal-team-6 only overrides for security issues or harmful patterns.
See the Conflict Resolution section in the canonical file for priority rules.

If `.seal-team-6-overrides.md` exists in the project root, its directives
override specific seal-team-6 defaults while preserving the rest.

---
'@

Inject-Reference "agents.md" $agentsBlock

# --- Inject reference into CLAUDE.md ---
$claudeBlock = @'
# Seal Team 6

Read `docs/seal-team-6/agents.md` — it is the entry point for all agentic guidance.
Always read `docs/seal-team-6/agentic/guardrails.md` before taking any actions.
Follow other references as they become relevant to your current task — do not pre-read all referenced files.

Pay special attention to:
- The stack detection table — load language guides matching this project's stack
- `.seal-team-6-overrides.md` (if it exists) — local overrides take precedence

---
'@

Inject-Reference "CLAUDE.md" $claudeBlock

# --- Download Agentic Guidance (Layer 1) ---
Write-Info "Downloading agentic guidance..."
$agenticFiles = @("guardrails.md", "task-decomposition.md", "tool-usage.md",
                   "context-management.md", "verification.md", "orchestration.md",
                   "continuous-improvement.md")
foreach ($file in $agenticFiles) {
    Download-File "$BaseUrl/docs/agentic/$file" "$DocsDir/agentic/$file"
}

# --- Download Engineering Principles (Layer 2) ---
Write-Info "Downloading engineering principles..."
$engineeringFiles = @("code-quality.md", "testing.md", "architecture.md",
                       "security.md", "git-workflow.md", "error-handling.md",
                       "performance.md")
foreach ($file in $engineeringFiles) {
    Download-File "$BaseUrl/docs/engineering/$file" "$DocsDir/engineering/$file"
}

# --- Download Language Guides (Layer 3) ---
$langFiles = @("idioms.md", "testing.md", "tooling.md")
foreach ($lang in $Languages) {
    Write-Info "Downloading $lang language guide..."
    foreach ($file in $langFiles) {
        Download-File "$BaseUrl/docs/languages/$lang/$file" "$DocsDir/languages/$lang/$file"
    }
}

# --- Override Template ---
if (-not (Test-Path ".seal-team-6-overrides.md")) {
    Download-File "$BaseUrl/docs/overrides.example.md" ".seal-team-6-overrides.example.md"
    Write-Info "Override template saved as .seal-team-6-overrides.example.md"
    Write-Info "Rename to .seal-team-6-overrides.md and edit to customize."
} else {
    Write-Ok "Existing .seal-team-6-overrides.md found — preserved."
}

# --- Cursor / Windsurf (opt-in) ---
$toolReference = "Read and follow docs/seal-team-6/agents.md for agentic best practices."

if ($Cursor) {
    Inject-Reference ".cursorrules" $toolReference
}

if ($Windsurf) {
    Inject-Reference ".windsurfrules" $toolReference
}

# --- Summary ---
Write-Host ""
Write-Ok "seal-team-6 installed successfully!"
Write-Host ""
Write-Info "Installed files:"
Write-Info "  $DocsDir/agents.md  — Canonical agentic context"
Write-Info "  $DocsDir/            — Best practices documentation"
Write-Info "  agents.md               — Injected reference (existing content preserved)"
Write-Info "  CLAUDE.md               — Injected reference (existing content preserved)"
if ($Cursor) {
    Write-Info "  .cursorrules            — Cursor integration"
}
if ($Windsurf) {
    Write-Info "  .windsurfrules          — Windsurf integration"
}

$installedLangs = @()
foreach ($lang in $Languages) {
    if (Test-Path "$DocsDir/languages/$lang") {
        $installedLangs += $lang
    }
}
if ($installedLangs.Count -gt 0) {
    Write-Info ("  Languages: " + ($installedLangs -join " "))
}

Write-Host ""
Write-Info "Recommended: commit docs/seal-team-6/ to version control so all team members share the same standards."
Write-Info "To update, re-run this script. To customize, edit .seal-team-6-overrides.md"

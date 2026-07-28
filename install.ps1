#Requires -Version 5.1
<#
.SYNOPSIS
    Seal Team 6 — Agentic Best Practices Installer (Windows)
.DESCRIPTION
    Installs seal-team-6 agentic best practices into the current project directory.
.EXAMPLE
    irm https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1 -Lang typescript,python -Version v1.1.0 -Cursor
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
        $newContent = "$injected`n`n$content"
        Write-FileContent $File $newContent
        Write-Info "Injected seal-team-6 reference at top of $File"
    }
}

function Detect-Languages {
    $found = New-Object System.Collections.Generic.List[string]
    if ((Test-Path "package.json") -or (Test-Path "tsconfig.json")) { [void]$found.Add("typescript") }
    if ((Test-Path "pyproject.toml") -or (Test-Path "setup.py") -or (Test-Path "requirements.txt")) { [void]$found.Add("python") }
    if (Test-Path "go.mod") { [void]$found.Add("go") }
    if (Test-Path "Cargo.toml") { [void]$found.Add("rust") }
    if ((Test-Path "pom.xml") -or (Test-Path "build.gradle") -or (Test-Path "build.gradle.kts")) { [void]$found.Add("java") }
    if ((Test-Path "global.json") -or (Get-ChildItem -Path . -Filter *.csproj -File -ErrorAction SilentlyContinue) -or (Get-ChildItem -Path . -Filter *.sln -File -ErrorAction SilentlyContinue)) {
        [void]$found.Add("csharp")
    }
    return ,$found.ToArray()
}

function Write-CursorRule {
    $dir = ".cursor/rules"
    $file = Join-Path $dir "seal-team-6.mdc"
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $content = @'
---
description: Seal Team 6 agentic best practices entrypoint
alwaysApply: true
---

Read `docs/seal-team-6/agents.md` for agentic principles, engineering standards, and language guides.
Always read `docs/seal-team-6/agentic/guardrails.md` before destructive or high-blast-radius actions.
Do not pre-read every referenced file — follow the Loading Strategy in the entrypoint.
If `.project-context.md` exists, its directives take precedence for matching topics.
'@
    Write-FileContent $file $content
    Write-Info "Wrote $file (Cursor rules)"
}

# --- Help ---
if ($Help) {
    Write-Host "Usage: install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Lang LANGS       Comma-separated language guides, or 'all'"
    Write-Host "                    Default: auto-detect from project markers"
    Write-Host "                    Available: typescript,python,go,rust,java,csharp"
    Write-Host "  -Version TAG      Pin to a git tag or commit (recommended; default: main)"
    Write-Host "  -Cursor           Write .cursor/rules/seal-team-6.mdc"
    Write-Host "  -Windsurf         Inject reference into .windsurfrules"
    Write-Host "  -Help             Show this help message"
    exit 0
}

# --- Parse Languages ---
if ($Lang -eq "all") {
    $Languages = $AllLanguages
    Write-Info "Installing all language guides"
}
elseif ($Lang) {
    $Languages = @($Lang -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
else {
    $Languages = Detect-Languages
    if ($Languages.Count -eq 0) {
        Write-Warn "No language markers detected — skipping Layer 3 language guides."
        Write-Warn "Pass -Lang typescript,python or -Lang all to install them."
    }
    else {
        Write-Info ("Auto-detected languages: " + ($Languages -join " "))
    }
}

if ($Version -eq "main") {
    Write-Warn "Installing from floating 'main'. Prefer -Version <tag> once releases exist (see CHANGELOG.md)."
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

$agentsContent = Read-FileContent "$DocsDir/agents.md"
$agentsContent = $agentsContent -replace '`docs/agentic/', '`docs/seal-team-6/agentic/'
$agentsContent = $agentsContent -replace '`docs/engineering/', '`docs/seal-team-6/engineering/'
$agentsContent = $agentsContent -replace '`docs/languages/', '`docs/seal-team-6/languages/'

$opPrinciplesIndex = $agentsContent.IndexOf("## Operating Principles")
if ($opPrinciplesIndex -ge 0) {
    $agentsContent = $agentsContent.Substring(0, $opPrinciplesIndex).TrimEnd()
}

Write-FileContent "$DocsDir/agents.md" "$agentsContent`n"

$verifyContent = Read-FileContent "$DocsDir/agents.md"
if ($verifyContent -notmatch 'docs/seal-team-6/') {
    Write-Warn "Path rewriting may have failed — verify $DocsDir/agents.md manually"
}

$agentsBlock = @'
# Seal Team 6 — Agentic Best Practices

Read `docs/seal-team-6/agents.md` for foundational agentic principles,
engineering best practices, and language-specific conventions.

These guide new code toward alignment with proven standards.
Existing project patterns are respected for established code —
seal-team-6 only overrides for security issues or harmful patterns.
See the Conflict Resolution section in the canonical file for priority rules.

If `.project-context.md` exists in the project root, its directives
extend or override specific seal-team-6 defaults while preserving the rest.

---
'@

Inject-Reference "AGENTS.md" $agentsBlock
Inject-Reference "agents.md" $agentsBlock

$claudeBlock = @'
# Seal Team 6

Read `docs/seal-team-6/agents.md` — it is the entry point for all agentic guidance.
Always read `docs/seal-team-6/agentic/guardrails.md` before taking any actions.
Follow other references as they become relevant to your current task — do not pre-read all referenced files.

Pay special attention to:
- The stack detection table — load language guides matching this project's stack
- `.project-context.md` (if it exists) — project-specific context takes precedence

---
'@

Inject-Reference "CLAUDE.md" $claudeBlock

Write-Info "Downloading agentic guidance..."
$agenticFiles = @("guardrails.md", "task-decomposition.md", "tool-usage.md",
                   "context-management.md", "verification.md", "orchestration.md",
                   "continuous-improvement.md", "health-snapshot.md",
                   "untrusted-input.md", "modes.md")
foreach ($file in $agenticFiles) {
    Download-File "$BaseUrl/docs/agentic/$file" "$DocsDir/agentic/$file"
}

Write-Info "Downloading engineering principles..."
$engineeringFiles = @("code-quality.md", "testing.md", "architecture.md",
                       "security.md", "git-workflow.md", "error-handling.md",
                       "performance.md")
foreach ($file in $engineeringFiles) {
    Download-File "$BaseUrl/docs/engineering/$file" "$DocsDir/engineering/$file"
}

$langFiles = @("idioms.md", "testing.md", "tooling.md")
foreach ($lang in $Languages) {
    Write-Info "Downloading $lang language guide..."
    foreach ($file in $langFiles) {
        Download-File "$BaseUrl/docs/languages/$lang/$file" "$DocsDir/languages/$lang/$file"
    }
}

if (-not (Test-Path ".project-context.md")) {
    Download-File "$BaseUrl/docs/project-context.example.md" ".project-context.example.md"
    Write-Info "Project context template saved as .project-context.example.md"
    Write-Info "Rename to .project-context.md and edit to customize."
} else {
    Write-Ok "Existing .project-context.md found — preserved."
}

if (-not (Test-Path "TECH_DEBT.md")) {
    Download-File "$BaseUrl/docs/tech-debt.example.md" "TECH_DEBT.example.md"
    Write-Info "Debt template saved as TECH_DEBT.example.md (rename to TECH_DEBT.md to activate)."
}

if ($Cursor) {
    Write-CursorRule
}

if ($Windsurf) {
    Inject-Reference ".windsurfrules" "Read and follow docs/seal-team-6/agents.md for agentic best practices."
}

Write-Host ""
Write-Ok "seal-team-6 installed successfully!"
Write-Host ""
Write-Info "Installed files:"
Write-Info "  $DocsDir/agents.md  — Canonical agentic context"
Write-Info "  $DocsDir/            — Best practices documentation"
Write-Info "  AGENTS.md / agents.md   — Injected reference (existing content preserved)"
Write-Info "  CLAUDE.md               — Injected reference (existing content preserved)"
if ($Cursor) {
    Write-Info "  .cursor/rules/seal-team-6.mdc — Cursor integration"
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
} else {
    Write-Info "  Languages: (none — use -Lang ...)"
}

Write-Host ""
Write-Info "Recommended: commit docs/seal-team-6/ to version control so all team members share the same standards."
Write-Info "Pin installs with -Version <tag>. Customize via .project-context.md"

#Requires -Version 5.1
<#
.SYNOPSIS
    Seal Team 6 — Agentic Best Practices Installer (Windows)
.DESCRIPTION
    Installs seal-team-6 agentic best practices into the current project directory.
    Supports -Local, -DryRun, -Uninstall, checksum verify, and host adapters.
.EXAMPLE
    irm https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1 -Local -Lang typescript -Cursor -Verify
.EXAMPLE
    .\install.ps1 -Uninstall -UninstallDocs
#>

param(
    [string]$Lang = "",
    [string]$Version = "main",
    [string]$Source = "",
    [switch]$Local,
    [switch]$Cursor,
    [switch]$Windsurf,
    [switch]$Continue,
    [switch]$Aider,
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$UninstallDocs,
    [switch]$NoBackup,
    [switch]$Verify,
    [switch]$NoVerify,
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
$AgenticFiles = @("guardrails.md", "task-decomposition.md", "tool-usage.md",
    "context-management.md", "verification.md", "orchestration.md",
    "continuous-improvement.md", "health-snapshot.md", "untrusted-input.md", "modes.md")
$EngineeringFiles = @("code-quality.md", "testing.md", "architecture.md",
    "security.md", "git-workflow.md", "error-handling.md", "performance.md")
$LangFiles = @("idioms.md", "testing.md", "tooling.md")
$MarkerBegin = "<!-- BEGIN seal-team-6 -->"
$MarkerEnd = "<!-- END seal-team-6 -->"
$BackupRoot = ".seal-team-6-backup"
$PackVersion = "1.0.0"
$DefaultVersion = "1.0.0"
$script:BackupDir = $null
$LocalSource = $null

$DoVerify = -not $NoVerify
if ($Verify) { $DoVerify = $true }

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Resolve-PathSafe {
    param([string]$Path)
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Write-FileContent {
    param([string]$Path, [string]$Content)
    $full = Resolve-PathSafe $Path
    $dir = Split-Path -Parent $full
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $tmp = "$full.tmp.$PID"
    [System.IO.File]::WriteAllText($tmp, $Content, $Utf8NoBom)
    Move-Item -LiteralPath $tmp -Destination $full -Force
}

function Read-FileContent {
    param([string]$Path)
    [System.IO.File]::ReadAllText((Resolve-PathSafe $Path), [System.Text.Encoding]::UTF8)
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

function Ensure-BackupDir {
    if (-not $script:BackupDir) {
        $stamp = Get-Date -Format "yyyyMMddTHHmmss"
        $script:BackupDir = Join-Path $BackupRoot $stamp
    }
    if (-not (Test-Path $script:BackupDir)) {
        New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
    }
}

function Backup-File {
    param([string]$File)
    if ($NoBackup -or $DryRun) { return }
    if (-not (Test-Path $File)) { return }
    Ensure-BackupDir
    $dest = Join-Path $script:BackupDir $File
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $File -Destination $dest -Force
    Write-Info "Backed up $File → $dest"
}

function Get-LocalSource {
    if ($env:SEAL_TEAM_6_ROOT) { return $env:SEAL_TEAM_6_ROOT }
    if ($PSScriptRoot) { return $PSScriptRoot }
    return (Get-Location).Path
}

function Fetch-File {
    param([string]$Rel, [string]$Dest)
    if ($DryRun) {
        Write-Info "[dry-run] would fetch $Rel → $Dest"
        return
    }
    $dir = Split-Path -Parent $Dest
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if ($LocalSource) {
        $src = Join-Path $LocalSource $Rel
        if (-not (Test-Path $src)) {
            throw "Local source missing: $src"
        }
        Copy-Item -LiteralPath $src -Destination $Dest -Force
        return
    }
    $url = "$BaseUrl/$Rel"
    try {
        Invoke-WebRequest -Uri $url -OutFile $Dest -UseBasicParsing -ErrorAction Stop
    }
    catch {
        throw "Failed to download ${url}: $_"
    }
}

function Try-Fetch {
    param([string]$Rel, [string]$Dest)
    try {
        Fetch-File -Rel $Rel -Dest $Dest
        return $true
    }
    catch {
        return $false
    }
}

function Import-Manifest {
    param([string]$Path)
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        if ($line -match '^(VERSION|AGENTIC_FILES|ENGINEERING_FILES|LANG_FILES|ALL_LANGUAGES)=(.*)$') {
            $key = $Matches[1]
            $val = $Matches[2].Trim().Trim('"').Trim("'")
            switch ($key) {
                "VERSION" { $script:PackVersion = $val }
                "AGENTIC_FILES" { $script:AgenticFiles = @($val -split '\s+' | Where-Object { $_ }) }
                "ENGINEERING_FILES" { $script:EngineeringFiles = @($val -split '\s+' | Where-Object { $_ }) }
                "LANG_FILES" { $script:LangFiles = @($val -split '\s+' | Where-Object { $_ }) }
                "ALL_LANGUAGES" { $script:AllLanguages = @($val -split '\s+' | Where-Object { $_ }) }
            }
        }
    }
}

function Strip-Markers {
    param([string]$Content)
    $pattern = [regex]::Escape($MarkerBegin) + "[\s\S]*?" + [regex]::Escape($MarkerEnd)
    return ($Content -replace $pattern, "").TrimStart("`r", "`n")
}

function Inject-Reference {
    param([string]$File, [string]$Block)
    $injected = "${MarkerBegin}`n${Block}`n${MarkerEnd}"

    if ($DryRun) {
        if (Test-Path $File) {
            Write-Info "[dry-run] would update seal-team-6 block in $File"
        } else {
            Write-Info "[dry-run] would create $File with seal-team-6 reference"
        }
        return
    }

    if (-not (Test-Path $File)) {
        Write-FileContent $File "$injected`n"
        Write-Info "Created $File with seal-team-6 reference"
        return
    }

    Backup-File $File
    $content = Read-FileContent $File

    if ($content -match [regex]::Escape($MarkerBegin)) {
        $existing = (Strip-Markers $content).TrimStart()
        if ($existing) {
            Write-FileContent $File "$injected`n`n$existing"
        } else {
            Write-FileContent $File "$injected`n"
        }
        Write-Info "Updated seal-team-6 reference in $File"
    }
    else {
        Write-FileContent $File "$injected`n`n$content"
        Write-Info "Injected seal-team-6 reference at top of $File"
    }
}

function Remove-MarkersFromFile {
    param([string]$File)
    if (-not (Test-Path $File)) { return }
    $content = Read-FileContent $File
    if ($content -notmatch [regex]::Escape($MarkerBegin)) { return }
    if ($DryRun) {
        Write-Info "[dry-run] would remove seal-team-6 block from $File"
        return
    }
    Backup-File $File
    $remaining = (Strip-Markers $content).Trim()
    if ($remaining) {
        Write-FileContent $File "$remaining`n"
    } else {
        Write-FileContent $File "<!-- seal-team-6 uninstalled; add project agent instructions here -->`n"
    }
    Write-Info "Removed seal-team-6 reference from $File"
}

function Detect-Languages {
    $found = New-Object System.Collections.Generic.List[string]
    if ((Test-Path "package.json") -or (Test-Path "tsconfig.json")) { [void]$found.Add("typescript") }
    if ((Test-Path "pyproject.toml") -or (Test-Path "setup.py") -or (Test-Path "requirements.txt")) { [void]$found.Add("python") }
    if (Test-Path "go.mod") { [void]$found.Add("go") }
    if (Test-Path "Cargo.toml") { [void]$found.Add("rust") }
    if ((Test-Path "pom.xml") -or (Test-Path "build.gradle") -or (Test-Path "build.gradle.kts")) { [void]$found.Add("java") }
    if ((Test-Path "global.json") -or
        (Get-ChildItem -Path . -Filter *.csproj -File -ErrorAction SilentlyContinue) -or
        (Get-ChildItem -Path . -Filter *.sln -File -ErrorAction SilentlyContinue)) {
        [void]$found.Add("csharp")
    }
    return , $found.ToArray()
}

function Test-ProjectRoot {
    $markers = @(
        ".git", "package.json", "tsconfig.json", "pyproject.toml", "setup.py", "requirements.txt",
        "go.mod", "Cargo.toml", "pom.xml", "build.gradle", "build.gradle.kts", "global.json"
    )
    foreach ($m in $markers) {
        if (Test-Path $m) { return $true }
    }
    if (Get-ChildItem -Path . -Filter *.csproj -File -ErrorAction SilentlyContinue) { return $true }
    if (Get-ChildItem -Path . -Filter *.sln -File -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Ensure-GitignoreBackupEntry {
    if ($DryRun) { return }
    $entry = ".seal-team-6-backup/"
    if (-not (Test-Path ".git")) { return }
    if (Test-Path ".gitignore") {
        $gi = Read-FileContent ".gitignore"
        if ($gi -notmatch "seal-team-6-backup") {
            Backup-File ".gitignore"
            $new = $gi.TrimEnd() + "`n`n# seal-team-6 installer backups`n$entry`n"
            Write-FileContent ".gitignore" $new
            Write-Info "Added $entry to .gitignore"
        }
    }
    else {
        Write-FileContent ".gitignore" "# seal-team-6 installer backups`n$entry`n"
        Write-Info "Created .gitignore with $entry"
    }
}

function Write-CursorRule {
    $dir = ".cursor/rules"
    $file = Join-Path $dir "seal-team-6.mdc"
    if ($DryRun) {
        Write-Info "[dry-run] would write $file"
        return
    }
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path $file) { Backup-File $file }
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

function Write-ContinueRule {
    $dir = ".continue/rules"
    $file = Join-Path $dir "seal-team-6.md"
    if ($DryRun) {
        Write-Info "[dry-run] would write $file"
        return
    }
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path $file) { Backup-File $file }
    $content = @'
# Seal Team 6

Read `docs/seal-team-6/agents.md` for agentic principles, engineering standards, and language guides.
Always read `docs/seal-team-6/agentic/guardrails.md` before destructive or high-blast-radius actions.
Follow the Loading Strategy — do not pre-read every referenced file.
If `.project-context.md` exists, its directives take precedence for matching topics.
'@
    Write-FileContent $file $content
    Write-Info "Wrote $file (Continue rules)"
}

function Write-AiderConf {
    $file = ".aider.conf.yml"
    $block = @"
# seal-team-6
read:
  - docs/seal-team-6/agents.md
  - docs/seal-team-6/agentic/guardrails.md
"@
    if ($DryRun) {
        Write-Info "[dry-run] would ensure aider read paths in $file"
        return
    }
    if (Test-Path $file) {
        $existing = Read-FileContent $file
        if ($existing -match "docs/seal-team-6/agents.md") {
            Write-Info "Aider config already references seal-team-6"
            return
        }
        Backup-File $file
        Write-FileContent $file ($existing.TrimEnd() + "`n`n" + $block + "`n")
        Write-Info "Appended seal-team-6 read paths to $file"
    }
    else {
        Write-FileContent $file "$block`n"
        Write-Info "Wrote $file (Aider)"
    }
}

function Rewrite-CanonicalAgents {
    $file = Join-Path $DocsDir "agents.md"
    if ($DryRun -or -not (Test-Path $file)) { return }
    $content = Read-FileContent $file
    $content = $content -replace '`docs/agentic/', '`docs/seal-team-6/agentic/'
    $content = $content -replace '`docs/engineering/', '`docs/seal-team-6/engineering/'
    $content = $content -replace '`docs/languages/', '`docs/seal-team-6/languages/'
    $idx = $content.IndexOf("## Operating Principles")
    if ($idx -ge 0) {
        $content = $content.Substring(0, $idx).TrimEnd()
    }
    Write-FileContent $file "$content`n"
    $verify = Read-FileContent $file
    if ($verify -notmatch 'docs/seal-team-6/') {
        Write-Warn "Path rewriting may have failed — verify $file manually"
    }
}

function Invoke-Uninstall {
    Write-Info "Uninstalling seal-team-6 references..."
    Ensure-GitignoreBackupEntry
    foreach ($f in @("AGENTS.md", "agents.md", "CLAUDE.md", ".windsurfrules")) {
        Remove-MarkersFromFile $f
    }
    $cursor = ".cursor/rules/seal-team-6.mdc"
    if (Test-Path $cursor) {
        if ($DryRun) {
            Write-Info "[dry-run] would remove $cursor"
        } else {
            Backup-File $cursor
            Remove-Item -LiteralPath $cursor -Force
            Write-Info "Removed $cursor"
        }
    }
    $cont = ".continue/rules/seal-team-6.md"
    if (Test-Path $cont) {
        if ($DryRun) {
            Write-Info "[dry-run] would remove $cont"
        } else {
            Backup-File $cont
            Remove-Item -LiteralPath $cont -Force
            Write-Info "Removed $cont"
        }
    }
    if ((Test-Path ".aider.conf.yml") -and ((Read-FileContent ".aider.conf.yml") -match "seal-team-6")) {
        Write-Warn "Left .aider.conf.yml in place (may contain other settings). Remove seal-team-6 read paths manually if desired."
    }
    if ($UninstallDocs -and (Test-Path $DocsDir)) {
        if ($DryRun) {
            Write-Info "[dry-run] would remove $DocsDir/"
        } else {
            $ver = Join-Path $DocsDir "VERSION"
            if (Test-Path $ver) { Backup-File $ver }
            Remove-Item -LiteralPath $DocsDir -Recurse -Force
            Write-Info "Removed $DocsDir/"
        }
    }
    else {
        Write-Info "Left $DocsDir/ in place (pass -UninstallDocs to remove)"
    }
    $b = if ($script:BackupDir) { $script:BackupDir } else { "none" }
    Write-Ok "Uninstall complete. Backups (if any): $b"
    Write-Info "Preserved: .project-context.md, TECH_DEBT.md (if present)"
}

# --- Help ---
if ($Help) {
    Write-Host @"
Usage: install.ps1 [OPTIONS]

Options:
  -Lang LANGS        Comma-separated language guides, or 'all'
  -Version TAG       Pin to a git tag or commit (recommended; default: main)
  -Local             Install from this repo checkout (dev/CI)
  -Source DIR        Install from a local directory tree
  -Cursor            Write .cursor/rules/seal-team-6.mdc
  -Windsurf          Inject reference into .windsurfrules
  -Continue          Write .continue/rules/seal-team-6.md
  -Aider             Ensure .aider.conf.yml reads seal-team-6 entrypoints
  -DryRun            Print actions without writing files
  -Uninstall         Remove managed marker blocks and host rules
  -UninstallDocs     With -Uninstall, also remove docs/seal-team-6/
  -NoBackup          Do not write .seal-team-6-backup/ snapshots
  -Verify            Verify checksums when available (default unless -NoVerify)
  -NoVerify          Skip checksum verification
  -Help              Show this help

Safety:
  Existing host files are backed up under .seal-team-6-backup/<timestamp>/
  docs/seal-team-6/ is fully overwritten on reinstall (not merged).
  .project-context.md and TECH_DEBT.md are never overwritten.
"@
    exit 0
}

# Resolve local source
if ($Local) {
    $LocalSource = Get-LocalSource
}
if ($Source) {
    $LocalSource = $Source
}

if ($Uninstall) {
    Invoke-Uninstall
    exit 0
}

# Load manifest
if ($LocalSource) {
    $man = Join-Path $LocalSource "manifest.conf"
    if (-not (Test-Path $man)) { throw "manifest.conf not found in $LocalSource" }
    Import-Manifest $man
    Write-Info "Using local source: $LocalSource"
}
else {
    $mtmp = Join-Path ([System.IO.Path]::GetTempPath()) ("st6-manifest-" + [guid]::NewGuid().ToString() + ".conf")
    try {
        if (Try-Fetch -Rel "manifest.conf" -Dest $mtmp) {
            Import-Manifest $mtmp
        }
        else {
            Write-Warn "Could not load remote manifest.conf — using built-in file lists"
        }
    }
    finally {
        if (Test-Path $mtmp) { Remove-Item $mtmp -Force -ErrorAction SilentlyContinue }
    }
}

# Languages
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

if ($Version -eq "main" -and -not $LocalSource) {
    Write-Warn "Installing from floating 'main'. Prefer -Version <tag> (see CHANGELOG.md / VERSION)."
}

if (-not (Test-ProjectRoot)) {
    Write-Warn "This doesn't look like a project root. Are you in the right directory?"
    if ($DryRun) {
        Write-Warn "[dry-run] continuing without prompt"
    }
    else {
        $answer = Read-Host "Continue anyway? [y/N]"
        if ($answer -notmatch "^[yY]") {
            Write-Host "Aborted."
            exit 1
        }
    }
}

Write-Info "Installing seal-team-6 v$PackVersion..."
if ($DryRun) { Write-Warn "Dry-run mode — no files will be written" }

Ensure-GitignoreBackupEntry

Write-Info "Downloading canonical context file..."
Fetch-File -Rel "agents.md" -Dest (Join-Path $DocsDir "agents.md")
Rewrite-CanonicalAgents

if (-not $DryRun) {
    Write-FileContent (Join-Path $DocsDir "VERSION") "$PackVersion`n"
    Write-Info "Wrote $DocsDir/VERSION ($PackVersion)"
}
else {
    Write-Info "[dry-run] would write $DocsDir/VERSION ($PackVersion)"
}

$agentsBlock = @"
# Seal Team 6 — Agentic Best Practices

Read ``docs/seal-team-6/agents.md`` for foundational agentic principles,
engineering best practices, and language-specific conventions.

Installed pack version: see ``docs/seal-team-6/VERSION``.

These guide new code toward alignment with proven standards.
Existing project patterns are respected for established code —
seal-team-6 only overrides for security issues or harmful patterns.
See the Conflict Resolution section in the canonical file for priority rules.

If ``.project-context.md`` exists in the project root, its directives
extend or override specific seal-team-6 defaults while preserving the rest.

---
"@

$claudeBlock = @"
# Seal Team 6

Read ``docs/seal-team-6/agents.md`` — it is the entry point for all agentic guidance.
Always read ``docs/seal-team-6/agentic/guardrails.md`` before taking any actions.
Follow other references as they become relevant to your current task — do not pre-read all referenced files.

Pack version: see ``docs/seal-team-6/VERSION``.

Pay special attention to:
- The stack detection table — load language guides matching this project's stack
- ``.project-context.md`` (if it exists) — project-specific context takes precedence

---
"@

# Case-insensitive FS (common on Windows/macOS): AGENTS.md and agents.md may be one file.
$hasAgentsUpper = Test-Path "AGENTS.md"
$hasAgentsLower = Test-Path "agents.md"
$sameAgentsFile = $false
if ($hasAgentsUpper -and $hasAgentsLower) {
    try {
        $i1 = (Get-Item -LiteralPath "AGENTS.md").FullName
        $i2 = (Get-Item -LiteralPath "agents.md").FullName
        $sameAgentsFile = ($i1 -eq $i2)
    } catch { $sameAgentsFile = $true }
}
if ($sameAgentsFile -or ($hasAgentsUpper -and -not $hasAgentsLower)) {
    Inject-Reference "AGENTS.md" $agentsBlock
}
elseif ($hasAgentsLower -and -not $hasAgentsUpper) {
    Inject-Reference "agents.md" $agentsBlock
}
elseif ($hasAgentsUpper -and $hasAgentsLower) {
    Inject-Reference "AGENTS.md" $agentsBlock
    Inject-Reference "agents.md" $agentsBlock
}
else {
    Inject-Reference "AGENTS.md" $agentsBlock
}

Inject-Reference "CLAUDE.md" $claudeBlock

Write-Info "Downloading agentic guidance..."
foreach ($file in $AgenticFiles) {
    Fetch-File -Rel "docs/agentic/$file" -Dest (Join-Path $DocsDir "agentic/$file")
}

Write-Info "Downloading engineering principles..."
foreach ($file in $EngineeringFiles) {
    Fetch-File -Rel "docs/engineering/$file" -Dest (Join-Path $DocsDir "engineering/$file")
}

foreach ($lang in $Languages) {
    Write-Info "Downloading $lang language guide..."
    foreach ($file in $LangFiles) {
        Fetch-File -Rel "docs/languages/$lang/$file" -Dest (Join-Path $DocsDir "languages/$lang/$file")
    }
}

if (-not (Test-Path ".project-context.md")) {
    Fetch-File -Rel "docs/project-context.example.md" -Dest ".project-context.example.md"
    Write-Info "Project context template saved as .project-context.example.md"
    Write-Info "Rename to .project-context.md and edit to customize."
}
else {
    Write-Ok "Existing .project-context.md found — preserved."
}

if (-not (Test-Path "TECH_DEBT.md")) {
    Fetch-File -Rel "docs/tech-debt.example.md" -Dest "TECH_DEBT.example.md"
    Write-Info "Debt template saved as TECH_DEBT.example.md (rename to TECH_DEBT.md to activate)."
}

if ($Cursor) { Write-CursorRule }
if ($Windsurf) {
    Inject-Reference ".windsurfrules" "Read and follow docs/seal-team-6/agents.md for agentic best practices. Pack version: docs/seal-team-6/VERSION."
}
if ($Continue) { Write-ContinueRule }
if ($Aider) { Write-AiderConf }

if ($DoVerify -and -not $DryRun) {
    $ctmp = Join-Path ([System.IO.Path]::GetTempPath()) ("st6-sum-" + [guid]::NewGuid().ToString())
    $have = $false
    if ($LocalSource -and (Test-Path (Join-Path $LocalSource "checksums.sha256"))) {
        Copy-Item (Join-Path $LocalSource "checksums.sha256") $ctmp -Force
        $have = $true
    }
    elseif (Try-Fetch -Rel "checksums.sha256" -Dest $ctmp) {
        $have = $true
    }
    if (-not $have) {
        Write-Warn "checksums.sha256 not available — skip integrity verify (pin a release tag that includes it)"
    }
    else {
        Write-Info "Verifying downloaded pack against checksums.sha256..."
        $fail = 0
        Get-Content $ctmp | ForEach-Object {
            if ($_ -match '^\s*$' -or $_.StartsWith("#")) { return }
            $parts = $_ -split '\s+', 2
            if ($parts.Count -lt 2) { return }
            $hash = $parts[0]
            $path = $parts[1].Trim()
            $localPath = $null
            if ($path -eq "agents.md") { return } # rewritten after install
            elseif ($path -eq "VERSION") { $localPath = Join-Path $DocsDir "VERSION" }
            elseif ($path -like "docs/agentic/*") { $localPath = Join-Path $DocsDir ("agentic/" + [IO.Path]::GetFileName($path)) }
            elseif ($path -like "docs/engineering/*") { $localPath = Join-Path $DocsDir ("engineering/" + [IO.Path]::GetFileName($path)) }
            elseif ($path -like "docs/languages/*") {
                $rest = $path.Substring("docs/languages/".Length)
                $localPath = Join-Path $DocsDir "languages/$rest"
            }
            elseif ($path -eq "docs/project-context.example.md") {
                $localPath = ".project-context.example.md"
                if (-not (Test-Path $localPath)) { return }
            }
            elseif ($path -eq "docs/tech-debt.example.md") {
                $localPath = "TECH_DEBT.example.md"
                if (-not (Test-Path $localPath)) { return }
            }
            else { return }

            if (-not $localPath -or -not (Test-Path $localPath)) { return }
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $bytes = [System.IO.File]::ReadAllBytes((Resolve-PathSafe $localPath))
            $actual = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
            $sha.Dispose()
            if ($actual -ne $hash.ToLowerInvariant()) {
                Write-Warn "Checksum mismatch: $localPath"
                $script:failCount = 1
                $fail++
            }
        }
        Remove-Item $ctmp -Force -ErrorAction SilentlyContinue
        if ($fail -gt 0) {
            throw "$fail checksum mismatch(es). Re-install from a clean tag or use -NoVerify."
        }
        Write-Ok "Integrity checks passed for installed files"
    }
}

Write-Host ""
if ($DryRun) {
    Write-Ok "Dry-run complete (seal-team-6 v$PackVersion) — no files written"
}
else {
    Write-Ok "seal-team-6 v$PackVersion installed successfully!"
}
Write-Host ""
Write-Info "Installed files:"
Write-Info "  $DocsDir/VERSION     — Pack version pin"
Write-Info "  $DocsDir/agents.md   — Canonical agentic context"
Write-Info "  $DocsDir/            — Best practices documentation"
Write-Info "  Host entrypoints     — AGENTS.md / agents.md / CLAUDE.md (as applicable)"
if ($script:BackupDir) {
    Write-Info "  Backups              — $($script:BackupDir)/"
}
if ($Cursor) { Write-Info "  .cursor/rules/seal-team-6.mdc — Cursor" }
if ($Windsurf) { Write-Info "  .windsurfrules — Windsurf" }
if ($Continue) { Write-Info "  .continue/rules/seal-team-6.md — Continue" }
if ($Aider) { Write-Info "  .aider.conf.yml — Aider" }

$installedLangs = @()
foreach ($lang in $Languages) {
    if ($DryRun -or (Test-Path (Join-Path $DocsDir "languages/$lang"))) {
        $installedLangs += $lang
    }
}
if ($installedLangs.Count -gt 0) {
    Write-Info ("  Languages: " + ($installedLangs -join " "))
}
else {
    Write-Info "  Languages: (none — use -Lang ...)"
}

Write-Host ""
Write-Info "docs/seal-team-6/ is fully refreshed on each install (not merged)."
Write-Info "Recommended: commit $DocsDir/ so the team shares the same standards."
Write-Info "Pin installs with -Version <tag>. Customize via .project-context.md"
Write-Info "Uninstall: install.ps1 -Uninstall [-UninstallDocs]"

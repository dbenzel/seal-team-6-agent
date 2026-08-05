#!/bin/sh
# Seal Team 6 — Agentic Best Practices Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.sh | sh
# Prefer: ... | sh -s -- --version=vX.Y.Z
# Local/CI: ./install.sh --local --lang=typescript
# Uninstall: ./install.sh --uninstall [--uninstall-docs]

set -e

# --- Configuration ---
REPO="dbenzel/seal-team-6-agent"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
DOCS_DIR="docs/seal-team-6"
# Managed markers (legacy BEGIN/END seal-team-6 still matched for reinstalls)
MARKER_BEGIN="<!-- BEGIN seal-team-6 -->"
MARKER_END="<!-- END seal-team-6 -->"
BACKUP_ROOT=".seal-team-6-backup"
DEFAULT_VERSION="1.0.0"

# Defaults (overridden by manifest when available)
ALL_LANGUAGES="typescript python go rust java csharp"
AGENTIC_FILES="guardrails.md task-decomposition.md tool-usage.md context-management.md verification.md orchestration.md continuous-improvement.md health-snapshot.md untrusted-input.md modes.md"
ENGINEERING_FILES="code-quality.md testing.md architecture.md security.md git-workflow.md error-handling.md performance.md"
LANG_FILES="idioms.md testing.md tooling.md"
PACK_VERSION="$DEFAULT_VERSION"

# --- Colors ---
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

info()  { printf "${BLUE}[seal-team-6]${NC} %s\n" "$1"; }
ok()    { printf "${GREEN}[seal-team-6]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[seal-team-6]${NC} %s\n" "$1"; }
die()   { printf "Error: %s\n" "$1" >&2; exit 1; }

# --- Atomic write: content on stdin → path ---
atomic_write() {
  dest="$1"
  dir=$(dirname "$dest")
  mkdir -p "$dir"
  tmp="${dest}.tmp.$$"
  cat > "$tmp"
  mv -f "$tmp" "$dest"
}

# --- Backup existing file into timestamped dir ---
BACKUP_DIR=""
ensure_backup_dir() {
  if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="${BACKUP_ROOT}/$(date +%Y%m%dT%H%M%S)"
  fi
  mkdir -p "$BACKUP_DIR"
}

backup_file() {
  file="$1"
  [ "$NO_BACKUP" = "true" ] && return 0
  [ "$DRY_RUN" = "true" ] && return 0
  [ ! -f "$file" ] && return 0
  ensure_backup_dir
  # Preserve relative path under backup dir
  bdest="${BACKUP_DIR}/${file}"
  mkdir -p "$(dirname "$bdest")"
  cp "$file" "$bdest"
  info "Backed up $file → $bdest"
}

# --- Download or local copy ---
fetch() {
  # fetch <repo-relative-path> <dest>
  rel="$1"
  dest="$2"
  dir=$(dirname "$dest")
  mkdir -p "$dir"

  if [ "$DRY_RUN" = "true" ]; then
    info "[dry-run] would fetch $rel → $dest"
    return 0
  fi

  if [ -n "$LOCAL_SOURCE" ]; then
    src="${LOCAL_SOURCE}/${rel}"
    if [ ! -f "$src" ]; then
      die "Local source missing: $src"
    fi
    cp "$src" "$dest"
    return 0
  fi

  url="${BASE_URL}/${rel}"
  errf=$(mktemp)
  if command -v curl > /dev/null 2>&1; then
    if ! curl -fsSL "$url" -o "$dest" 2>"$errf"; then
      msg=$(cat "$errf" 2>/dev/null || true)
      rm -f "$errf"
      die "Failed to download $url${msg:+ ($msg)}"
    fi
  elif command -v wget > /dev/null 2>&1; then
    if ! wget -q "$url" -O "$dest" 2>"$errf"; then
      msg=$(cat "$errf" 2>/dev/null || true)
      rm -f "$errf"
      die "Failed to download $url${msg:+ ($msg)}"
    fi
  else
    rm -f "$errf"
    die "neither curl nor wget found. Install one and retry."
  fi
  rm -f "$errf"
}

# Soft fetch (returns non-zero on failure, no die)
fetch_soft() {
  rel="$1"
  dest="$2"
  if [ -n "$LOCAL_SOURCE" ]; then
    [ -f "${LOCAL_SOURCE}/${rel}" ] || return 1
    cp "${LOCAL_SOURCE}/${rel}" "$dest"
    return 0
  fi
  url="${BASE_URL}/${rel}"
  if command -v curl > /dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest" 2>/dev/null
  elif command -v wget > /dev/null 2>&1; then
    wget -q "$url" -O "$dest" 2>/dev/null
  else
    return 1
  fi
}

# Strip managed block(s) from content on stdin; print remainder
strip_markers() {
  awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    $0 ~ b { skip=1; next }
    $0 ~ e { skip=0; next }
    !skip { print }
  '
}

# Inject reference block into a host file (backup + atomic)
inject_reference() {
  file="$1"
  block="$2"
  injected="${MARKER_BEGIN}
${block}
${MARKER_END}"

  if [ "$DRY_RUN" = "true" ]; then
    if [ -f "$file" ]; then
      info "[dry-run] would update seal-team-6 block in $file"
    else
      info "[dry-run] would create $file with seal-team-6 reference"
    fi
    return 0
  fi

  if [ ! -f "$file" ]; then
    printf '%s\n' "$injected" | atomic_write "$file"
    info "Created $file with seal-team-6 reference"
    return 0
  fi

  backup_file "$file"

  if grep -q "$MARKER_BEGIN" "$file" 2>/dev/null; then
    existing_content=$(strip_markers < "$file")
    # Trim leading blank lines
    existing_content=$(printf '%s\n' "$existing_content" | awk 'NF{p=1} p')
    if [ -n "$existing_content" ]; then
      printf '%s\n\n%s\n' "$injected" "$existing_content" | atomic_write "$file"
    else
      printf '%s\n' "$injected" | atomic_write "$file"
    fi
    info "Updated seal-team-6 reference in $file"
  else
    existing_content=$(cat "$file")
    printf '%s\n\n%s\n' "$injected" "$existing_content" | atomic_write "$file"
    info "Injected seal-team-6 reference at top of $file"
  fi
}

remove_markers_from_file() {
  file="$1"
  [ ! -f "$file" ] && return 0
  if ! grep -q "$MARKER_BEGIN" "$file" 2>/dev/null; then
    return 0
  fi
  if [ "$DRY_RUN" = "true" ]; then
    info "[dry-run] would remove seal-team-6 block from $file"
    return 0
  fi
  backup_file "$file"
  remaining=$(strip_markers < "$file")
  remaining=$(printf '%s\n' "$remaining" | awk 'NF{p=1} p')
  if [ -n "$remaining" ]; then
    printf '%s\n' "$remaining" | atomic_write "$file"
  else
    # File was only our block — leave a short stub so we don't delete user path unexpectedly
    printf '%s\n' "<!-- seal-team-6 uninstalled; add project agent instructions here -->" | atomic_write "$file"
  fi
  info "Removed seal-team-6 reference from $file"
}

detect_languages() {
  found=""
  if [ -f "package.json" ] || [ -f "tsconfig.json" ]; then
    found="$found typescript"
  fi
  if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    found="$found python"
  fi
  if [ -f "go.mod" ]; then
    found="$found go"
  fi
  if [ -f "Cargo.toml" ]; then
    found="$found rust"
  fi
  if [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    found="$found java"
  fi
  if [ -f "global.json" ] || ls ./*.csproj > /dev/null 2>&1 || ls ./*.sln > /dev/null 2>&1; then
    found="$found csharp"
  fi
  echo "$found" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

is_project_root() {
  [ -d ".git" ] && return 0
  [ -f "package.json" ] && return 0
  [ -f "tsconfig.json" ] && return 0
  [ -f "pyproject.toml" ] && return 0
  [ -f "setup.py" ] && return 0
  [ -f "requirements.txt" ] && return 0
  [ -f "go.mod" ] && return 0
  [ -f "Cargo.toml" ] && return 0
  [ -f "pom.xml" ] && return 0
  [ -f "build.gradle" ] && return 0
  [ -f "build.gradle.kts" ] && return 0
  [ -f "global.json" ] && return 0
  ls ./*.csproj > /dev/null 2>&1 && return 0
  ls ./*.sln > /dev/null 2>&1 && return 0
  return 1
}

ensure_gitignore_backup_entry() {
  [ "$DRY_RUN" = "true" ] && return 0
  entry=".seal-team-6-backup/"
  if [ -d ".git" ]; then
    if [ -f ".gitignore" ]; then
      if ! grep -qxF "$entry" .gitignore 2>/dev/null && ! grep -qF "seal-team-6-backup" .gitignore 2>/dev/null; then
        backup_file ".gitignore"
        printf '\n# seal-team-6 installer backups\n%s\n' "$entry" >> .gitignore
        info "Added $entry to .gitignore"
      fi
    else
      printf '# seal-team-6 installer backups\n%s\n' "$entry" | atomic_write ".gitignore"
      info "Created .gitignore with $entry"
    fi
  fi
}

write_cursor_rule() {
  dir=".cursor/rules"
  file="${dir}/seal-team-6.mdc"
  if [ "$DRY_RUN" = "true" ]; then
    info "[dry-run] would write $file"
    return 0
  fi
  mkdir -p "$dir"
  [ -f "$file" ] && backup_file "$file"
  cat <<'EOF' | atomic_write "$file"
---
description: Seal Team 6 agentic best practices entrypoint
alwaysApply: true
---

Read `docs/seal-team-6/agents.md` for agentic principles, engineering standards, and language guides.
Always read `docs/seal-team-6/agentic/guardrails.md` before destructive or high-blast-radius actions.
Do not pre-read every referenced file — follow the Loading Strategy in the entrypoint.
If `.project-context.md` exists, its directives take precedence for matching topics.
EOF
  info "Wrote $file (Cursor rules)"
}

write_continue_rule() {
  dir=".continue/rules"
  file="${dir}/seal-team-6.md"
  if [ "$DRY_RUN" = "true" ]; then
    info "[dry-run] would write $file"
    return 0
  fi
  mkdir -p "$dir"
  [ -f "$file" ] && backup_file "$file"
  cat <<'EOF' | atomic_write "$file"
# Seal Team 6

Read `docs/seal-team-6/agents.md` for agentic principles, engineering standards, and language guides.
Always read `docs/seal-team-6/agentic/guardrails.md` before destructive or high-blast-radius actions.
Follow the Loading Strategy — do not pre-read every referenced file.
If `.project-context.md` exists, its directives take precedence for matching topics.
EOF
  info "Wrote $file (Continue rules)"
}

write_aider_conf() {
  file=".aider.conf.yml"
  block="# seal-team-6
read:
  - docs/seal-team-6/agents.md
  - docs/seal-team-6/agentic/guardrails.md
"
  if [ "$DRY_RUN" = "true" ]; then
    info "[dry-run] would ensure aider read paths in $file"
    return 0
  fi
  if [ -f "$file" ]; then
    if grep -q "docs/seal-team-6/agents.md" "$file" 2>/dev/null; then
      info "Aider config already references seal-team-6"
      return 0
    fi
    backup_file "$file"
    printf '\n%s\n' "$block" >> "$file"
    info "Appended seal-team-6 read paths to $file"
  else
    printf '%s\n' "$block" | atomic_write "$file"
    info "Wrote $file (Aider)"
  fi
}

rewrite_canonical_agents() {
  # Stream rewrite + strip Operating Principles (no sed -i.bak left behind)
  file="${DOCS_DIR}/agents.md"
  [ "$DRY_RUN" = "true" ] && return 0
  [ ! -f "$file" ] && return 0

  tmp=$(mktemp)
  sed \
    -e 's|`docs/agentic/|`docs/seal-team-6/agentic/|g' \
    -e 's|`docs/engineering/|`docs/seal-team-6/engineering/|g' \
    -e 's|`docs/languages/|`docs/seal-team-6/languages/|g' \
    "$file" | awk '
      /^## Operating Principles$/ { exit }
      { print }
    ' > "$tmp"
  mv -f "$tmp" "$file"

  if ! grep -q 'docs/seal-team-6/' "$file" 2>/dev/null; then
    warn "Path rewriting may have failed — verify ${file} manually"
  fi
}

verify_checksums() {
  [ "$VERIFY" != "true" ] && return 0
  [ "$DRY_RUN" = "true" ] && return 0

  ctmp=$(mktemp)
  if ! fetch_soft "checksums.sha256" "$ctmp"; then
    warn "checksums.sha256 not available — skip integrity verify (pin a release tag that includes it)"
    rm -f "$ctmp"
    return 0
  fi

  if command -v shasum > /dev/null 2>&1; then
    HASH_CMD="shasum -a 256"
  elif command -v sha256sum > /dev/null 2>&1; then
    HASH_CMD="sha256sum"
  else
    warn "No shasum/sha256sum — skip integrity verify"
    rm -f "$ctmp"
    return 0
  fi

  info "Verifying downloaded pack against checksums.sha256..."
  # Map installed paths back to repo-relative for check
  # We verify files under DOCS_DIR and VERSION content against known hashes where possible.
  fail=0
  while read -r hash path; do
    [ -z "$hash" ] && continue
    case "$path" in
      \#*) continue ;;
    esac
    # Only verify files we installed into DOCS_DIR or known roots
    local_path=""
    case "$path" in
      agents.md)
        local_path="${DOCS_DIR}/agents.md"
        # canonical was rewritten — skip hash for agents.md after rewrite
        continue
        ;;
      VERSION|manifest.conf)
        local_path="${DOCS_DIR}/$(basename "$path")"
        if [ "$path" = "VERSION" ]; then
          local_path="${DOCS_DIR}/VERSION"
        elif [ "$path" = "manifest.conf" ]; then
          # not always installed to docs; verify against LOCAL if present
          if [ -n "$LOCAL_SOURCE" ] && [ -f "${LOCAL_SOURCE}/manifest.conf" ]; then
            local_path="${LOCAL_SOURCE}/manifest.conf"
          else
            continue
          fi
        fi
        ;;
      docs/agentic/*)
        local_path="${DOCS_DIR}/agentic/$(basename "$path")"
        ;;
      docs/engineering/*)
        local_path="${DOCS_DIR}/engineering/$(basename "$path")"
        ;;
      docs/languages/*)
        # docs/languages/ts/idioms.md → docs/seal-team-6/languages/ts/idioms.md
        rest=${path#docs/languages/}
        local_path="${DOCS_DIR}/languages/${rest}"
        ;;
      docs/project-context.example.md)
        local_path=".project-context.example.md"
        [ -f "$local_path" ] || continue
        ;;
      docs/tech-debt.example.md)
        local_path="TECH_DEBT.example.md"
        [ -f "$local_path" ] || continue
        ;;
      *)
        continue
        ;;
    esac

    if [ ! -f "$local_path" ]; then
      continue
    fi
    actual=$($HASH_CMD "$local_path" | awk '{print $1}')
    if [ "$actual" != "$hash" ]; then
      # Language packs may be partial — only fail if file exists and mismatches
      warn "Checksum mismatch: $local_path"
      fail=$((fail + 1))
    fi
  done < "$ctmp"
  rm -f "$ctmp"

  if [ "$fail" -gt 0 ]; then
    die "$fail checksum mismatch(es). Re-install from a clean tag or use --no-verify (not recommended)."
  fi
  ok "Integrity checks passed for installed files"
}

do_uninstall() {
  info "Uninstalling seal-team-6 references..."
  ensure_gitignore_backup_entry 2>/dev/null || true

  for f in AGENTS.md agents.md CLAUDE.md .windsurfrules; do
    remove_markers_from_file "$f"
  done

  if [ -f ".cursor/rules/seal-team-6.mdc" ]; then
    if [ "$DRY_RUN" = "true" ]; then
      info "[dry-run] would remove .cursor/rules/seal-team-6.mdc"
    else
      backup_file ".cursor/rules/seal-team-6.mdc"
      rm -f ".cursor/rules/seal-team-6.mdc"
      info "Removed .cursor/rules/seal-team-6.mdc"
    fi
  fi

  if [ -f ".continue/rules/seal-team-6.md" ]; then
    if [ "$DRY_RUN" = "true" ]; then
      info "[dry-run] would remove .continue/rules/seal-team-6.md"
    else
      backup_file ".continue/rules/seal-team-6.md"
      rm -f ".continue/rules/seal-team-6.md"
      info "Removed .continue/rules/seal-team-6.md"
    fi
  fi

  if [ -f ".aider.conf.yml" ] && grep -q "seal-team-6" ".aider.conf.yml" 2>/dev/null; then
    warn "Left .aider.conf.yml in place (may contain other settings). Remove seal-team-6 read paths manually if desired."
  fi

  if [ "$UNINSTALL_DOCS" = "true" ]; then
    if [ -d "$DOCS_DIR" ]; then
      if [ "$DRY_RUN" = "true" ]; then
        info "[dry-run] would remove $DOCS_DIR/"
      else
        # Backup whole tree summary: copy VERSION if present
        [ -f "${DOCS_DIR}/VERSION" ] && backup_file "${DOCS_DIR}/VERSION"
        rm -rf "$DOCS_DIR"
        info "Removed $DOCS_DIR/"
      fi
    fi
  else
    info "Left $DOCS_DIR/ in place (pass --uninstall-docs to remove)"
  fi

  ok "Uninstall complete. Backups (if any): ${BACKUP_DIR:-none}"
  info "Preserved: .project-context.md, TECH_DEBT.md (if present)"
}

# --- Parse Arguments ---
LANG_MODE="auto"
LANGUAGES=""
CURSOR=false
WINDSURF=false
CONTINUE=false
AIDER=false
VERSION_SET=false
DRY_RUN=false
UNINSTALL=false
UNINSTALL_DOCS=false
NO_BACKUP=false
VERIFY=true
LOCAL_SOURCE=""

for arg in "$@"; do
  case "$arg" in
    --lang=*)
      raw="${arg#--lang=}"
      if [ "$raw" = "all" ]; then
        LANG_MODE="all"
        LANGUAGES="$ALL_LANGUAGES"
      else
        LANG_MODE="explicit"
        LANGUAGES=$(echo "$raw" | tr ',' ' ')
      fi
      ;;
    --version=*)
      BRANCH="${arg#--version=}"
      BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
      VERSION_SET=true
      ;;
    --local)
      # Source files from the directory containing this script (or SEAL_TEAM_6_ROOT)
      if [ -n "$SEAL_TEAM_6_ROOT" ]; then
        LOCAL_SOURCE="$SEAL_TEAM_6_ROOT"
      else
        # When executed as ./install.sh, $0 is the script path
        case "$0" in
          */*)
            LOCAL_SOURCE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
            ;;
          *)
            LOCAL_SOURCE=$(pwd)
            ;;
        esac
      fi
      VERSION_SET=true
      ;;
    --source=*)
      LOCAL_SOURCE="${arg#--source=}"
      VERSION_SET=true
      ;;
    --cursor) CURSOR=true ;;
    --windsurf) WINDSURF=true ;;
    --continue) CONTINUE=true ;;
    --aider) AIDER=true ;;
    --dry-run) DRY_RUN=true ;;
    --uninstall) UNINSTALL=true ;;
    --uninstall-docs) UNINSTALL_DOCS=true ;;
    --no-backup) NO_BACKUP=true ;;
    --verify) VERIFY=true ;;
    --no-verify) VERIFY=false ;;
    --help|-h)
      cat <<'HELP'
Usage: install.sh [OPTIONS]

Options:
  --lang=LANGS       Comma-separated language guides, or 'all'
                     Default: auto-detect from project markers
                     Available: typescript,python,go,rust,java,csharp
  --version=TAG      Pin to a git tag or commit (recommended; default: main)
  --local            Install from this repo checkout (dev/CI; implies local files)
  --source=DIR       Install from a local directory tree
  --cursor           Write .cursor/rules/seal-team-6.mdc
  --windsurf         Inject reference into .windsurfrules
  --continue         Write .continue/rules/seal-team-6.md
  --aider            Ensure .aider.conf.yml reads seal-team-6 entrypoints
  --dry-run          Print actions without writing files
  --uninstall        Remove managed marker blocks and host rules
  --uninstall-docs   With --uninstall, also remove docs/seal-team-6/
  --no-backup        Do not write .seal-team-6-backup/ snapshots
  --verify           Verify checksums when checksums.sha256 is available (default)
  --no-verify        Skip checksum verification
  --help             Show this help message

Safety:
  Existing AGENTS.md / CLAUDE.md / etc. are backed up under
  .seal-team-6-backup/<timestamp>/ before mutation (unless --no-backup).
  docs/seal-team-6/ is fully overwritten on reinstall (no merge).
  .project-context.md and TECH_DEBT.md are never overwritten.
HELP
      exit 0
      ;;
    *)
      warn "Unknown argument: $arg"
      ;;
  esac
done

# Uninstall path
if [ "$UNINSTALL" = "true" ]; then
  do_uninstall
  exit 0
fi

# --- Pre-flight ---
if ! is_project_root; then
  warn "This doesn't look like a project root. Are you in the right directory?"
  if [ "$DRY_RUN" = "true" ]; then
    warn "[dry-run] continuing without prompt"
  else
    printf "Continue anyway? [y/N] "
    read -r answer
    case "$answer" in
      [yY]*) ;;
      *) echo "Aborted."; exit 1 ;;
    esac
  fi
fi

if [ "$VERSION_SET" = "false" ]; then
  warn "Installing from floating 'main'. Prefer --version=<tag> (see CHANGELOG.md / VERSION)."
fi

if [ -n "$LOCAL_SOURCE" ]; then
  info "Using local source: $LOCAL_SOURCE"
fi

# Load manifest for file lists / version
if [ -n "$LOCAL_SOURCE" ] && [ -f "${LOCAL_SOURCE}/manifest.conf" ]; then
  # shellcheck disable=SC1090
  . "${LOCAL_SOURCE}/manifest.conf"
  PACK_VERSION="${VERSION:-$DEFAULT_VERSION}"
elif [ -n "$LOCAL_SOURCE" ]; then
  die "manifest.conf not found in $LOCAL_SOURCE"
else
  mtmp=$(mktemp)
  if fetch_soft "manifest.conf" "$mtmp"; then
    # shellcheck disable=SC1090
    . "$mtmp"
    PACK_VERSION="${VERSION:-$DEFAULT_VERSION}"
  else
    warn "Could not load remote manifest.conf — using built-in file lists"
  fi
  rm -f "$mtmp"
fi

# Re-apply --lang=all after manifest may have updated ALL_LANGUAGES
if [ "$LANG_MODE" = "all" ]; then
  LANGUAGES="$ALL_LANGUAGES"
fi

if [ "$LANG_MODE" = "auto" ]; then
  LANGUAGES=$(detect_languages)
  if [ -z "$LANGUAGES" ]; then
    warn "No language markers detected — skipping Layer 3 language guides."
    warn "Pass --lang=typescript,python or --lang=all to install them."
  else
    info "Auto-detected languages: ${LANGUAGES}"
  fi
elif [ "$LANG_MODE" = "all" ]; then
  info "Installing all language guides"
fi

info "Installing seal-team-6 v${PACK_VERSION}..."
if [ "$DRY_RUN" = "true" ]; then
  warn "Dry-run mode — no files will be written"
fi

ensure_gitignore_backup_entry

# --- Download canonical agents.md ---
info "Downloading canonical context file..."
fetch "agents.md" "${DOCS_DIR}/agents.md"
rewrite_canonical_agents

# Write VERSION into pack
if [ "$DRY_RUN" != "true" ]; then
  printf '%s\n' "$PACK_VERSION" | atomic_write "${DOCS_DIR}/VERSION"
  info "Wrote ${DOCS_DIR}/VERSION ($PACK_VERSION)"
else
  info "[dry-run] would write ${DOCS_DIR}/VERSION ($PACK_VERSION)"
fi

# --- Host entrypoints ---
AGENTS_BLOCK="# Seal Team 6 — Agentic Best Practices

Read \`docs/seal-team-6/agents.md\` for foundational agentic principles,
engineering best practices, and language-specific conventions.

Installed pack version: see \`docs/seal-team-6/VERSION\`.

These guide new code toward alignment with proven standards.
Existing project patterns are respected for established code —
seal-team-6 only overrides for security issues or harmful patterns.
See the Conflict Resolution section in the canonical file for priority rules.

If \`.project-context.md\` exists in the project root, its directives
extend or override specific seal-team-6 defaults while preserving the rest.

---"

CLAUDE_BLOCK="# Seal Team 6

Read \`docs/seal-team-6/agents.md\` — it is the entry point for all agentic guidance.
Always read \`docs/seal-team-6/agentic/guardrails.md\` before taking any actions.
Follow other references as they become relevant to your current task — do not pre-read all referenced files.

Pack version: see \`docs/seal-team-6/VERSION\`.

Pay special attention to:
- The stack detection table — load language guides matching this project's stack
- \`.project-context.md\` (if it exists) — project-specific context takes precedence

---"

# Inject only existing agent host files; if neither exists, create AGENTS.md only.
# On case-insensitive filesystems (default macOS), AGENTS.md and agents.md are one file — inject once.
if [ -f "AGENTS.md" ] && [ -f "agents.md" ] && [ "AGENTS.md" -ef "agents.md" ]; then
  inject_reference "AGENTS.md" "$AGENTS_BLOCK"
elif [ -f "AGENTS.md" ] || [ -f "agents.md" ]; then
  [ -f "AGENTS.md" ] && inject_reference "AGENTS.md" "$AGENTS_BLOCK"
  if [ -f "agents.md" ]; then
    if [ ! -f "AGENTS.md" ] || [ ! "AGENTS.md" -ef "agents.md" ]; then
      inject_reference "agents.md" "$AGENTS_BLOCK"
    fi
  fi
else
  inject_reference "AGENTS.md" "$AGENTS_BLOCK"
fi

# CLAUDE.md: update if present; create if missing (Claude Code / multi-host default)
inject_reference "CLAUDE.md" "$CLAUDE_BLOCK"

# --- Layer 1 ---
info "Downloading agentic guidance..."
for file in $AGENTIC_FILES; do
  fetch "docs/agentic/${file}" "${DOCS_DIR}/agentic/${file}"
done

# --- Layer 2 ---
info "Downloading engineering principles..."
for file in $ENGINEERING_FILES; do
  fetch "docs/engineering/${file}" "${DOCS_DIR}/engineering/${file}"
done

# --- Layer 3 ---
for lang in $LANGUAGES; do
  info "Downloading ${lang} language guide..."
  for file in $LANG_FILES; do
    fetch "docs/languages/${lang}/${file}" "${DOCS_DIR}/languages/${lang}/${file}"
  done
done

# --- Templates ---
if [ ! -f ".project-context.md" ]; then
  fetch "docs/project-context.example.md" ".project-context.example.md"
  info "Project context template saved as .project-context.example.md"
  info "Rename to .project-context.md and edit to customize."
else
  ok "Existing .project-context.md found — preserved."
fi

if [ ! -f "TECH_DEBT.md" ]; then
  fetch "docs/tech-debt.example.md" "TECH_DEBT.example.md"
  info "Debt template saved as TECH_DEBT.example.md (rename to TECH_DEBT.md to activate)."
fi

# --- Host adapters (opt-in) ---
if [ "$CURSOR" = "true" ]; then
  write_cursor_rule
fi
if [ "$WINDSURF" = "true" ]; then
  inject_reference ".windsurfrules" "Read and follow docs/seal-team-6/agents.md for agentic best practices. Pack version: docs/seal-team-6/VERSION."
fi
if [ "$CONTINUE" = "true" ]; then
  write_continue_rule
fi
if [ "$AIDER" = "true" ]; then
  write_aider_conf
fi

# --- Verify ---
verify_checksums

# --- Summary ---
echo ""
if [ "$DRY_RUN" = "true" ]; then
  ok "Dry-run complete (seal-team-6 v${PACK_VERSION}) — no files written"
else
  ok "seal-team-6 v${PACK_VERSION} installed successfully!"
fi
echo ""
info "Installed files:"
info "  ${DOCS_DIR}/VERSION     — Pack version pin"
info "  ${DOCS_DIR}/agents.md   — Canonical agentic context"
info "  ${DOCS_DIR}/            — Best practices documentation"
info "  Host entrypoints        — AGENTS.md / agents.md / CLAUDE.md (as applicable)"
if [ -n "$BACKUP_DIR" ]; then
  info "  Backups                 — ${BACKUP_DIR}/"
fi
if [ "$CURSOR" = "true" ]; then
  info "  .cursor/rules/seal-team-6.mdc — Cursor"
fi
if [ "$WINDSURF" = "true" ]; then
  info "  .windsurfrules          — Windsurf"
fi
if [ "$CONTINUE" = "true" ]; then
  info "  .continue/rules/seal-team-6.md — Continue"
fi
if [ "$AIDER" = "true" ]; then
  info "  .aider.conf.yml         — Aider"
fi

INSTALLED_LANGS=""
for lang in $LANGUAGES; do
  if [ -d "${DOCS_DIR}/languages/${lang}" ] || [ "$DRY_RUN" = "true" ]; then
    INSTALLED_LANGS="${INSTALLED_LANGS} ${lang}"
  fi
done
if [ -n "$INSTALLED_LANGS" ]; then
  info "  Languages:${INSTALLED_LANGS}"
else
  info "  Languages: (none — use --lang=...)"
fi

echo ""
info "docs/seal-team-6/ is fully refreshed on each install (not merged)."
info "Recommended: commit ${DOCS_DIR}/ so the team shares the same standards."
info "Pin installs with --version=<tag>. Customize via .project-context.md"
info "Uninstall: install.sh --uninstall [--uninstall-docs]"

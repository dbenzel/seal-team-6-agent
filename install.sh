#!/bin/sh
# Seal Team 6 — Agentic Best Practices Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.sh | sh
# Prefer: ... | sh -s -- --version=vX.Y.Z
# Or:    ... | sh -s -- --lang=typescript,python

set -e

# --- Configuration ---
REPO="dbenzel/seal-team-6-agent"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
DOCS_DIR="docs/seal-team-6"
ALL_LANGUAGES="typescript python go rust java csharp"
MARKER_BEGIN="<!-- BEGIN seal-team-6 -->"
MARKER_END="<!-- END seal-team-6 -->"

# --- Colors (if terminal supports them) ---
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

# --- Helpers ---
info()  { printf "${BLUE}[seal-team-6]${NC} %s\n" "$1"; }
ok()    { printf "${GREEN}[seal-team-6]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[seal-team-6]${NC} %s\n" "$1"; }

download() {
  local url="$1"
  local dest="$2"
  local dir
  dir=$(dirname "$dest")
  mkdir -p "$dir"

  if command -v curl > /dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest" 2>/dev/null
  elif command -v wget > /dev/null 2>&1; then
    wget -q "$url" -O "$dest" 2>/dev/null
  else
    echo "Error: neither curl nor wget found. Install one and retry." >&2
    exit 1
  fi
}

# Inject a seal-team-6 reference block at the top of a file.
# If the file already has a seal-team-6 block, replace it.
# If the file doesn't exist, create it with just the block.
# $1 = file path, $2 = block content (without markers)
inject_reference() {
  local file="$1"
  local block="$2"
  local injected="${MARKER_BEGIN}
${block}
${MARKER_END}"

  if [ ! -f "$file" ]; then
    printf '%s\n' "$injected" > "$file"
    info "Created $file with seal-team-6 reference"
    return
  fi

  if grep -q "$MARKER_BEGIN" "$file" 2>/dev/null; then
    local existing_content
    existing_content=$(awk "
      /$MARKER_BEGIN/{skip=1; next}
      /$MARKER_END/{skip=0; next}
      !skip{print}
    " "$file")
    existing_content=$(echo "$existing_content" | sed '/./,$!d')
    printf '%s\n\n%s\n' "$injected" "$existing_content" > "$file"
    info "Updated seal-team-6 reference in $file"
  else
    local existing_content
    existing_content=$(cat "$file")
    printf '%s\n\n%s\n' "$injected" "$existing_content" > "$file"
    info "Injected seal-team-6 reference at top of $file"
  fi
}

detect_languages() {
  local found=""
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
  # C#: any .csproj / .sln / global.json in root
  if [ -f "global.json" ] || ls ./*.csproj > /dev/null 2>&1 || ls ./*.sln > /dev/null 2>&1; then
    found="$found csharp"
  fi
  # trim
  echo "$found" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

write_cursor_rule() {
  local dir=".cursor/rules"
  local file="${dir}/seal-team-6.mdc"
  mkdir -p "$dir"
  cat > "$file" <<'EOF'
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

# --- Parse Arguments ---
LANG_MODE="auto" # auto | all | explicit
LANGUAGES=""
CURSOR=false
WINDSURF=false
VERSION_SET=false

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
    --cursor)
      CURSOR=true
      ;;
    --windsurf)
      WINDSURF=true
      ;;
    --help|-h)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --lang=LANGS      Comma-separated language guides, or 'all'"
      echo "                    Default: auto-detect from project markers"
      echo "                    Available: typescript,python,go,rust,java,csharp"
      echo "  --version=TAG     Pin to a git tag or commit (recommended; default: main)"
      echo "  --cursor          Write .cursor/rules/seal-team-6.mdc"
      echo "  --windsurf        Inject reference into .windsurfrules"
      echo "  --help            Show this help message"
      exit 0
      ;;
    *)
      warn "Unknown argument: $arg"
      ;;
  esac
done

# --- Pre-flight Checks ---
if [ ! -d ".git" ] && [ ! -f "package.json" ] && [ ! -f "pyproject.toml" ] && [ ! -f "go.mod" ] && [ ! -f "Cargo.toml" ] && [ ! -f "pom.xml" ]; then
  warn "This doesn't look like a project root. Are you in the right directory?"
  printf "Continue anyway? [y/N] "
  read -r answer
  case "$answer" in
    [yY]*) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

if [ "$VERSION_SET" = "false" ]; then
  warn "Installing from floating 'main'. Prefer --version=<tag> once releases exist (see CHANGELOG.md)."
fi

if [ "$LANG_MODE" = "auto" ]; then
  LANGUAGES=$(detect_languages)
  if [ -z "$LANGUAGES" ]; then
    warn "No language markers detected — skipping Layer 3 language guides."
    warn "Pass --lang=typescript,python or --lang=all to install them."
  else
    info "Auto-detected languages:${LANGUAGES}"
  fi
elif [ "$LANG_MODE" = "all" ]; then
  info "Installing all language guides"
fi

info "Installing seal-team-6 agentic best practices..."

# --- Download canonical agents.md into docs/seal-team-6/ ---
info "Downloading canonical context file..."
download "${BASE_URL}/agents.md" "${DOCS_DIR}/agents.md"

# Rewrite docs/ paths in the canonical copy to be relative from docs/seal-team-6/
if command -v sed > /dev/null 2>&1; then
  sed -i.bak 's|`docs/agentic/|`docs/seal-team-6/agentic/|g' "${DOCS_DIR}/agents.md"
  sed -i.bak 's|`docs/engineering/|`docs/seal-team-6/engineering/|g' "${DOCS_DIR}/agents.md"
  sed -i.bak 's|`docs/languages/|`docs/seal-team-6/languages/|g' "${DOCS_DIR}/agents.md"
  # Strip Operating Principles from canonical copy to avoid duplication with root agents.md
  sed -i.bak '/^## Operating Principles$/,$ d' "${DOCS_DIR}/agents.md"
  rm -f "${DOCS_DIR}/agents.md.bak"
fi

if ! grep -q 'docs/seal-team-6/' "${DOCS_DIR}/agents.md" 2>/dev/null; then
  warn "Path rewriting may have failed — verify ${DOCS_DIR}/agents.md manually"
fi

# --- Inject reference into AGENTS.md and agents.md ---
AGENTS_BLOCK="# Seal Team 6 — Agentic Best Practices

Read \`docs/seal-team-6/agents.md\` for foundational agentic principles,
engineering best practices, and language-specific conventions.

These guide new code toward alignment with proven standards.
Existing project patterns are respected for established code —
seal-team-6 only overrides for security issues or harmful patterns.
See the Conflict Resolution section in the canonical file for priority rules.

If \`.project-context.md\` exists in the project root, its directives
extend or override specific seal-team-6 defaults while preserving the rest.

---"

inject_reference "AGENTS.md" "$AGENTS_BLOCK"
inject_reference "agents.md" "$AGENTS_BLOCK"

# --- Inject reference into CLAUDE.md ---
CLAUDE_BLOCK="# Seal Team 6

Read \`docs/seal-team-6/agents.md\` — it is the entry point for all agentic guidance.
Always read \`docs/seal-team-6/agentic/guardrails.md\` before taking any actions.
Follow other references as they become relevant to your current task — do not pre-read all referenced files.

Pay special attention to:
- The stack detection table — load language guides matching this project's stack
- \`.project-context.md\` (if it exists) — project-specific context takes precedence

---"

inject_reference "CLAUDE.md" "$CLAUDE_BLOCK"

# --- Download Agentic Guidance (Layer 1) ---
info "Downloading agentic guidance..."
AGENTIC_FILES="guardrails.md task-decomposition.md tool-usage.md context-management.md verification.md orchestration.md continuous-improvement.md health-snapshot.md untrusted-input.md modes.md"
for file in $AGENTIC_FILES; do
  download "${BASE_URL}/docs/agentic/${file}" "${DOCS_DIR}/agentic/${file}"
done

# --- Download Engineering Principles (Layer 2) ---
info "Downloading engineering principles..."
ENGINEERING_FILES="code-quality.md testing.md architecture.md security.md git-workflow.md error-handling.md performance.md"
for file in $ENGINEERING_FILES; do
  download "${BASE_URL}/docs/engineering/${file}" "${DOCS_DIR}/engineering/${file}"
done

# --- Download Language Guides (Layer 3) ---
LANG_FILES="idioms.md testing.md tooling.md"
for lang in $LANGUAGES; do
  info "Downloading ${lang} language guide..."
  for file in $LANG_FILES; do
    download "${BASE_URL}/docs/languages/${lang}/${file}" "${DOCS_DIR}/languages/${lang}/${file}"
  done
done

# --- Project Context + debt template ---
if [ ! -f ".project-context.md" ]; then
  download "${BASE_URL}/docs/project-context.example.md" ".project-context.example.md"
  info "Project context template saved as .project-context.example.md"
  info "Rename to .project-context.md and edit to customize."
else
  ok "Existing .project-context.md found — preserved."
fi

if [ ! -f "TECH_DEBT.md" ]; then
  download "${BASE_URL}/docs/tech-debt.example.md" "TECH_DEBT.example.md"
  info "Debt template saved as TECH_DEBT.example.md (rename to TECH_DEBT.md to activate)."
fi

# --- Cursor / Windsurf (opt-in) ---
if [ "$CURSOR" = "true" ]; then
  write_cursor_rule
fi

if [ "$WINDSURF" = "true" ]; then
  inject_reference ".windsurfrules" "Read and follow docs/seal-team-6/agents.md for agentic best practices."
fi

# --- Summary ---
echo ""
ok "seal-team-6 installed successfully!"
echo ""
info "Installed files:"
info "  ${DOCS_DIR}/agents.md  — Canonical agentic context"
info "  ${DOCS_DIR}/            — Best practices documentation"
info "  AGENTS.md / agents.md   — Injected reference (existing content preserved)"
info "  CLAUDE.md               — Injected reference (existing content preserved)"
if [ "$CURSOR" = "true" ]; then
  info "  .cursor/rules/seal-team-6.mdc — Cursor integration"
fi
if [ "$WINDSURF" = "true" ]; then
  info "  .windsurfrules          — Windsurf integration"
fi

INSTALLED_LANGS=""
for lang in $LANGUAGES; do
  if [ -d "${DOCS_DIR}/languages/${lang}" ]; then
    INSTALLED_LANGS="${INSTALLED_LANGS} ${lang}"
  fi
done
if [ -n "$INSTALLED_LANGS" ]; then
  info "  Languages:${INSTALLED_LANGS}"
else
  info "  Languages: (none — use --lang=...)"
fi

echo ""
info "Recommended: commit docs/seal-team-6/ to version control so all team members share the same standards."
info "Pin installs with --version=<tag>. Customize via .project-context.md"

#!/bin/sh
# Smoke-test install.sh (and optionally uninstall) against a temp project.
# Usage: ./scripts/install-smoke-test.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
assert() {
  msg="$1"
  shift
  if "$@"; then
    echo "  PASS: $msg"
    pass=$((pass + 1))
  else
    echo "  FAIL: $msg" >&2
    fail=$((fail + 1))
  fi
}

echo "== smoke: fresh project, local install =="
mkdir -p "$TMP/proj"
cd "$TMP/proj"
git init -q
printf '%s\n' '{"name":"smoke"}' > package.json
printf '%s\n' '# existing agents' > AGENTS.md
printf '%s\n' '# existing claude' > CLAUDE.md

sh "$ROOT/install.sh" --local --lang=typescript --cursor --continue --aider --verify

assert "docs pack exists" test -d docs/seal-team-6
assert "VERSION written" test -f docs/seal-team-6/VERSION
assert "canonical agents" test -f docs/seal-team-6/agents.md
assert "path rewrite" grep -q 'docs/seal-team-6/agentic/' docs/seal-team-6/agents.md
assert "typescript guide" test -f docs/seal-team-6/languages/typescript/idioms.md
assert "no python guide (auto not all)" test ! -f docs/seal-team-6/languages/python/idioms.md
assert "AGENTS marker" grep -q 'BEGIN seal-team-6' AGENTS.md
assert "preserves AGENTS body" grep -q 'existing agents' AGENTS.md
# Case-insensitive FS: agents.md may be the same inode as AGENTS.md
if [ -f agents.md ] && [ AGENTS.md -ef agents.md ]; then
  assert "single agents host file (case-insensitive FS)" true
else
  assert "did not create agents.md (AGENTS.md present)" test ! -f agents.md
fi
assert "CLAUDE marker" grep -q 'BEGIN seal-team-6' CLAUDE.md
assert "backup created" test -d .seal-team-6-backup
assert "cursor rule" test -f .cursor/rules/seal-team-6.mdc
assert "continue rule" test -f .continue/rules/seal-team-6.md
assert "aider conf" test -f .aider.conf.yml
assert "project context example" test -f .project-context.example.md
assert "tech debt example" test -f TECH_DEBT.example.md
assert "gitignore has backup" grep -q 'seal-team-6-backup' .gitignore 2>/dev/null || test -f .gitignore

echo "== smoke: dry-run does not write new files =="
# capture mtime of VERSION
before=$(wc -c < docs/seal-team-6/VERSION)
sh "$ROOT/install.sh" --local --dry-run --lang=all >/dev/null
after=$(wc -c < docs/seal-team-6/VERSION)
assert "dry-run leaves VERSION size" test "$before" = "$after"
assert "dry-run did not add python" test ! -f docs/seal-team-6/languages/python/idioms.md

echo "== smoke: reinstall is idempotent on markers =="
sh "$ROOT/install.sh" --local --lang=typescript --no-verify >/dev/null
count=$(grep -c 'BEGIN seal-team-6' AGENTS.md || true)
assert "single marker block after reinstall" test "$count" -eq 1

echo "== smoke: uninstall removes markers and docs =="
sh "$ROOT/install.sh" --uninstall --uninstall-docs >/dev/null
assert "docs removed" test ! -d docs/seal-team-6
if grep -q 'BEGIN seal-team-6' AGENTS.md 2>/dev/null; then
  assert "AGENTS marker gone" false
else
  assert "AGENTS marker gone" true
fi
assert "AGENTS body kept" grep -q 'existing agents' AGENTS.md
assert "cursor rule removed" test ! -f .cursor/rules/seal-team-6.mdc

echo "== smoke: neither agents file → create AGENTS.md only =="
rm -f AGENTS.md agents.md CLAUDE.md
mkdir -p "$TMP/empty" && cd "$TMP/empty"
git init -q
sh "$ROOT/install.sh" --local --lang=go --no-verify >/dev/null
assert "created AGENTS.md" test -f AGENTS.md
if [ -f agents.md ] && [ AGENTS.md -ef agents.md ]; then
  assert "single agents host file after create (case-insensitive FS)" true
else
  assert "no agents.md dual create" test ! -f agents.md
fi
assert "created CLAUDE.md" test -f CLAUDE.md
assert "go guide" test -f docs/seal-team-6/languages/go/idioms.md

echo ""
echo "Results: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "All install smoke tests passed."

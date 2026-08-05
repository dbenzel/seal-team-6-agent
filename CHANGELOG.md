# Changelog

All notable changes to seal-team-6 are documented here.
Install with `--version=<tag>` (or `-Version`) once a tag exists; prefer tags over floating `main`.

## 1.0.0 — 2026-08-04

### Added

- `VERSION` + `docs/seal-team-6/VERSION` pack pin after install
- `manifest.conf` — single source of truth for file lists (both installers)
- `checksums.sha256` + `scripts/generate-checksums.sh` for integrity checks
- Installer **backups** under `.seal-team-6-backup/<timestamp>/` before mutating host files
- `--dry-run` / `-DryRun` — print planned actions without writing
- `--uninstall` / `-Uninstall` (+ `--uninstall-docs` / `-UninstallDocs`)
- `--local` / `-Local` and `--source=` / `-Source` for offline/dev/CI installs
- `--verify` (default) / `--no-verify` checksum verification when available
- Host adapters: `--continue` / `-Continue`, `--aider` / `-Aider` (plus existing Cursor/Windsurf)
- Atomic writes (temp file + rename) for host entrypoints
- Expanded project-root preflight (Gradle, C#, tsconfig, requirements, etc.)
- Smarter host injection: only touch existing `AGENTS.md`/`agents.md`; create `AGENTS.md` if neither exists
- CI workflow: checksum freshness + install smoke (Ubuntu, macOS, Windows)
- `scripts/install-smoke-test.sh`, `scripts/eval-golden.sh`
- `.gitignore` for installer artifacts and OS noise
- Language guide “Last reviewed” stamps on idioms docs

### Changed

- Evidence-first verification replaces ritual TDD-as-always (tests still required as proof; fake greens still forbidden)
- Install defaults to **auto-detected** language guides; use `--lang=all` / `-Lang all` for the full set
- Cursor integration writes `.cursor/rules/seal-team-6.mdc` instead of legacy `.cursorrules`
- Inject project entrypoints into existing agent host files (plus `CLAUDE.md`)
- Context budgeting guidance uses concrete tactics instead of fake percentage quotas
- Progress tracking allows parallel research; still one *implementation* focus at a time
- Path rewriting no longer leaves transient `sed -i.bak` files
- Download errors surface URL/context instead of silent failure

### Safety notes

- `docs/seal-team-6/` is **fully overwritten** on reinstall (not merged)
- `.project-context.md` and `TECH_DEBT.md` are **never** overwritten
- Host files (`AGENTS.md`, `CLAUDE.md`, …) are snapshotted under `.seal-team-6-backup/` unless `--no-backup`

### Docs (this release train)

- `docs/agentic/untrusted-input.md` — prompt-injection / MCP hygiene
- `docs/agentic/modes.md` — explore / plan / implement / verify / review
- `docs/tech-debt.example.md` — structured debt template
- `docs/evals/README.md` — golden-task checklist for guidance changes

## Unreleased

_(empty)_

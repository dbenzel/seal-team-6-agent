# Changelog

All notable changes to seal-team-6 are documented here.
Install with `--version=<tag>` (or `-Version`) once a tag exists; prefer tags over floating `main`.

## Unreleased

### Changed

- Evidence-first verification replaces ritual TDD-as-always (tests still required as proof; fake greens still forbidden)
- Install defaults to **auto-detected** language guides; use `--lang=all` / `-Lang all` for the full set
- Cursor integration writes `.cursor/rules/seal-team-6.mdc` instead of legacy `.cursorrules`
- Inject project entrypoints into `AGENTS.md` and `agents.md` (plus `CLAUDE.md`)
- Context budgeting guidance uses concrete tactics instead of fake percentage quotas
- Progress tracking allows parallel research; still one *implementation* focus at a time

### Added

- `docs/agentic/untrusted-input.md` — prompt-injection / MCP hygiene
- `docs/agentic/modes.md` — explore / plan / implement / verify / review
- `docs/tech-debt.example.md` — structured debt template
- `docs/evals/README.md` — golden-task checklist for guidance changes
- Install warning when pinning is omitted (`main` float)

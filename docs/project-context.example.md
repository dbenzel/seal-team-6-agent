# Seal Team 6 — Project Context

This file captures project-specific intelligence that extends the seal-team-6 defaults. Agents read this file at the start of every session. Over time, it grows as agents observe patterns and propose additions.

Rename this file to `.project-context.md` in your project root to activate.

---

Uncomment sections below by removing the `<!--` and `-->` markers, then edit to match your project. Agents may also propose additions to uncommented sections — accept or reject each proposal.

<!-- ## Testing
- Use Mocha instead of Jest/Vitest for this project
- Integration tests live in `e2e/` not `tests/`
- Minimum coverage threshold: 80%
-->

<!-- ## Git Workflow
- Use conventional commits (feat:, fix:, chore:, etc.)
- Squash merge all PRs
- Branch naming: {type}/{ticket}-{description} (e.g., feat/PROJ-123-add-login)
-->

<!-- ## Architecture
- This project uses a monorepo structure managed by Turborepo
- Shared packages live in `packages/`
- Applications live in `apps/`
- Use barrel exports (index.ts) for package public APIs
-->

<!-- ## Project-Specific Rules
- All API endpoints must include OpenAPI documentation
- Database migrations must be reversible
- Feature flags must be used for all user-facing changes
-->

<!-- ## Coverage & Quality Tracking
- Coverage target: 80% line coverage, 60% branch coverage
- Coverage tool: pytest-cov / nyc / go test -cover (auto-detect)
- Track coverage in: CI pipeline / local only
- High-risk modules that need coverage first: src/auth/, src/payments/
- Use TECH_DEBT.md for tracking identified issues: yes (default)
-->

<!-- ## Agent Improvement Scope
- Tier 1 improvements (small, safe, reported): enabled (default) / disabled
- Scope negotiation for multi-step tasks: always / only for large tasks (default) / never
- Suggest health snapshots on first interaction: yes (default) / no
-->

<!-- ## Learned Patterns
(Agents may propose additions to this section based on observations.
Accept or reject each proposal — this section grows over time.)

Examples of learned patterns:
- This project uses factory functions for all service instantiation
- API responses follow the envelope pattern: { data, error, meta }
- All database access goes through repository classes in src/repos/
-->

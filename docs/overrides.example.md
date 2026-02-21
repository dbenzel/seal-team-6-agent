# Seal Team 6 — Local Overrides

This file overrides defaults from `agents.md`. Only directives listed here take effect — everything else falls through to the seal-team-6 defaults.

Rename this file to `.seal-team-6-overrides.md` in your project root to activate.

---

## Override Examples

Uncomment and modify sections below as needed.

### Testing Overrides

```markdown
<!-- Uncomment to customize testing behavior -->
<!-- ## Testing
- Use Mocha instead of Jest/Vitest for this project
- Integration tests live in `e2e/` not `tests/`
- Minimum coverage threshold: 80%
-->
```

### Git Workflow Overrides

```markdown
<!-- Uncomment to customize git workflow -->
<!-- ## Git Workflow
- Use conventional commits (feat:, fix:, chore:, etc.)
- Squash merge all PRs
- Branch naming: {type}/{ticket}-{description} (e.g., feat/PROJ-123-add-login)
-->
```

### Architecture Overrides

```markdown
<!-- Uncomment to customize architecture guidance -->
<!-- ## Architecture
- This project uses a monorepo structure managed by Turborepo
- Shared packages live in `packages/`
- Applications live in `apps/`
- Use barrel exports (index.ts) for package public APIs
-->
```

### Custom Rules

```markdown
<!-- Add any project-specific rules here -->
<!-- ## Project-Specific Rules
- All API endpoints must include OpenAPI documentation
- Database migrations must be reversible
- Feature flags must be used for all user-facing changes
-->
```

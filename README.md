# Seal Team 6 — Agentic Best Practices

Battle-tested guardrails and best practices for AI-assisted software engineering. One command drops proven agentic guidance into any project.

Think of it as a **package manager for agentic context** — replicate successful patterns without manual duplication.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.sh | sh
```

This installs into your current project directory:
- `docs/seal-team-6/` — Full best practices documentation (canonical source)
- `agents.md` — If it exists, a seal-team-6 reference is **prepended** (existing content preserved). If not, one is created.
- `CLAUDE.md` — Same behavior: inject reference at top, preserve existing content.

### Install Specific Languages Only

```bash
curl -fsSL https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.sh | sh -s -- --lang=typescript,python
```

Available languages: `typescript`, `python`, `go`, `rust`, `java`, `csharp`

### Additional Options

```bash
# Pin to a specific version
curl -fsSL .../install.sh | sh -s -- --version=v1.0.0

# Generate Cursor/Windsurf integration files
curl -fsSL .../install.sh | sh -s -- --cursor --windsurf
```

## What's Inside

### Three-Layer Architecture

```
agents.md (root)
│
├── Layer 1: Agentic Guidance
│   ├── guardrails.md            — Safety, blast radius, destructive action prevention
│   ├── task-decomposition.md    — Breaking work into subtasks, planning
│   ├── tool-usage.md            — Right tool for the job, parallelization
│   ├── context-management.md    — Keeping context clean and relevant
│   ├── verification.md          — Testing, validation, checking your work
│   ├── orchestration.md         — Reference trees, sub-agent delegation, context budgeting
│   └── continuous-improvement.md — Boy scout rule, opportunistic cleanup
│
├── Layer 2: Engineering Principles (language-agnostic)
│   ├── code-quality.md        — Naming, simplicity, readability
│   ├── testing.md             — TDD protocol, testing pyramid, coverage
│   ├── architecture.md        — SOLID, separation of concerns, abstractions
│   ├── security.md            — OWASP, secrets, input validation
│   ├── git-workflow.md        — Commits, branches, PRs
│   ├── error-handling.md      — Error patterns, logging, recovery
│   └── performance.md         — Profiling, algorithms, optimization
│
└── Layer 3: Language-Specific Guides (loaded per stack)
    ├── typescript/  — idioms, testing (Vitest/Jest), tooling (tsconfig, ESLint)
    ├── python/      — idioms, testing (pytest), tooling (ruff, mypy, uv)
    ├── go/          — idioms, testing (stdlib), tooling (golangci-lint)
    ├── rust/        — idioms, testing (cargo test), tooling (clippy, cargo)
    ├── java/        — idioms, testing (JUnit 5), tooling (Gradle/Maven)
    └── csharp/      — idioms, testing (xUnit), tooling (.NET SDK, Roslyn)
```

### How It Works

1. The installer **injects a reference block** at the top of your existing `agents.md` and `CLAUDE.md` (or creates them if they don't exist). Existing project-specific guidance is preserved below.
2. The canonical `docs/seal-team-6/agents.md` instructs the agent to **detect your stack** (package.json → TypeScript, go.mod → Go, etc.)
3. Seal-team-6 principles guide new code toward alignment with these standards; existing project patterns are respected for established code (see Conflict Resolution in `agents.md`)
4. Existing project guidance is still respected — seal-team-6 only overrides when there's a security issue or actively harmful pattern
5. If `.seal-team-6-overrides.md` exists, those directives override specific seal-team-6 defaults
6. Re-running the installer updates the seal-team-6 block (between `<!-- BEGIN/END seal-team-6 -->` markers) without touching your content

### Key Opinions

- **TDD is the default workflow** (for application code). Write a failing test. See red. Implement. See green. Refactor.
- **Never fake a test.** No empty bodies, no `pass`, no `assert True`, no placeholder assertions.
- **Read before writing.** Never modify code you haven't read.
- **Minimum viable change.** Do what was asked, nothing more.
- **Ask when uncertain.** A clarifying question costs seconds; a wrong assumption costs hours.

## Customization

Copy the override template and edit:

```bash
cp .seal-team-6-overrides.example.md .seal-team-6-overrides.md
```

Override any section — unaddressed topics fall through to defaults. See the template for examples.

## Updating

Re-run the install command. It's idempotent — the seal-team-6 reference block in `agents.md`/`CLAUDE.md` is updated in place (between the `<!-- BEGIN/END seal-team-6 -->` markers), `docs/seal-team-6/` is refreshed, and your project-specific content + `.seal-team-6-overrides.md` are preserved.

```bash
curl -fsSL https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.sh | sh
```

## Supported AI Tools

| Tool | Integration |
|---|---|
| **Claude Code** | Reads `CLAUDE.md` → `agents.md` automatically |
| **Cursor** | Run with `--cursor` flag, or point `.cursorrules` at `agents.md` manually |
| **Windsurf** | Run with `--windsurf` flag, or point `.windsurfrules` at `agents.md` manually |
| **Other** | Reference `agents.md` in your tool's context configuration |

## Contributing

PRs welcome. The bar for new content:

1. **Opinionated** — generic advice that applies everywhere isn't useful
2. **Battle-tested** — it should come from real experience, not theory
3. **Concise** — every sentence should earn its place

## License

MIT

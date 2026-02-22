# Seal Team 6 — Agentic Best Practices

Battle-tested guardrails and best practices for AI-assisted software engineering. One command drops proven agentic guidance into any project — and keeps improving it over time.

Think of it as a **package manager for agentic context** — replicate successful patterns without manual duplication. But unlike a static config drop, seal-team-6 compounds: every interaction makes the codebase measurably better, with your consent at every step.

## Quick Start

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.ps1 | iex
```

> **Windows note:** If you get an execution policy error, run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` first.

This installs into your current project directory:
- `docs/seal-team-6/` — Full best practices documentation (canonical source)
- `agents.md` — If it exists, a seal-team-6 reference is **prepended** (existing content preserved). If not, one is created.
- `CLAUDE.md` — Same behavior: inject reference at top, preserve existing content.
- `.project-context.example.md` — Template for project-specific intelligence. Rename to `.project-context.md` and customize.

### Install Specific Languages Only

```bash
curl -fsSL https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.sh | sh -s -- --lang=typescript,python
```

**Windows (PowerShell):**

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.ps1))) -Lang typescript,python
```

Available languages: `typescript`, `python`, `go`, `rust`, `java`, `csharp`

### Additional Options

```bash
# Pin to a specific version
curl -fsSL .../install.sh | sh -s -- --version=v1.0.0

# Generate Cursor/Windsurf integration files
curl -fsSL .../install.sh | sh -s -- --cursor --windsurf
```

**Windows (PowerShell):**

```powershell
# Pin to a specific version
& ([scriptblock]::Create((irm .../install.ps1))) -Version v1.0.0

# Generate Cursor/Windsurf integration files
& ([scriptblock]::Create((irm .../install.ps1))) -Cursor -Windsurf
```

## What's Inside

### Three-Layer Architecture

```
agents.md (root)
│
├── Layer 1: Agentic Guidance
│   ├── guardrails.md            — Safety, blast radius, scope negotiation
│   ├── task-decomposition.md    — Breaking work into subtasks, planning
│   ├── tool-usage.md            — Right tool for the job, parallelization
│   ├── context-management.md    — Keeping context clean and relevant
│   ├── verification.md          — Testing, validation, checking your work
│   ├── orchestration.md         — Reference trees, sub-agent delegation, context budgeting
│   ├── continuous-improvement.md — Consent tiers, debt surfacing, non-regression ratchets
│   └── health-snapshot.md       — Project health assessment (coverage, types, architecture)
│
├── Layer 2: Engineering Principles (language-agnostic)
│   ├── code-quality.md        — Naming, simplicity, readability
│   ├── testing.md             — TDD protocol, testing pyramid, coverage assessment
│   ├── architecture.md        — SOLID, separation of concerns, open/closed workflows
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

1. The installer **injects a reference block** at the top of your existing `agents.md` and `CLAUDE.md` (or creates them). Existing content is preserved.
2. The canonical `agents.md` detects your stack (package.json → TypeScript, go.mod → Go, etc.) and loads the right language guides.
3. New code follows seal-team-6 standards. Existing code is respected — seal-team-6 only overrides for security issues or harmful patterns.
4. On first interaction, the agent **suggests a health snapshot** — an honest assessment of your project's test coverage, type safety, architecture, and security posture. You decide whether to run it.
5. Every improvement the agent makes beyond your request is **visible in the task summary**. Small improvements (< 10 lines, same file) are reported. Larger changes require your approval first.
6. Issues discovered along the way get tracked in `TECH_DEBT.md` — so findings persist across sessions instead of evaporating.
7. `.project-context.md` **grows over time** as agents observe patterns and propose additions. It starts with your preferences and accumulates into a rich project-specific guide.
8. **The ratchet only moves forward.** Coverage, type safety, and conventions don't regress — agents flag any change that would weaken established protections.

### Key Opinions

- **TDD is the default workflow** (for application code). Write a failing test. See red. Implement. See green. Refactor.
- **Never fake a test.** No empty bodies, no `pass`, no `assert True`, no placeholder assertions.
- **Read before writing.** Never modify code you haven't read.
- **Minimum viable change.** Do what was asked, nothing more.
- **Ask when uncertain.** A clarifying question costs seconds; a wrong assumption costs hours.
- **Every improvement is visible.** No silent scope expansion. Agents report everything they changed beyond your request.
- **Coverage is honest.** If you don't know your coverage number, you have a coverage problem. Measure it, track it, improve it.
- **The ratchet only moves forward.** Tests don't regress. Types don't loosen. Safety checks don't disappear.

## Project Context

Your project's `.project-context.md` is a living document — not just configuration, but accumulated intelligence. Start with preferences, grow into a project-specific guide:

```bash
cp .project-context.example.md .project-context.md
```

```powershell
# Windows
Copy-Item .project-context.example.md .project-context.md
```

It covers: testing conventions, coverage targets, architecture rules, agent improvement scope, and **learned patterns** that agents discover over time. See the template for examples.

## Updating

Re-run the install command. It's idempotent — the seal-team-6 reference block in `agents.md`/`CLAUDE.md` is updated in place (between the `<!-- BEGIN/END seal-team-6 -->` markers), `docs/seal-team-6/` is refreshed, and your project-specific content + `.project-context.md` are preserved. Your project's accumulated intelligence stays intact.

```bash
curl -fsSL https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/dbenzel/seal-team-6-agent/main/install.ps1 | iex
```

## Supported AI Tools

| Tool | Integration |
|---|---|
| **Claude Code** | Reads `CLAUDE.md` → `agents.md` automatically |
| **Cursor** | Run with `--cursor` / `-Cursor` flag, or point `.cursorrules` at `agents.md` manually |
| **Windsurf** | Run with `--windsurf` / `-Windsurf` flag, or point `.windsurfrules` at `agents.md` manually |
| **Other** | Reference `agents.md` in your tool's context configuration |

## Contributing

PRs welcome. The bar for new content:

1. **Opinionated** — generic advice that applies everywhere isn't useful
2. **Battle-tested** — it should come from real experience, not theory
3. **Concise** — every sentence should earn its place

## License

MIT

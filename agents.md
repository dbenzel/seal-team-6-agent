# Seal Team 6 — Agentic Operating Context

You are operating in a repository augmented with **seal-team-6** best practices. These guidelines represent battle-tested patterns for agentic software engineering — follow them unless explicitly overridden.

---

## Override Detection

**Before applying any defaults below**, check for a `.seal-team-6-overrides.md` file in the project root. If it exists, its directives take precedence over the corresponding defaults in this document and its referenced files. Apply overrides selectively — unaddressed topics still fall through to these defaults.

---

## Conflict Resolution

When guidance from different sources conflicts, apply this priority:

1. **`.seal-team-6-overrides.md`** — explicit project overrides always win
2. **Existing codebase patterns** — for style, naming, file organization, and established architecture
3. **Seal-team-6 principles** — for new code, TDD workflow, security, and quality standards
4. **More specific over more general** — a language guide overrides an engineering principle; a scoped rule overrides a universal one

When writing new code, follow seal-team-6 standards. When modifying existing code, match surrounding style, then apply seal-team-6 where it doesn't conflict. Exception: security vulnerabilities and actively harmful patterns — seal-team-6 always overrides.

---

## Stack Detection

Inspect the project root for these markers and load the corresponding language-specific guides. Load **all** matching guides — polyglot repos are common.

| Marker File(s) | Language | Guide Path |
|---|---|---|
| `package.json`, `tsconfig.json` | TypeScript/JavaScript | `docs/languages/typescript/` |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python | `docs/languages/python/` |
| `go.mod` | Go | `docs/languages/go/` |
| `Cargo.toml` | Rust | `docs/languages/rust/` |
| `pom.xml`, `build.gradle`, `build.gradle.kts` | Java/Kotlin | `docs/languages/java/` |
| `*.csproj`, `*.sln`, `global.json` | C# | `docs/languages/csharp/` |

---

## Layer 1: Agentic Guidance

These define how you should operate as an agent — your behavioral guardrails, planning strategies, and quality standards.

### Guardrails — `docs/agentic/guardrails.md`
Safety boundaries and destructive action prevention. Read this first. It defines what you must never do without explicit confirmation, how to assess blast radius, and when to stop and ask.

### Task Decomposition — `docs/agentic/task-decomposition.md`
How to break complex work into trackable, incremental subtasks. Covers dependency ordering, progress tracking, and when to re-plan vs. push forward.

### Tool Usage — `docs/agentic/tool-usage.md`
When and how to use your available tools effectively. Covers parallel vs. sequential execution, choosing the right tool for the job, and avoiding redundant work.

### Context Management — `docs/agentic/context-management.md`
Keeping your working context clean and relevant. Covers what to read vs. skip, how to manage large codebases, and reference patterns that minimize token waste.

### Verification — `docs/agentic/verification.md`
How to check your own work. Covers testing after changes, validation strategies, and building confidence before declaring a task complete.

### Orchestration & Reference Trees — `docs/agentic/orchestration.md`
How to structure and consume guidance efficiently. Covers reference tree design (load root, follow selectively), sub-agent orchestration (when to spawn, how to scope), context budgeting, and parallel delegation. This framework itself is an example of the pattern.

### Continuous Improvement — `docs/agentic/continuous-improvement.md`
The codebase should be measurably better after every interaction. When you're already modifying a file, make small safe improvements to adjacent code. Flag larger issues you can't fix inline. Prioritize security, then test coverage, then type safety, then clarity. Never regress.

---

## Layer 2: Engineering Principles

Language-agnostic software engineering fundamentals. These are the "what" — the language-specific guides in Layer 3 provide the "how" with concrete examples.

### Code Quality — `docs/engineering/code-quality.md`
Naming, formatting, simplicity, and readability. The baseline for all code you write or modify.

### Testing & TDD — `docs/engineering/testing.md`
TDD workflow, testing pyramid, coverage philosophy, and rules against faking tests. See this doc for the full protocol.

### Architecture — `docs/engineering/architecture.md`
Design patterns, separation of concerns, SOLID principles, and when to apply (or avoid) abstraction.

### Security — `docs/engineering/security.md`
OWASP awareness, input validation, secrets management, and dependency hygiene.

### Git Workflow — `docs/engineering/git-workflow.md`
Branching strategy, commit conventions, PR practices, and code review principles.

### Error Handling — `docs/engineering/error-handling.md`
Error patterns, logging, graceful degradation, and user-facing error design.

### Performance — `docs/engineering/performance.md`
Profiling before optimizing, algorithmic thinking, and avoiding premature optimization.

---

## Layer 3: Language-Specific Guides

Loaded conditionally based on stack detection above. Each language directory contains:

- **`idioms.md`** — Language-specific patterns, conventions, and anti-patterns
- **`testing.md`** — Framework-specific test patterns, fixtures, and assertion styles
- **`tooling.md`** — Build tools, linters, formatters, and configuration conventions

See the `docs/languages/` directory for available language guides.

---

## Loading Strategy

Do not load all documents upfront. Scale context to the task:

| Always load | Load for code tasks | Load on demand |
|---|---|---|
| This file (`agents.md`) | `docs/agentic/task-decomposition.md` | `docs/agentic/context-management.md` |
| `docs/agentic/guardrails.md` | `docs/agentic/tool-usage.md` | `docs/agentic/orchestration.md` |
| | `docs/agentic/verification.md` | `docs/agentic/continuous-improvement.md` |
| | `docs/engineering/testing.md` | `docs/engineering/architecture.md` |
| | `docs/engineering/code-quality.md` | `docs/engineering/security.md` |
| | Language guides (per stack detection) | `docs/engineering/git-workflow.md` |
| | | `docs/engineering/error-handling.md` |
| | | `docs/engineering/performance.md` |

**Always load:** Read for every task. These define safety boundaries and operating context.
**Load for code tasks:** Read when writing or modifying code.
**Load on demand:** Follow the reference when the task involves that specific topic.

---

## Operating Principles

These are the meta-rules that govern how you apply everything above:

1. **Test first, always** (for application code). Write a failing test before writing implementation code. Run it. See it fail. Then make it pass. Never fake a green test — no empty bodies, no `pass`, no `assert True`, no skipped assertions. For non-code changes (config, CI, docs), verify your work through other means — see `docs/engineering/testing.md`.
2. **Read before writing.** Never modify code you haven't read. Understand context before suggesting changes.
3. **Minimum viable change.** Do exactly what was asked. Don't refactor adjacent code, add features, or "improve" things that weren't requested — with one exception: small, safe, contained cleanups (< 10 lines, same file, covered by tests) within code you're already modifying. See `docs/agentic/continuous-improvement.md` for the boundary.
4. **Verify your work.** Run tests, check types, confirm builds. Don't declare success without evidence.
5. **Ask when uncertain.** A clarifying question costs seconds. A wrong assumption costs minutes to hours.
6. **Respect existing patterns.** Match the codebase's style, conventions, and architecture — even if you'd do it differently in a greenfield project.
7. **Think in blast radius.** Before any action, consider: what's the worst case if this goes wrong? Scale your caution to match.
8. **Think, then act.** For non-trivial tasks, structure your approach before executing: (1) state your understanding of the task, (2) identify which files to read, (3) plan changes, (4) execute, (5) verify. Structured reasoning catches assumptions.
9. **Progress over perfection.** Ship working increments. Don't block on getting everything perfect in one pass.

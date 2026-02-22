# Continuous Improvement

**Principle:** Every touch point is an opportunity. When you're already working in a file, assess what's around you — if small improvements align with the standards and fall within the blast radius of your current change, make them. If they're larger, flag them. The codebase should be measurably better after every interaction, not just in the code you were asked to write.

---

**Relationship to Operating Principle #3 (Minimum Viable Change):** The boy scout rule operates *within* the blast radius of your current change. You may improve code in a function you're already modifying. You may NOT modify other files or add scope that wasn't requested. When in doubt, flag the issue to the user rather than fixing it silently.

---

## Rules

### 1. The Boy Scout Rule — Leave It Better Than You Found It

When modifying a file, scan the immediate surroundings for violations of the engineering principles in this framework. If a fix is:

- **Small** (< 10 lines changed)
- **Safe** (covered by existing tests, or verifiable by running the test suite)
- **Contained** (doesn't ripple into other files)

Include it in your change — but **always report it** (see Consent Tiers below).

Examples of Tier 1 improvements:
- Renaming a poorly-named variable in a function you're already modifying
- Replacing a bare `except:` with a specific exception in code you're touching
- Removing dead code in a function you're editing
- Fixing a type annotation that's wrong or missing on code adjacent to your change
- Replacing string concatenation with interpolation in a line you're already changing

### 2. Consent Tiers

Every improvement falls into one of two tiers:

**Tier 1 — Allowed, always reported.** Small, safe, contained improvements (< 10 lines, same file, covered by tests). You can make these without asking first, but you **must list them in your task summary**. No invisible changes — ever.

```
✅ Task complete: Fixed the login validation bug in auth.ts.

Additional improvements made (Tier 1):
- Fixed wrong type annotation on `validateEmail` return type (line 42)
- Removed dead `legacyCheck` variable (line 67)
```

**Tier 2 — Requires user approval.** Anything that adds scope beyond Tier 1:
- Adding tests for existing untested code
- Structural refactors (extracting functions, splitting modules)
- New error handling for existing code
- Changes that touch other files
- Any architectural change

For Tier 2, flag the improvement and ask before proceeding.

Users can tighten this further in `.project-context.md` — including disabling Tier 1 entirely so everything requires approval.

### 3. Flag What You Can't Fix Inline

When you notice a larger issue that doesn't fit within your current task's blast radius, **tell the user**. Be specific:

```
While working on the login endpoint, I noticed:
- `UserService` has no test coverage (docs/engineering/testing.md violation)
- Database queries in `OrderRepository` are vulnerable to SQL injection (docs/engineering/security.md violation)
- The `utils/helpers.ts` file is a 400-line grab bag with no cohesion (docs/engineering/architecture.md violation)

These are outside the scope of the current task but worth addressing.
Want me to add these to TECH_DEBT.md, or tackle any of them now?
```

Don't fix these silently — they're too large. But don't ignore them either.

### 4. Debt Surfacing

Flagged issues need somewhere to go — otherwise they evaporate between sessions.

**Default mechanism: `TECH_DEBT.md` in the project root.** Repo-portable, requires no external tooling, visible to all agents across sessions.

When flagging issues, propose a concrete next step:
1. "Want me to add this to `TECH_DEBT.md`?" (default)
2. "Want me to tackle this as a follow-up task right now?"

**Group related issues** rather than flagging one at a time. At the end of a session with multiple findings, present them together with risk priority.

If `TECH_DEBT.md` already exists, **read it when starting a task in a related module**. Check if any listed items are relevant to the current work — this creates continuity across sessions.

Debt items should include:
- What's wrong and where (`OrderRepository.find_by_filter()` — SQL concatenation)
- Risk level (high / medium / low)
- Recommended action

Format: simple markdown, sections by risk level. Keep it scannable by humans and agents.

### 5. Opportunistic Test Addition

When you encounter code with no tests while working on a related change:

- If the untested code is **in a function you're modifying**, write a test for the existing behavior before making your change (this is just TDD applied retroactively)
- If the untested code is **adjacent but not being modified**, flag it but don't block your current task on it
- Never reduce test coverage — if you modify tested code, ensure the tests still pass and update them if needed

### 6. Migration Patterns

When you encounter an older pattern that has a modern equivalent in the standards, migrate it **if and only if** you're already modifying the code:

| Old Pattern | Modern Standard | Migrate When... |
|---|---|---|
| `var` without type hint (Python) | Type-annotated variables | You're editing the function |
| `String.Format` (C#) | String interpolation | You're modifying the line |
| Manual null checks | Optional/nullable types | You're refactoring the method |
| Callback-based async | async/await | You're modifying the async flow |
| Bare `except:`/`catch (Exception)` | Specific exception types | You're in the error handling path |
| `assertEqual` | Framework-idiomatic assertions | You're modifying the test |
| No `readonly`/`final`/`const` on immutable fields | Immutability markers | You're editing the class |

**Don't** go file-hunting for migration targets. Only migrate what you touch.

### 7. Health Assessments

When starting work on an unfamiliar module, spend 2 minutes assessing it against the standards before diving into the task. This is not a full audit — it's a quick scan:

1. **Tests exist?** Is there a test file? Does it have real assertions?
2. **Types sound?** Are there `any`, `dynamic`, untyped parameters?
3. **Error handling present?** Are errors caught and handled, or silently swallowed?
4. **Security basics?** Any hardcoded secrets, SQL concatenation, unsanitized input?
5. **Code quality?** Naming, structure, dead code, complexity?

If you find critical issues (security vulnerabilities, data loss risks), flag them immediately — even if they're unrelated to your task. Non-critical issues get flagged at the end of your task.

For a **full project-level assessment**, see `docs/agentic/health-snapshot.md`. The module-level scan here is the everyday quick version; the health snapshot is the comprehensive baseline.

### 8. Progressive Alignment

The goal is not to rewrite the codebase overnight. It's to create a **ratchet** — each interaction moves the codebase closer to the standards, and nothing moves it further away.

```
Day 1:   ████░░░░░░ 40% aligned
Day 30:  ██████░░░░ 60% aligned (many small improvements across many tasks)
Day 90:  ████████░░ 80% aligned (compounding effect)
Day 180: █████████░ 90% aligned (diminishing returns on remaining legacy)
```

This works because:
- Every new code is written to standard (passive benefit of the framework)
- Every touched file gets small improvements (active benefit of this doc)
- Large violations get flagged and queued via `TECH_DEBT.md` (visibility leads to action)
- Nothing regresses (the non-regression ratchets prevent backsliding)

**Make progress measurable.** Use coverage metrics and health snapshots (see `docs/agentic/health-snapshot.md`) to track alignment over time. Record milestones in `.project-context.md` so the ratchet is visible, not just conceptual.

### 9. What NOT to Improve Unprompted

Restraint matters as much as action. Don't:

- **Reformat files you're not modifying** — formatting-only PRs are noise
- **Refactor working code that you're not touching** — you might break it, and it's out of scope
- **Add docstrings/comments to code you didn't change** — that's drive-by annotation, not improvement
- **Upgrade dependencies unprompted** — dependency changes have unpredictable blast radius
- **Change architecture** — architectural improvements are never "small"; always discuss first
- **Migrate an entire file from old patterns** — only migrate the lines you're already changing

---

## The Improvement Hierarchy

When you have limited budget for improvement (you usually do), prioritize:

1. **Security fixes** — Always. Immediately. Even if out of scope.
2. **Bug-adjacent improvements** — If you're fixing a bug, harden the surrounding code
3. **Test coverage** — If you're modifying untested code, add tests for existing behavior first
4. **Type safety** — Add types/annotations to code you're touching
5. **Naming and clarity** — Rename confusing variables/functions in code you're editing
6. **Dead code removal** — Delete unused code in files you're modifying
7. **Pattern migration** — Modernize old patterns in lines you're already changing

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Ignore issues you notice in adjacent code | Flag them to the user with specific references |
| Rewrite an entire file because you found one issue | Fix what's in your blast radius, flag the rest |
| Make improvements without reporting them | Every improvement beyond the request appears in the task summary |
| Block your primary task on cleanup work | Finish the task, then suggest improvements |
| Improve code you haven't read thoroughly | Read and understand before changing |
| Skip tests for your improvements | Every change — even cleanup — must pass the existing suite |
| Let security issues slide because they're "out of scope" | Security is always in scope |

---

## Non-Regression Ratchets

The ratchet only moves forward. Agents must flag (Tier 2 — requires user approval) any change that would:

| Regression | What to flag |
|---|---|
| **Remove or weaken a test** | A test that passed before must pass after, unless the tested behavior is intentionally being removed |
| **Loosen type strictness** | Adding `any`, `// @ts-ignore`, removing type annotations, disabling strict flags |
| **Remove a CI/CD safety check** | Deleting a lint step, removing a security scan, disabling a git hook |
| **Break an API contract** | Changing a response shape, removing a field, changing behavior of an existing endpoint |
| **Contradict an established convention** | Introducing a pattern that conflicts with what `.project-context.md` or codebase inspection shows is the project's standard |

These are not "never do this" rules — they're "never do this silently." Flag the regression, explain what would change, and ask the user to confirm it's intentional. Sometimes regressions are the right call (removing a deprecated API, dropping a flaky test to rewrite it). The point is: the user decides, not the agent.

See `docs/engineering/architecture.md` (Open/Closed Workflows) for the structural principle behind these ratchets.

---

## Evolving Project Context

The framework is static — the docs don't change after install. But `.project-context.md` is the **extension point** where project-specific intelligence accumulates over time.

### When to Propose an Update

After observing a recurring pattern 2+ times in the codebase, propose adding it to `.project-context.md`:

- "I've noticed this project always uses factory functions instead of constructors. Want me to add this to `.project-context.md` so future sessions pick it up?"
- "The auth module came up as high-risk in the health snapshot. Want me to note that in `.project-context.md`?"
- "Coverage is now at 72%, up from 45% last month. Want me to record this milestone?"

Always a question, never a silent write. The user owns `.project-context.md`.

### What Belongs in Learned Patterns

- Project-specific conventions not captured by the framework's defaults
- Recurring architectural patterns unique to this codebase
- Risk areas identified by health snapshots
- Coverage baselines and progress milestones
- Technology decisions ("we use Redis for caching, not Memcached")

### What Does NOT Belong

- Temporary state or task-specific context
- Anything that duplicates the framework defaults
- Speculative observations from a single instance

### The Compound Effect

Over time, `.project-context.md` becomes a rich project-specific guide. An agent working in the repo 6 months after install has dramatically better context than one working on day 1 — not because the framework changed, but because the project accumulated intelligence. This is what makes the install gradually profound.
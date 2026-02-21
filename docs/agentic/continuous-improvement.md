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

Include it in your change. Don't ask — just improve it alongside your primary task.

Examples of improvements worth making silently:
- Renaming a poorly-named variable in a function you're already modifying
- Replacing a bare `except:` with a specific exception in code you're touching
- Removing dead code in a function you're editing
- Fixing a type annotation that's wrong or missing on code adjacent to your change
- Replacing string concatenation with interpolation in a line you're already changing

### 2. Flag What You Can't Fix Inline

When you notice a larger issue that doesn't fit within your current task's blast radius, **tell the user**. Be specific:

```
While working on the login endpoint, I noticed:
- `UserService` has no test coverage (docs/engineering/testing.md violation)
- Database queries in `OrderRepository` are vulnerable to SQL injection (docs/engineering/security.md violation)
- The `utils/helpers.ts` file is a 400-line grab bag with no cohesion (docs/engineering/architecture.md violation)

These are outside the scope of the current task but worth addressing. Want me to create issues or tackle any of these next?
```

Don't fix these silently — they're too large. But don't ignore them either.

### 3. Opportunistic Test Addition

When you encounter code with no tests while working on a related change:

- If the untested code is **in a function you're modifying**, write a test for the existing behavior before making your change (this is just TDD applied retroactively)
- If the untested code is **adjacent but not being modified**, flag it but don't block your current task on it
- Never reduce test coverage — if you modify tested code, ensure the tests still pass and update them if needed

### 4. Migration Patterns

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

### 5. Health Assessments

When starting work on an unfamiliar module, spend 2 minutes assessing it against the standards before diving into the task. This is not a full audit — it's a quick scan:

1. **Tests exist?** Is there a test file? Does it have real assertions?
2. **Types sound?** Are there `any`, `dynamic`, untyped parameters?
3. **Error handling present?** Are errors caught and handled, or silently swallowed?
4. **Security basics?** Any hardcoded secrets, SQL concatenation, unsanitized input?
5. **Code quality?** Naming, structure, dead code, complexity?

If you find critical issues (security vulnerabilities, data loss risks), flag them immediately — even if they're unrelated to your task. Non-critical issues get flagged at the end of your task.

### 6. Progressive Alignment

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
- Large violations get flagged and queued (visibility leads to action)
- Nothing regresses (the standards prevent backsliding)

### 7. What NOT to Improve Unprompted

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
| Make silent large-scope improvements | Only make small, safe, contained improvements silently |
| Block your primary task on cleanup work | Finish the task, then suggest improvements |
| Improve code you haven't read thoroughly | Read and understand before changing |
| Skip tests for your improvements | Every change — even cleanup — must pass the existing suite |
| Let security issues slide because they're "out of scope" | Security is always in scope |
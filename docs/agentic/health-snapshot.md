# Health Snapshot

**Principle:** You can't improve what you haven't measured. A health snapshot gives the project an honest baseline — and a way to track whether the ratchet is actually moving forward.

---

## When to Run

- **User requests it:** "Assess this project," "run a health check," "what's the state of our test coverage?"
- **Agent suggests it:** On first interaction with a codebase that has seal-team-6 installed but no prior snapshot, offer: "I notice this repo has seal-team-6 but no health snapshot yet — want me to run one?" The user must approve before proceeding.
- **Periodic re-run:** After significant work (a sprint, a major feature, a coverage push), suggest re-running to show progress.

A snapshot is **read-only analysis**. It never modifies code. All recommended actions require user approval before execution.

Configurable in `.project-context.md` — users can suppress the first-interaction suggestion.

---

## Assessment Dimensions

Score each dimension as **Red** (significant gaps), **Yellow** (partial coverage, some risk), or **Green** (solid).

### 1. Test Coverage

- **If a coverage tool is configured:** Run it. Report line coverage, branch coverage if available.
- **If no coverage tool:** Sample key modules. Do test files exist? Do they have real assertions (not empty bodies or `assert True`)? Are critical paths covered (auth, payments, data persistence)?
- **What to flag:** Modules with zero tests, test files with fake assertions, coverage below the project's target (if set in `.project-context.md`).

### 2. Type Safety

- Scan for `any`, `dynamic`, untyped function parameters, missing return types.
- **What to flag:** Functions with `any` parameters in critical paths, modules with no type annotations.

### 3. Architectural Health

- Look for god classes (files > 500 lines with multiple responsibilities), circular imports, separation of concerns violations.
- **What to flag:** Modules that mix business logic with infrastructure, high coupling between packages.

### 4. Security Posture

- Scan for hardcoded secrets, SQL string concatenation, unsanitized user input, outdated dependencies with known vulnerabilities.
- **What to flag:** Any finding here. Security issues are always flagged, even if everything else is green.

### 5. Error Handling

- Look for bare `except:`/`catch (Exception)`, swallowed errors (catch with no action), missing error boundaries at system edges.
- **What to flag:** Silent error swallowing in critical paths, no error handling at API boundaries.

---

## Output Format

Present results as a concise report. Be direct — don't soften bad news.

```
## Health Snapshot — [project name] — [date]

| Dimension          | Score  | Summary                                    |
|--------------------|--------|--------------------------------------------|
| Test Coverage      | Yellow | 45% line coverage; auth module untested    |
| Type Safety        | Green  | Strict mode enabled, minimal `any` usage   |
| Architecture       | Yellow | `UserService` is 800 lines, 3 responsibilities |
| Security           | Red    | SQL concatenation in `OrderRepository`     |
| Error Handling     | Yellow | Bare `except:` in 4 API endpoints          |

### Highest-Risk Areas (prioritized)
1. **SQL injection in `OrderRepository.find_by_filter()`** — Security, immediate risk
2. **No tests for `src/auth/`** — Coverage gap in critical path
3. **`UserService` god class** — Architectural debt, growing complexity

### Recommended Next Actions
1. Fix SQL injection (security — always first)
2. Add characterization tests for auth module
3. Break `UserService` into `UserAuth`, `UserProfile`, `UserNotifications`

Want me to tackle any of these, or add them to `TECH_DEBT.md`?
```

Adjust detail level to the project's size. A 5-file project doesn't need the same depth as a 500-file monorepo.

---

## After the Snapshot

- **Propose `.project-context.md` updates:** If the snapshot reveals patterns worth codifying (high-risk modules, established conventions, coverage baseline), suggest adding them to `.project-context.md`. This is how the framework learns about the project.
- **Offer to populate `TECH_DEBT.md`:** If multiple issues were found, offer to create or update `TECH_DEBT.md` with the findings, prioritized by risk.
- **Don't act without consent.** The snapshot is information, not authorization. Every recommended action is a proposal.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Run a snapshot without being asked or offering first | Always get user consent before spending time on assessment |
| Soften findings to avoid bad news | Be direct — "45% coverage" not "room for improvement" |
| Turn the snapshot into a full audit | Keep it to 5-10 minutes. This is a snapshot, not an engagement |
| Act on findings without approval | Present findings, propose actions, wait for consent |
| Skip dimensions because they "look fine" | Score all five. A quick "Green — looks solid" is still useful |
| Repeat the same snapshot every session | Only suggest re-runs after significant work or at meaningful intervals |

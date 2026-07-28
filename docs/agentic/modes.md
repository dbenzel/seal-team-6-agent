# Operating Modes

**Principle:** Match write-permission and depth of planning to task risk. Explore and plan freely; implement only with a clear scope; verify before claiming done.

---

## Modes

| Mode | When | May write code? | Exit criteria |
|---|---|---|---|
| **Explore** | Unfamiliar area, locating facts | No (read-only) | You can name the files/functions that matter |
| **Plan** | Multi-file or ambiguous work | No (docs/plan artifacts OK if asked) | Scoped steps, risks, and open questions listed |
| **Implement** | Scope agreed (or obviously small) | Yes, within scope | Changes match the plan / request |
| **Verify** | After meaningful edits | Tests/config only if needed for proof | Evidence reported (tests, types, build, manual check) |
| **Review** | Diff-focused pass before handoff | No (comments / suggested fixes) | Issues ranked; no silent drive-by edits |

---

## Decision Table

| Situation | Mode |
|---|---|
| "Where is X?" / "How does Y work?" | Explore |
| "Add a feature" spanning >2 files or unclear requirements | Plan, then Implement |
| One-line / single-file obvious fix with clear acceptance | Implement (skip formal Plan) |
| Just finished a non-trivial change | Verify before saying done |
| User asks "look over this" / pre-PR | Review |

---

## Rules

1. **Do not Implement while still Exploring.** If you discover the problem is different than assumed, return to Plan.
2. **Plan artifacts beat memory.** For long tasks, keep a short checklist the user can see.
3. **Verify is not optional** for code changes — see `docs/agentic/verification.md`.
4. **Review does not expand scope.** Suggest follow-ups; do not silently rewrite.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Start editing before locating the right module | Explore first |
| Write a 20-step plan for a one-line fix | Implement directly |
| Declare done without running checks | Enter Verify |
| "While I'm here" refactors during Review | Flag as Tier 2 / TECH_DEBT |

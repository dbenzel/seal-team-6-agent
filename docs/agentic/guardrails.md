# Guardrails

**Principle:** Every action has a blast radius. Scale your caution to match the potential impact of what you're about to do.

---

## Rules

### 1. Never Take Destructive Actions Without Explicit Confirmation

These actions require the user to explicitly request them — never do them proactively:

- `git push --force`, `git reset --hard`, `git clean -f`
- Deleting files, branches, or database tables
- Overwriting uncommitted changes
- Killing processes or stopping services
- Modifying CI/CD pipelines
- Posting to external services (Slack, email, GitHub comments)

**If in doubt, ask.** The cost of a confirmation prompt is near-zero. The cost of a destructive mistake can be hours of lost work.

### 2. Assess Blast Radius Before Acting

Before any non-trivial action, mentally answer:

- **Scope:** Does this affect one file, many files, or systems outside this repo?
- **Reversibility:** Can this be undone with a simple `git checkout` or undo? Or is it permanent?
- **Visibility:** Will anyone else see this action (teammates, CI, production users)?

| Blast Radius | Examples | Required Caution |
|---|---|---|
| Local, reversible | Edit a file, run tests | Proceed freely |
| Local, hard to reverse | Delete files, reset git state | Confirm with user |
| Shared/visible | Push code, create PR, post comment | Always confirm |
| Production-affecting | Deploy, modify infra, change permissions | Refuse unless explicitly instructed |

### 3. Investigate Before Overwriting

When you encounter unexpected state — unfamiliar files, branches, configuration, lock files — investigate before deleting or overwriting. It may represent the user's in-progress work.

- **Merge conflicts:** Resolve them, don't discard changes
- **Lock files:** Investigate what holds the lock before removing it
- **Uncommitted changes:** Stash or ask — never silently overwrite
- **Unknown branches:** Ask before deleting

### 4. Never Bypass Safety Checks

Do not use flags that skip safety mechanisms unless explicitly told to:

- `--no-verify` (skips git hooks)
- `--force` (skips conflict checks)
- `--no-check` or equivalent (skips type/lint checks)

If a safety check fails, fix the root cause. The check exists for a reason.

### 5. Secrets and Sensitive Data

- Never commit `.env`, credentials, API keys, or tokens
- Never log or display secrets in output
- If you encounter secrets in code, flag them to the user immediately
- Never hardcode secrets — always use environment variables or secret management

### 6. Stop and Escalate When

- You're about to do something you can't undo
- You've tried two approaches and both failed — re-plan instead of brute-forcing
- The user's request seems to conflict with their stated goals
- You're unsure about requirements and a wrong guess would be costly
- The codebase is in a state you don't understand

### 7. Scope Clarity

Before starting non-trivial work, establish what's in scope and what's not.

- **State your understanding:** "I'll fix the login validation bug in `auth.ts`. I won't modify the session management or add new tests for existing code unless you want me to."
- **When you discover adjacent problems:** Flag them distinctly from your primary task. Don't weave them into your work without signaling. Use the debt surfacing protocol in `docs/agentic/continuous-improvement.md`.
- **Scope expansion requires acknowledgment:** If while working you realize the task is larger than expected, pause and tell the user before expanding. "This bug traces back to a shared utility — fixing it properly requires also changing `utils/validation.ts`. Want me to proceed, or should I apply a narrow fix?"
- **Don't expand silently.** Even small scope creep compounds across tasks. If your change touches files or modules beyond what was discussed, flag it.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Delete a file to "fix" an import error | Find the actual root cause |
| Force-push to fix a messy history | Ask the user how they want to clean up |
| Skip failing tests to get a green build | Fix the tests or ask why they're failing |
| Overwrite a config file you don't understand | Read it, understand it, then modify surgically |
| Retry the same failed approach 3+ times | Step back, re-analyze, try a different angle |

# Git Workflow

**Principle:** Git history is a communication tool. Every commit, branch, and PR tells a story — make it one that future developers (including your future self) can follow.

---

## Rules

### 1. Commit Conventions

- **Atomic commits:** Each commit represents one logical change. Don't mix unrelated changes.
- **Descriptive messages:** Summarize the "why" not just the "what." "Fix race condition in session cleanup" > "Fix bug."
- **Present tense, imperative mood:** "Add validation" not "Added validation" or "Adds validation."
- **Body for context:** Use the commit body for non-obvious reasoning, links to issues, or alternative approaches considered.

```
feat: add email verification to signup flow

Users were creating accounts with invalid emails, causing delivery
failures. This adds a verification step before account activation.

Closes #142
```

### 2. Branching Strategy

- **Feature branches:** One branch per feature/fix, branched from `main`
- **Short-lived:** Merge within days, not weeks. Long-lived branches accumulate merge conflicts.
- **Descriptive names:** `feat/user-email-verification`, `fix/session-timeout-crash`, `refactor/auth-middleware`
- **Delete after merge:** Merged branches are clutter — clean them up

### 3. Pull Request Practices

- **Small PRs:** Easier to review, faster to merge, lower risk. Aim for < 400 lines changed.
- **Self-review first:** Read your own diff before requesting review. Catch the easy stuff yourself.
- **Describe the change:** PR description should explain what changed, why, and how to test it.
- **One concern per PR:** Don't mix feature work with refactoring. Separate PRs are easier to review and revert.

### 4. What to Commit

| Commit | Don't Commit |
|---|---|
| Source code | Build artifacts (`dist/`, `build/`) |
| Configuration files | Secrets (`.env`, credentials) |
| Lock files (`package-lock.json`, `poetry.lock`) | Editor-specific files (`.vscode/`, `.idea/`) unless team-shared |
| Test files | Large binary files |
| Documentation | Auto-generated code (unless it's checked-in by convention) |

### 5. Git Safety

- **Never force-push to shared branches** (`main`, `develop`, release branches) without team consensus
- **Never rewrite published history** — it breaks everyone else's checkout
- **Prefer merge over rebase** for shared branches — rebase is fine for local feature branches
- **Use `--no-ff` merges** for feature branches to preserve branch topology in history

### 6. Conflict Resolution

- **Resolve, don't discard.** Understand both sides of a conflict before choosing.
- **Pull before push.** Stay current with the base branch to minimize conflicts.
- **If unsure, ask.** When a conflict touches code you didn't write, check with the author.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| "WIP", "fix", "stuff" as commit messages | Write descriptive messages that explain why |
| One giant commit with 50 files changed | Break into logical atomic commits |
| Leave feature branches open for weeks | Merge frequently; use feature flags if needed |
| Commit `.env` or `node_modules` | Use `.gitignore` properly |
| Force-push to main | Work on feature branches and merge |

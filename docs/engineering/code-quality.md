# Code Quality

**Principle:** Code is read far more often than it is written. Optimize for clarity, simplicity, and consistency over cleverness.

---

## Rules

### 1. Naming

- **Functions:** Verb phrases that describe the action — `getUserById`, `validate_email`, `ParseConfig`
- **Variables:** Noun phrases that describe the content — `activeUsers`, `retry_count`, `maxTimeout`
- **Booleans:** Read as yes/no questions — `isValid`, `has_permission`, `shouldRetry`
- **Constants:** Screaming snake case with descriptive names — `MAX_RETRY_COUNT`, not `MRC`
- **No abbreviations** unless universally understood (`id`, `url`, `http` are fine; `usr`, `cnt`, `mgr` are not)
- **Scope-proportional length:** Loop variables can be short (`i`, `k`). Module-level variables should be descriptive.

### 2. Simplicity

- Prefer flat over nested — early returns reduce indentation
- Prefer explicit over clever — a straightforward `if/else` beats a tricky ternary chain
- Prefer standard patterns over custom abstractions — don't invent what the language provides
- Three similar lines of code is better than a premature abstraction
- Delete dead code — don't comment it out "just in case"

### 3. Formatting

- Follow the project's existing formatter/linter configuration
- If none exists, use the language's canonical formatter (Prettier, Black, gofmt, rustfmt)
- Never mix formatting changes with logic changes in the same commit
- Consistent indentation, consistent quote style, consistent brace placement

### 4. Functions

- Do one thing — if you need "and" to describe what a function does, split it
- Keep parameter lists short (≤ 3–4 params; use an options object/struct beyond that)
- Avoid side effects in functions that return values — separate queries from commands
- Avoid boolean parameters — they make call sites unreadable (`process(true, false)` vs. named options)

### 5. Comments

- Don't comment **what** the code does — the code should be self-evident
- Comment **why** when the reason isn't obvious — business rules, workarounds, non-obvious constraints
- Delete stale comments — a wrong comment is worse than no comment
- TODOs are acceptable but must be actionable ("TODO: handle pagination when API supports it")

### 6. DRY — But Not Too Dry

- Extract duplication only when the duplicated code changes for the same reason
- Two things can look identical but represent different concepts — don't merge them
- If extracting a helper makes the code harder to follow, leave the duplication

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| `data`, `info`, `temp`, `stuff` as variable names | Use specific, descriptive names |
| 6 levels of nesting | Use early returns and extract functions |
| Comment out code "for later" | Delete it — git has history |
| Reformat an entire file while fixing a bug | Keep formatting and logic changes separate |
| Create `StringUtils`, `Helpers`, `Common` modules | Name modules by what they do, not what they are |

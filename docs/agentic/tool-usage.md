# Tool Usage

**Principle:** Use the right tool for the job. Prefer dedicated tools over shell commands, parallelize independent operations, and avoid redundant work.

---

## Rules

### 1. Prefer Dedicated Tools Over Shell Commands

When a specialized tool exists for an operation, use it instead of a shell equivalent:

| Operation | Use This | Not This |
|---|---|---|
| Read a file | File read tool | `cat`, `head`, `tail` |
| Edit a file | File edit tool | `sed`, `awk`, shell redirects |
| Create a file | File write tool | `echo >`, `cat <<EOF` |
| Search file contents | Grep/search tool | `grep`, `rg` via shell |
| Find files by name | Glob/find tool | `find`, `ls` via shell |

**Why:** Dedicated tools give the user visibility into what you're doing, produce structured output, and are less error-prone than shell pipelines.

### 2. Parallelize Independent Operations

When you need multiple pieces of information and the queries don't depend on each other, run them simultaneously:

- Reading multiple files → parallel reads
- Searching for different patterns → parallel searches
- Running independent checks (lint + test + type-check) → parallel execution

**Don't parallelize** when results from one operation inform the next — that creates race conditions or wasted work.

### 3. Don't Duplicate Work

- If you delegate a search to a sub-agent, don't also run the same search yourself
- If you've already read a file in this session, don't re-read it unless you suspect it's changed
- If a tool returns an error, understand the error before retrying the same call

### 4. Match Tool to Scale

| Task Scale | Approach |
|---|---|
| Find a specific file | Direct glob/find |
| Search for a known pattern | Direct grep/search |
| Explore unfamiliar codebase area | Sub-agent with exploration scope |
| Multi-step research across many files | Sub-agent with specific research question |
| Simple file edit | Direct edit tool |
| Complex multi-file refactor | Plan first, then sequential edits |

### 5. Shell Commands: When and How

Reserve shell execution for operations that genuinely require it:

- Running builds, tests, linters
- Git operations
- Package manager commands (npm, pip, cargo, etc.)
- System commands (process management, network checks)

When using shell commands:
- Quote paths that might contain spaces
- Use `&&` for sequential dependent commands
- Prefer absolute paths over `cd` + relative paths
- Set reasonable timeouts for long-running operations
- Read command output — don't assume success

### 6. Avoid Tool Sprawl

Don't create elaborate tool chains when a simple approach works:

- One well-targeted search > five speculative searches
- Reading the right file > scanning twenty files hoping to find it
- Asking the user "where is X?" > spending 5 minutes searching for it

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Use `cat` to read a file when a read tool exists | Use the dedicated read tool |
| Run the same search three different ways "just in case" | Think about what you're looking for, search once, refine if needed |
| Shell out for everything | Use structured tools for file operations |
| Run a sub-agent for a simple file read | Use the tool directly |
| Retry a failed command identically | Understand why it failed first |

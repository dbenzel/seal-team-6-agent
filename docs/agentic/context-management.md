# Context Management

**Principle:** Your context window is finite and valuable. Be intentional about what you load into it — read what's relevant, skip what isn't, and structure your references to minimize waste.

---

## Rules

### 1. Read Strategically, Not Exhaustively

Don't read every file in a directory hoping to find what you need. Instead:

1. **Start with entry points** — `README.md`, `package.json`, `main.*`, `index.*`, `app.*`
2. **Follow imports** — trace the dependency chain from the file you're working on
3. **Search before reading** — use grep/search to find the right file before reading it
4. **Read selectively** — if a file is 500+ lines, read the relevant section, not the whole thing

### 2. Prioritize High-Signal Files

| High Signal (Read First) | Low Signal (Read If Needed) |
|---|---|
| The file being modified | Unrelated utility files |
| Direct imports of that file | Config files for unused features |
| Test files for the modified code | Documentation for familiar tools |
| Type definitions used by the code | Auto-generated files |
| README/docs describing the feature | Changelog/history files |

### 3. Build Mental Models, Not Transcripts

When exploring a codebase:

- **Map the structure** — understand the directory layout and module boundaries
- **Identify patterns** — how are routes defined? How are tests structured? Where do types live?
- **Note conventions** — naming patterns, file organization, import styles
- **Summarize, don't memorize** — "this module handles auth with JWT tokens" > reading every line of the auth module

### 4. Reference Efficiently

When you need to recall information from a file you've already read:

- Use file paths and line numbers rather than re-reading
- Reference specific function/class names rather than quoting entire blocks
- Link to the source rather than duplicating content in your response

### 5. Know When to Offload

If a research question requires reading many files across a large codebase:

- Delegate to a sub-agent with a specific question
- Let the sub-agent do the exhaustive search and return a focused answer
- This protects your main context from being flooded with search results

### 6. Manage Large File Reads

For files that exceed comfortable reading size:

- Read the file's structure first (function/class definitions, exports)
- Then read specific sections relevant to your task
- Don't read auto-generated files (bundles, lock files, compiled output) unless specifically needed
- If a file is too large to read at once, use line offsets to read in chunks

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Read every file in `src/` to understand the project | Read the entry point and follow imports |
| Re-read a file you read 2 minutes ago | Reference your existing understanding |
| Read a 2000-line file to find one function | Search for the function name, then read that section |
| Load entire test suites into context | Read only the tests relevant to your change |
| Read generated files (dist/, node_modules/, etc.) | Read source files only |

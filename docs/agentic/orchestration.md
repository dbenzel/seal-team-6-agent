# Orchestration & Reference Trees

**Principle:** Context is your scarcest resource. Structure guidance as a tree of references — load the root, follow only what's relevant, and delegate breadth-first work to sub-agents. The goal is maximum useful context with minimum token spend.

---

## Rules

### 1. Reference Trees Over Monolithic Documents

Large documents bloat context and dilute signal. Instead, structure guidance as a shallow tree:

```
agents.md (root — always loaded, ~100 lines)
│
├── References Layer 1 docs (load all — they're behavioral guardrails)
├── References Layer 2 docs (load all — they're engineering principles)
└── References Layer 3 docs (load selectively — only matching languages)
```

**Why this works:** The root file is concise enough to always fit in context. It tells the agent *what exists* and *when to load it*. The agent then follows references on-demand rather than ingesting everything upfront. This is the same principle as lazy evaluation — defer work until it's needed.

### 2. Design for Selective Loading

When writing reference documents:

- **Root files** should be summaries with pointers, not exhaustive content. A reader should understand *what each referenced doc covers* without opening it.
- **Referenced files** should be self-contained. If you follow a reference, you shouldn't need to also read 3 other files to understand it.
- **Conditional references** should have clear triggers. "If the project uses TypeScript, read X" is better than "read X if relevant."

| Good Reference | Bad Reference |
|---|---|
| "See `docs/security.md` for OWASP guidance and secrets management" | "See `docs/security.md`" (what's in it?) |
| "If `go.mod` exists, load `docs/languages/go/`" | "Load language docs as needed" (when is it needed?) |

### 3. Sub-Agent Orchestration

Sub-agents protect your primary context from being flooded by exploratory work. Use them for breadth; keep your main context for depth.

**When to spawn a sub-agent:**
- Searching across many files for a pattern you're not sure about
- Exploring an unfamiliar part of the codebase
- Running multiple independent research queries in parallel
- Any task where the intermediate results are high-volume but the answer is low-volume

**When NOT to spawn a sub-agent:**
- Reading a specific, known file (just read it directly)
- Running a single targeted search (just search directly)
- Tasks where you need the result before you can think about the next step (blocks your flow for marginal benefit)

### 4. Scope Sub-Agent Tasks Precisely

A sub-agent should receive:

1. **A specific question** — not "explore the codebase" but "find where authentication middleware is registered and what library it uses"
2. **Enough context** to answer without re-reading what you've already read
3. **Output format expectations** — "return the file path and relevant function name" not "tell me everything you find"

```
# Good sub-agent task
"Find all API endpoints that accept file uploads. Return a list of
file paths and function names."

# Bad sub-agent task
"Look at the codebase and tell me about the API."
```

### 5. Context Budgeting

Treat your context window as a budget. Every file you read, every search result you load, every sub-agent result you incorporate costs tokens and displaces other information.

**Budget allocation strategy:**

| Context Share | Purpose |
|---|---|
| ~20% | Understanding the task (user request, requirements, discussion) |
| ~30% | Reading the code being modified (the files you're changing) |
| ~20% | Reading related code (imports, types, tests for the code you're changing) |
| ~15% | Exploration and research (finding files, understanding patterns) |
| ~15% | Headroom for tool outputs, error messages, iteration |

When you're running low on context:
- Summarize what you've learned rather than keeping raw file contents
- Delegate remaining research to sub-agents
- Reference files by path and line number instead of quoting them
- Focus on the most critical remaining tasks

### 6. Parallel Sub-Agents for Independent Queries

When you have multiple independent research questions, spawn sub-agents in parallel rather than sequentially. This is faster and avoids polluting your context with intermediate results.

```
# Good: Parallel, independent queries
Sub-agent 1: "What test framework does this project use?"
Sub-agent 2: "What database does this project connect to?"
Sub-agent 3: "What CI/CD system is configured?"

# Bad: Sequential when parallelism is possible
Read CI config... now read test config... now read database config...
(each intermediate result bloats context)
```

### 7. Aggregation Over Accumulation

When sub-agents return results, extract only what you need:

- **Don't** paste the full sub-agent output into your working context
- **Do** summarize the key finding: "Sub-agent found that auth uses Passport.js, registered in `src/middleware/auth.ts:14`"
- **Do** keep specific references (file paths, line numbers) for follow-up
- **Don't** keep the raw search results that led to the finding

---

## How This Framework Uses Reference Trees

This document set (`agents.md` + `docs/`) is itself an example of the reference tree pattern:

1. **`agents.md`** (root) is ~100 lines. Always fits in context. Contains:
   - Stack detection table (conditional loading trigger)
   - One-sentence summary of each referenced doc (enough to decide whether to load it)
   - Operating principles (always-applicable rules)

2. **Layer 1 (agentic)** — 7 files. Guardrails are always loaded; the rest are loaded as they become relevant to the current task (see Loading Strategy in `agents.md`).

3. **Layer 2 (engineering)** — 7 files. Testing and code-quality are loaded for code tasks; the rest are loaded on demand (see Loading Strategy in `agents.md`).

4. **Layer 3 (languages)** — Loaded conditionally per stack. A Python project never loads the Rust guide. A polyglot project loads multiple.

5. **Override file** — Loaded only if it exists. Sparse by design — only contains deltas from defaults.

The total token cost of loading everything is high, but the typical cost per project is much lower because Layer 3 loads selectively.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Write one 500-line guidance document | Split into a root summary + referenced detail files |
| Load all documentation upfront "just in case" | Load the root, follow references as needed |
| Spawn a sub-agent for a single file read | Read it directly — sub-agents have overhead |
| Give sub-agents vague, open-ended tasks | Give specific questions with expected output format |
| Paste full sub-agent results into your context | Extract the key finding, discard the intermediate work |
| Read files sequentially when queries are independent | Parallel reads or parallel sub-agents |
| Keep raw search results in context after finding the answer | Summarize and discard the raw results |

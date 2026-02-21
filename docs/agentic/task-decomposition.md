# Task Decomposition

**Principle:** Complex work becomes manageable when broken into small, trackable, independently verifiable steps. Plan before you build, and re-plan when reality diverges from your plan.

---

## Rules

### 1. Decompose Before Executing

For any task that requires more than 3 steps or touches more than 2 files:

1. **Understand** — Read the relevant code and requirements
2. **Plan** — Break the work into discrete, ordered steps
3. **Track** — Use a todo list or similar mechanism to track progress
4. **Execute** — Work through steps one at a time, marking each complete

### 2. Good Task Granularity

Each subtask should be:

- **Independently verifiable** — You can confirm it's done without completing other tasks
- **Small enough to hold in context** — If you can't describe it in one sentence, break it down further
- **Ordered by dependency** — Don't start a task until its prerequisites are complete

| Too Coarse | Right Granularity | Too Fine |
|---|---|---|
| "Implement auth system" | "Create login endpoint" | "Write line 42 of auth.ts" |
| "Fix all the bugs" | "Fix null pointer in UserService.getById" | "Add null check" |
| "Refactor the app" | "Extract shared validation logic into utils/" | "Rename variable x to userId" |

### 3. Dependency Ordering

Identify task dependencies explicitly:

- **Independent tasks** can run in parallel — do them simultaneously when possible
- **Sequential tasks** must complete in order — don't skip ahead
- **Blocked tasks** are waiting on external input — flag them and move to unblocked work

### 4. Progress Tracking

- Mark tasks complete **immediately** when done — don't batch completions
- Only one task should be "in progress" at a time
- If a task reveals sub-tasks, add them to the list rather than trying to hold them in memory
- If a task turns out to be unnecessary, remove it — don't leave stale items

### 5. When to Re-Plan

Re-planning is not failure — it's adaptation. Trigger a re-plan when:

- A task is taking significantly longer than expected
- You discover the problem is different than initially understood
- Your approach is blocked and no workaround is obvious
- The user changes or clarifies requirements
- You've completed half the tasks and the remaining ones no longer make sense

### 6. Incremental Delivery

Prefer delivering working increments over big-bang completions:

- Get a minimal version working first, then enhance
- Commit or checkpoint after each meaningful step
- Show progress to the user — don't go silent for long stretches
- If the full task will take many steps, summarize progress periodically

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Dive into coding without understanding the full scope | Read relevant code and plan first |
| Keep a mental list of 10+ things to do | Write them down in a tracked list |
| Work on 3 things simultaneously | Finish one task before starting the next |
| Ignore new information that contradicts your plan | Re-plan based on what you've learned |
| Deliver everything at the end as one massive change | Ship incremental, verifiable progress |

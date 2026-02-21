# Performance

**Principle:** Measure before optimizing. The biggest performance wins come from algorithmic improvements and avoiding unnecessary work, not from micro-optimizations.

---

## Rules

### 1. Profile First

Never optimize based on intuition. Measure:

1. **Identify the symptom** — What is slow? Page load? API response? Build time?
2. **Measure the baseline** — Get a number. "Feels slow" is not a measurement.
3. **Profile to find the bottleneck** — Use profiling tools to find where time is actually spent.
4. **Optimize the bottleneck** — Focus on the hottest path. A 50% improvement to code that runs 1% of the time is meaningless.
5. **Measure again** — Confirm the optimization actually helped.

### 2. Algorithmic Thinking

The biggest wins come from choosing the right algorithm and data structure:

| Scenario | Slow | Fast |
|---|---|---|
| Finding an item in a list | Linear scan O(n) | Hash set/map O(1) |
| Checking for duplicates | Nested loop O(n²) | Set-based O(n) |
| Sorting | Bubble sort O(n²) | Built-in sort O(n log n) |
| Repeated string concat | String += in a loop O(n²) | StringBuilder/join O(n) |

Before optimizing the constants, ask: "Is the algorithm fundamentally right?"

### 3. Avoid Unnecessary Work

The fastest code is code that doesn't run:

- **Don't compute what you won't use** — lazy evaluation, pagination, early returns
- **Don't fetch what you won't display** — select specific fields, not `SELECT *`
- **Don't re-compute what hasn't changed** — caching, memoization
- **Don't block on what you don't need yet** — async operations, background jobs

### 4. Database Performance

Most application performance problems are database problems:

- Use indexes on columns you query frequently
- Avoid N+1 queries — fetch related data in batches
- Use `EXPLAIN` / query plans to understand query cost
- Don't fetch entire tables when you need one row
- Connection pooling reduces connection overhead

### 5. Caching

Cache when:
- The data is expensive to compute/fetch
- The data is requested frequently
- The data doesn't change often (or stale data is acceptable)

Cache invalidation is hard. Start with short TTLs and extend as confidence grows. When in doubt, don't cache — correct is more important than fast.

### 6. Premature Optimization

Avoid optimizing:
- Code that isn't a measured bottleneck
- Code that runs once (startup, migrations, scripts)
- Code where readability matters more than nanoseconds
- Hypothetical future scale problems

Optimize when:
- Users are experiencing measurable latency
- Costs are scaling non-linearly
- Profiling points to a specific hotspot

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| "I rewrote it in a more performant way" (without measuring) | Profile, optimize the bottleneck, measure the improvement |
| Optimize every function for speed | Optimize hot paths; leave cold paths readable |
| Cache everything | Cache only what's expensive, frequent, and stable |
| Use `SELECT *` everywhere | Select only the fields you need |
| Premature micro-optimization (bit shifting instead of division) | Write clear code; let the compiler optimize |

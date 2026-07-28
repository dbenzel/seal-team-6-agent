# Testing & Verification

**Principle:** Prove behavior before you declare done. Tests are evidence, not theater. Prefer test-first when risk or ambiguity is high; never ship fake greens.

---

## Evidence-First Decision Table

| Situation | Approach |
|---|---|
| Bug fix | Reproduce with a failing test (or failing script), then fix |
| New non-trivial logic / API contract | Test-first (red → green → refactor) |
| Refactor | Characterization tests first if coverage is thin; then refactor under green |
| Trivial / obvious single-line change with existing coverage | Implement, then run the relevant suite |
| UI copy, docs, pure config | Verify by build, preview, or checklist — not a fake unit test |
| Untested legacy you're about to touch | Add characterization coverage for the behavior you're changing before edits |

**Non-negotiable in all cases:** if you add or keep a test, it must be capable of failing. Empty bodies, `pass`, `assert True`, and placeholder assertions are forbidden.

---

## The TDD Protocol (when test-first applies)

Use this cycle for high-risk or ambiguous application code:

### 1. Red — Write a Failing Test

Write a test that describes the desired behavior. Run it. **It must fail.** If it passes before you've written any implementation, either:
- The behavior already exists (and you don't need to implement it), or
- Your test is wrong — it's not actually testing what you think it is

```
# The test MUST fail at this point.
# If it doesn't, stop. Figure out why before proceeding.
```

### 2. Green — Write the Minimum Implementation

Write the **smallest amount of code** that makes the test pass. No more. Don't anticipate future needs, don't add error handling for cases your test doesn't cover yet, don't refactor.

```
# Run the test suite. The new test must pass.
# All previously passing tests must still pass.
```

### 3. Refactor — Clean Up While Green

With all tests passing, clean up the implementation:
- Remove duplication
- Improve naming
- Simplify logic
- Extract functions if needed

**Run tests after every refactor step.** If anything goes red, undo the last refactor and try again.

### 4. Repeat

Each new behavior gets its own red-green-refactor cycle. Small cycles. Fast feedback.

---

## Rules

### 1. Never Fake a Passing Test

These are **strictly prohibited**:

| Language | Faking Pattern | Why It's Wrong |
|---|---|---|
| Python | `def test_foo(): pass` | Empty body always passes — tests nothing |
| Python | `assert True` | Tautology — can never fail |
| JavaScript | `test('foo', () => {})` | Empty callback always passes |
| JavaScript | `expect(true).toBe(true)` | Tautology |
| Any | `@skip` / `xit` / `pytest.mark.skip` on new tests | Skipping a test you just wrote defeats TDD |
| Any | `// TODO: add assertions` | A test without assertions is not a test |
| Any | Commenting out a failing assertion | Hiding failure is not fixing it |

**The test must be capable of failing.** If you remove the implementation and the test still passes, the test is broken.

### 2. Test Behavior, Not Implementation

Tests should describe **what** the code does, not **how** it does it:

```
# Good: Tests behavior
"returns the user's full name when first and last name are provided"
"raises ValueError when email format is invalid"
"redirects to login page when session is expired"

# Bad: Tests implementation details
"calls the database query method"
"sets the internal _cache variable"
"uses a for loop to iterate"
```

Implementation-coupled tests break when you refactor, even if the behavior is unchanged. That's a test smell.

### 3. The Testing Pyramid

Invest testing effort proportionally:

```
         /  E2E  \          Few — slow, expensive, high confidence
        /----------\
       / Integration \      Some — test component boundaries
      /----------------\
     /    Unit Tests     \  Many — fast, cheap, focused
    /----------------------\
```

- **Unit tests** (70%): Test individual functions/methods in isolation. Fast, focused, many of them.
- **Integration tests** (20%): Test component boundaries — API endpoints, database queries, service interactions.
- **E2E tests** (10%): Test critical user flows end-to-end. Expensive but high confidence.

### 4. When to Write Tests

- **New feature (non-trivial):** Prefer tests first; at minimum, land real tests before calling the work done
- **Bug fix:** Write a test that reproduces the bug first, then fix it
- **Refactor:** Existing tests should already cover the behavior — if they don't, add characterization tests before refactoring
- **Deleting code:** Verify no tests break; remove tests for deleted behavior

### 5. What NOT to Test

- Auto-generated code (unless you've modified it)
- Third-party library internals (test your usage of them, not the library itself)
- Trivial getters/setters with no logic
- Framework boilerplate (config files, route declarations with no custom logic)
- One-off scripts that aren't part of the application

### 6. When Full Test-First Does Not Apply

Evidence is still required. The *form* of evidence changes:

| Context | Verification Instead of Ritual TDD |
|---|---|
| Configuration (CI, Docker, infra) | Verify the build/deploy works |
| Documentation | Review for accuracy and completeness |
| Data migrations | Run against test data, verify results |
| Dependency updates | Run the existing test suite, verify build |
| One-off scripts | Test the script's output manually |
| Trivial edits with strong existing coverage | Run the relevant tests after the change |
| UI-only presentation tweaks | Visual/browser check or storybook/preview when available |

Skipping verification entirely is never acceptable. Inventing unit tests that only assert tautologies is worse than an honest manual check.

### 7. Test Quality Standards

Each test should:
- Have a descriptive name that reads as a specification
- Test exactly one behavior
- Be independent — no test should depend on another test's state
- Be deterministic — same result every run, no flakiness
- Be fast — unit tests should complete in milliseconds
- Clean up after itself — no leaked state, files, or processes

---

## Agentic Workflow

1. **Understand the requirement** — Read existing code, understand what needs to change
2. **Choose evidence level** — Use the decision table above (test-first vs implement-then-verify)
3. **If test-first:** write the test, run it, confirm red, then implement
4. **If implement-then-verify:** implement the minimal change, then run the relevant suite (and add tests if coverage for the changed behavior is missing)
5. **Confirm green / no regressions** — Read the output; don't assume success
6. **Refactor if needed** — Only under green, within blast radius
7. **Report** — Tell the user what you verified and the results

**Critical:** If you claim a new test proves a behavior, you must have observed it fail for the right reason (or be fixing a bug where the reproduction failed first). Never skip reading test output.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Skip verification because the change "looks small" | Run the relevant checks anyway |
| Force a full red-green ritual on a one-line copy tweak | Verify appropriately; don't invent theater tests |
| Write a test that passes immediately when doing test-first | Ensure it fails before implementation exists |
| Use `pass`, `True`, or empty bodies to get green | Write a real assertion against expected behavior |
| Skip a failing test instead of fixing it | Fix the code or fix the test — skipping is hiding |
| Write one giant test for multiple behaviors | One test per behavior, with a descriptive name |
| Test the mock instead of the code | Mocks should simulate dependencies, not replace the SUT |
| Ignore flaky tests | Fix them immediately — flaky tests erode trust in the suite |
| Write tests that take seconds each | Keep unit tests in milliseconds; optimize slow tests |

---

## Assessing & Improving Existing Coverage

Evidence-first governs new work. Most projects also have existing coverage gaps. This section addresses how to honestly assess coverage and systematically improve it.

### Measuring Coverage

Run coverage tools — the specific tool depends on the language (see language-specific guides in `docs/languages/`). Report:

- **Line coverage** — Which lines execute during tests. The baseline metric.
- **Branch coverage** — Whether both sides of every conditional are tested. More meaningful than line coverage alone.
- **Mutation testing** (stretch goal) — Whether tests actually catch bugs, not just execute code. High line coverage with low mutation scores means your tests run the code but don't assert on the results.

**A project that doesn't know its coverage number has a coverage problem.** The first step is always: measure. Record the baseline in `.project-context.md` so future sessions can track progress.

### Identifying High-Risk Gaps

Not all untested code is equally dangerous. When prioritizing what to test first:

| Priority | Risk Factor | Why |
|---|---|---|
| 1 | **Blast radius** | Code called by many modules — a bug here cascades. Test high-fanout code first. |
| 2 | **Domain criticality** | Auth, payments, data persistence, external integrations. A bug here has real-world consequences. |
| 3 | **Change frequency** | Frequently modified untested code is a live risk. Check `git log --stat` — files that change often without tests are ticking. |
| 4 | **Complexity** | High cyclomatic complexity + no tests = high probability of hidden bugs. Simple getters can wait. |

Stable, low-complexity, leaf-node code with no tests is dormant risk — worth tracking but not urgent.

### Coverage Improvement Protocol

This is always a **user-initiated** effort. Agents suggest, users decide scope.

1. **Establish baseline.** Run coverage. Record the number.
2. **User defines scope.** "Cover the auth module," "add tests for the top 5 riskiest files," or "get to 60% coverage." Never start a coverage campaign without explicit scope.
3. **Write characterization tests first.** Test existing behavior as-is — don't fix bugs or refactor while writing coverage. The goal is a safety net, not improvement.
4. **Run coverage before and after.** Report the delta. "Auth module: 12% → 78% line coverage."
5. **Never refactor untested code.** Test it first. Then refactor under test protection. This order is non-negotiable.
6. **Record progress in `.project-context.md`.** Coverage milestones create a visible ratchet.

### Coverage Targets

This framework doesn't set a number — that belongs in `.project-context.md` where each project sets its own target. But the principle is clear:

- Coverage should be **measured** (you know the number)
- Coverage should be **tracked** (you know whether it's going up or down)
- Coverage should be **trending upward** (the ratchet moves forward)
- Coverage should **never silently decrease** (see Non-Regression Ratchets in `docs/agentic/continuous-improvement.md`)

# Testing & Test-Driven Development

**Principle:** TDD is the default workflow, not an optional practice. A failing test is the starting point for every change — it defines what "done" looks like before you write a single line of implementation.

---

## The TDD Protocol

This is non-negotiable. Every implementation follows this cycle:

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

- **New feature:** Write tests first (TDD)
- **Bug fix:** Write a test that reproduces the bug first, then fix it
- **Refactor:** Existing tests should already cover the behavior — if they don't, add tests before refactoring
- **Deleting code:** Verify no tests break; remove tests for deleted behavior

### 5. What NOT to Test

- Auto-generated code (unless you've modified it)
- Third-party library internals (test your usage of them, not the library itself)
- Trivial getters/setters with no logic
- Framework boilerplate (config files, route declarations with no custom logic)
- One-off scripts that aren't part of the application

### 6. Test Quality Standards

Each test should:
- Have a descriptive name that reads as a specification
- Test exactly one behavior
- Be independent — no test should depend on another test's state
- Be deterministic — same result every run, no flakiness
- Be fast — unit tests should complete in milliseconds
- Clean up after itself — no leaked state, files, or processes

---

## TDD in Practice: Agentic Workflow

When working as an agent, TDD looks like this:

1. **Understand the requirement** — Read existing code, understand what needs to change
2. **Write the test** — Create a test file or add to an existing test file
3. **Run the test suite** — Confirm your new test fails (red)
4. **Implement** — Write the minimum code to pass the test
5. **Run the test suite again** — Confirm green (new test passes, no regressions)
6. **Refactor if needed** — Clean up while keeping tests green
7. **Report** — Tell the user what you tested and the results

**Critical:** Step 3 is not optional. You must observe the red state. If you skip it, you have no proof the test actually validates anything.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Write implementation first, tests after | Write the test first — always |
| Write a test that passes immediately | Ensure it fails before implementation exists |
| Use `pass`, `True`, or empty bodies to get green | Write a real assertion against expected behavior |
| Skip a failing test instead of fixing it | Fix the code or fix the test — skipping is hiding |
| Write one giant test for multiple behaviors | One test per behavior, with a descriptive name |
| Test the mock instead of the code | Mocks should simulate dependencies, not replace the SUT |
| Ignore flaky tests | Fix them immediately — flaky tests erode trust in the suite |
| Write tests that take seconds each | Keep unit tests in milliseconds; optimize slow tests |

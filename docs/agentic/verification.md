# Verification

**Principle:** Never declare a task complete without evidence that it works. Trust comes from verification, not confidence.

---

## Rules

### 1. Verify After Every Meaningful Change

After modifying code, run the appropriate checks before moving on:

| Change Type | Minimum Verification |
|---|---|
| Bug fix | Run the failing test, confirm it passes |
| New feature | Run existing tests + verify the new behavior |
| Refactor | Run the full test suite — refactors should change zero behavior |
| Config change | Verify the build/tool still works |
| Dependency change | Install, build, and run tests |
| File deletion | Verify nothing else imports/references the deleted file |

### 2. The Verification Ladder

Escalate verification based on change scope:

1. **Syntax check** — Does the code parse? (Fastest: type-check, lint)
2. **Unit tests** — Do individual functions still behave correctly?
3. **Integration tests** — Do components work together?
4. **Build** — Does the project compile/bundle successfully?
5. **Manual check** — Does the feature actually work as intended?

For small changes, steps 1-2 may suffice. For larger changes, go higher up the ladder.

### 3. Don't Trust Yourself — Trust the Tests

Common traps:

- "I'm sure this works, it's a simple change" → Run the tests anyway
- "The types check out, so the logic must be right" → Types don't verify behavior
- "I've done this a hundred times" → This codebase may have edge cases you haven't seen

### 4. Check for Collateral Damage

Your change might break something you didn't intend:

- **Imports:** Did you rename or move something that others import?
- **Types:** Did you change a type that's used elsewhere?
- **Side effects:** Did you change initialization order or shared state?
- **Tests:** Are there tests that depend on the exact behavior you changed?

When in doubt, run the full test suite rather than just the tests you think are relevant.

### 5. Verify the Negative Case Too

Don't just confirm your change works — confirm it doesn't break what was already working:

- If you fixed a bug, make sure the happy path still works
- If you added a feature, make sure existing features are unaffected
- If you changed error handling, make sure errors are still caught

### 6. Report What You Verified

When completing a task, briefly state what verification you performed:

- "Tests pass (23 passing, 0 failing)"
- "Build succeeds, no type errors"
- "Ran the dev server and confirmed the login flow works"
- "Searched for all references to the renamed function — all updated"

This gives the user confidence and creates a record of what was checked.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| "It should work" without running anything | Run the tests and report results |
| Only test the happy path | Also test error cases and edge cases |
| Skip verification for "trivial" changes | Trivial changes cause non-trivial bugs |
| Run tests but ignore the output | Read the output and confirm all pass |
| Verify one file but forget to check dependents | Search for references and verify the chain |

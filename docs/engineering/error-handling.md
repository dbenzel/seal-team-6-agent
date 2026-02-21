# Error Handling

**Principle:** Errors are expected, not exceptional. Design for them explicitly — anticipate failure at system boundaries, provide actionable messages, and never silently swallow errors.

---

## Rules

### 1. Fail Fast, Fail Loud

- Detect errors as close to the source as possible
- Don't let invalid state propagate through the system
- Throw/raise immediately when a precondition is violated
- Missing required configuration should crash at startup, not at 2 AM when the code path is first hit

### 2. Handle Errors at the Right Level

Not every function should catch errors. Handle them where you have enough context to do something useful:

| Level | Responsibility |
|---|---|
| **Function/method** | Validate inputs, throw on violation. Don't catch errors you can't handle. |
| **Service/module** | Catch errors from dependencies, translate them to domain-relevant errors. |
| **API boundary** | Catch all errors, map to appropriate HTTP status codes, log details, return safe messages. |
| **Top-level** | Last-resort catch-all. Log, alert, and return a generic error. Never expose internals. |

### 3. Error Messages

Good error messages are **actionable**. They tell the user (or developer) what happened, why, and what to do about it:

```
# Bad
"Error"
"Something went wrong"
"Invalid input"

# Good
"Email address must contain an @ symbol"
"Database connection failed: connection refused on port 5432. Check that PostgreSQL is running."
"API rate limit exceeded. Retry after 60 seconds."
```

### 4. Never Silently Swallow Errors

These patterns are bugs, not error handling:

```python
# Python — NEVER do this
try:
    risky_operation()
except:
    pass

# JavaScript — NEVER do this
try {
    riskyOperation();
} catch (e) {}
```

If you catch an error, you must do at least one of:
- Log it
- Re-throw it (possibly wrapped in a more specific error)
- Return an error value to the caller
- Recover and take an alternative action

### 5. Error Types and Hierarchies

- Use the language's standard error types when they fit
- Create custom error types for domain-specific failures
- Include context: what operation failed, what input caused it, what the caller can do

### 6. Logging

- Log errors with enough context to diagnose without reproducing
- Include: timestamp, error type, message, relevant IDs, stack trace
- Don't log sensitive data (passwords, tokens, PII)
- Use structured logging (JSON) in production for machine parseability
- Use log levels correctly: ERROR for failures, WARN for degraded states, INFO for normal operations, DEBUG for development

---

## Retry and Recovery

- **Retry only transient failures** — network timeouts, rate limits, temporary unavailability
- **Use exponential backoff** — don't hammer a failing service
- **Set a retry limit** — infinite retries turn transient failures into permanent hangs
- **Make operations idempotent** — if a retry succeeds, it shouldn't double-apply the operation

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| `catch (e) {}` / `except: pass` | Log, re-throw, or recover — never swallow |
| Return `null` to indicate an error | Use error types, Result types, or exceptions |
| Show stack traces to end users | Log the trace, show a safe message |
| Use generic "Something went wrong" | Provide specific, actionable error messages |
| Retry forever on non-transient errors | Fail fast when the error won't resolve by retrying |

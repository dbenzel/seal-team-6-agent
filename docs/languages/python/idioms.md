# Python Idioms: Patterns and Anti-Patterns

> **Principle:** Write Python that leverages the language's full type system, standard library, and idioms. Treat Python as a gradually typed, expressive language — not a scripting toy. Code should be explicit, predictable, and hostile to runtime surprises.

---

## Rules

1. **Use type hints everywhere (PEP 484).** Every function signature, every return type, every class attribute. Treat Python as a gradually typed language. Type hints are not optional documentation — they are machine-checked contracts that catch entire categories of bugs before runtime. Use `from __future__ import annotations` to enable postponed evaluation.

2. **Use dataclasses or Pydantic models for structured data, never raw dicts.** A `dict` with known keys is a dataclass waiting to happen. Raw dicts have no IDE support, no validation, no autocomplete, and silently accept typos in key names. Pydantic is preferred when data crosses a trust boundary (API input, config files, external data). Dataclasses are preferred for internal domain objects.

3. **Use `pathlib.Path` over `os.path`.** The `os.path` module is stringly-typed, procedural, and error-prone. `pathlib` provides an object-oriented interface with operator overloading (`/`), method chaining, and cross-platform correctness by default.

4. **Use f-strings for string formatting.** f-strings are faster, more readable, and less error-prone than `.format()` or `%` formatting. The only exception is when you need a reusable template string — use `str.format()` with named placeholders in that case.

5. **Use context managers (`with`) for all resource management.** Files, database connections, locks, temporary directories, HTTP sessions — anything that must be cleaned up. If you write a class that manages a resource, implement `__enter__` and `__exit__` or use `@contextmanager`.

6. **Prefer comprehensions over manual loops when the intent is transformation or filtering.** List, dict, and set comprehensions express "transform this collection" more clearly than a loop with `.append()`. But do not nest comprehensions more than one level deep — readability dies fast. If the comprehension exceeds one line, use a loop or extract a function.

7. **Use the `collections` module.** `defaultdict` eliminates key-existence checks. `Counter` replaces manual counting loops. `deque` provides O(1) append/pop from both ends. `namedtuple` (or its typed variant `NamedTuple`) gives lightweight immutable records. These exist for a reason — use them.

8. **Never use mutable default arguments.** Default arguments are evaluated once at function definition time, not at call time. A mutable default (list, dict, set) is shared across all calls, leading to some of the most confusing bugs in Python.

9. **Use `__slots__` for data-heavy classes.** When you have thousands or millions of instances of a class (e.g., graph nodes, parsed records), `__slots__` reduces memory usage by 40-60% and improves attribute access speed. The tradeoff is no dynamic attribute assignment — which is usually a feature, not a bug.

10. **Use `Enum` for fixed sets of values.** String constants scattered across a codebase are a refactoring nightmare. Enums provide type safety, IDE support, exhaustiveness checking (with `match`), and prevent invalid values at construction time.

11. **Use the walrus operator (`:=`) judiciously.** It shines in `while` loops with an assignment condition and in comprehensions that need to reuse a computed value. Do not use it in simple `if` statements where a separate assignment is clearer — readability is the priority.

12. **NEVER use bare `except:` — always catch specific exceptions.** A bare `except` catches `SystemExit`, `KeyboardInterrupt`, and `GeneratorExit` in addition to actual errors. At minimum, use `except Exception`. In production code, catch the narrowest exception type possible. Log or re-raise — never silently swallow.

13. **Use `itertools` and generators for large data processing.** Generators produce values lazily, keeping memory flat regardless of input size. `itertools.chain`, `islice`, `groupby`, `product`, and `starmap` compose into powerful pipelines without materializing intermediate lists.

---

## Examples

### Type Hints

```python
# DO: Full type annotations with modern syntax
from __future__ import annotations
from typing import Protocol

class Serializable(Protocol):
    def to_dict(self) -> dict[str, Any]: ...

def process_users(
    users: list[User],
    *,
    active_only: bool = True,
    limit: int | None = None,
) -> list[UserSummary]:
    ...

# DON'T: Untyped functions that force callers to read implementation
def process_users(users, active_only=True, limit=None):
    ...
```

### Dataclasses Over Dicts

```python
# DO: Structured, validated, self-documenting
from dataclasses import dataclass, field
from datetime import datetime

@dataclass(frozen=True)
class DeploymentConfig:
    service_name: str
    replicas: int
    environment: str
    created_at: datetime = field(default_factory=datetime.utcnow)

    def __post_init__(self) -> None:
        if self.replicas < 1:
            raise ValueError(f"replicas must be >= 1, got {self.replicas}")

config = DeploymentConfig(service_name="api", replicas=3, environment="prod")

# DON'T: Stringly-typed, no validation, no autocomplete
config = {
    "service_name": "api",
    "replicas": 3,
    "enviroment": "prod",  # typo goes undetected forever
}
```

### Pathlib

```python
# DO: Object-oriented, composable, cross-platform
from pathlib import Path

config_dir = Path.home() / ".config" / "myapp"
config_dir.mkdir(parents=True, exist_ok=True)

for log_file in config_dir.glob("*.log"):
    if log_file.stat().st_size > 10_000_000:
        log_file.unlink()

# DON'T: Stringly-typed, verbose, easy to get wrong
import os

config_dir = os.path.join(os.path.expanduser("~"), ".config", "myapp")
os.makedirs(config_dir, exist_ok=True)

for fname in os.listdir(config_dir):
    if fname.endswith(".log"):
        full_path = os.path.join(config_dir, fname)
        if os.path.getsize(full_path) > 10_000_000:
            os.remove(full_path)
```

### F-Strings

```python
# DO: Direct, readable, fast
name = "world"
count = 42
msg = f"Hello {name}, you have {count:,} items"
debug = f"{user.name!r} logged in at {timestamp:%Y-%m-%d %H:%M}"

# DON'T: Verbose, positional, error-prone
msg = "Hello {}, you have {:,} items".format(name, count)
msg = "Hello %s, you have %d items" % (name, count)
```

### Mutable Default Arguments

```python
# DO: Use None sentinel and create in function body
def add_item(item: str, items: list[str] | None = None) -> list[str]:
    if items is None:
        items = []
    items.append(item)
    return items

# DON'T: Mutable default shared across all calls
def add_item(item: str, items: list[str] = []) -> list[str]:
    items.append(item)  # this list persists between calls
    return items
```

### Exception Handling

```python
# DO: Specific exceptions, meaningful handling
import httpx

try:
    response = httpx.get(url, timeout=10.0)
    response.raise_for_status()
except httpx.TimeoutException:
    logger.warning(f"Request to {url} timed out, will retry")
    return retry_with_backoff(url)
except httpx.HTTPStatusError as exc:
    logger.error(f"HTTP {exc.response.status_code} from {url}")
    raise ServiceUnavailableError(url) from exc

# DON'T: Bare except swallows everything including Ctrl+C
try:
    response = httpx.get(url)
except:
    pass  # silently swallows TimeoutError, KeyboardInterrupt, SystemExit...
```

### Generators and itertools

```python
# DO: Lazy pipeline, constant memory regardless of input size
import itertools
from collections.abc import Iterator

def parse_log_lines(path: Path) -> Iterator[LogEntry]:
    with path.open() as f:
        for line in f:
            if line.startswith("ERROR"):
                yield LogEntry.from_line(line)

# Process first 100 errors without reading entire file
recent_errors = list(itertools.islice(parse_log_lines(huge_log), 100))

# DON'T: Materialize everything into memory
def parse_log_lines(path: Path) -> list[LogEntry]:
    results = []
    with path.open() as f:
        lines = f.readlines()  # entire file in memory
    for line in lines:
        if line.startswith("ERROR"):
            results.append(LogEntry.from_line(line))
    return results  # entire result set in memory
```

### Walrus Operator

```python
# DO: Useful in while loops and comprehensions
import re

# Avoid calling regex twice
if match := re.search(r"version=(\d+\.\d+)", text):
    version = match.group(1)

# Filter and transform in one pass
results = [
    cleaned
    for raw in data
    if (cleaned := expensive_normalize(raw)) is not None
]

# DON'T: Cramming walrus into simple assignments for no benefit
if (x := get_value()) > 10:  # just use two lines
    ...
```

---

## Anti-Patterns

| Anti-Pattern | Why It's Harmful | What to Do Instead |
|---|---|---|
| Raw dicts for known structures | No validation, no autocomplete, typos in keys go undetected | Use `@dataclass` or Pydantic `BaseModel` |
| Bare `except:` or `except Exception` with `pass` | Silently swallows errors, masks bugs, catches `KeyboardInterrupt` | Catch specific exceptions, log them, re-raise or handle meaningfully |
| Mutable default arguments (`def f(x=[])`) | Shared state across calls causes spooky action at a distance | Use `None` sentinel: `def f(x=None)` then `x = x or []` |
| `os.path.join()` chains | Stringly-typed, verbose, no method chaining | Use `pathlib.Path` with `/` operator |
| `isinstance` chains for dispatch | Fragile, violates Open/Closed principle, grows linearly | Use `match`/`case` (Python 3.10+), `singledispatch`, or polymorphism |
| String constants for state (`status = "active"`) | No validation, typos compile fine, refactoring is find-and-replace | Use `enum.Enum` or `enum.StrEnum` |
| `import *` | Pollutes namespace, breaks static analysis, makes dependencies invisible | Import specific names or use qualified imports |
| `type: ignore` without error code | Suppresses all type errors on a line, hides real issues | Use `type: ignore[specific-error]` to suppress only the known issue |
| Nested comprehensions (2+ levels deep) | Unreadable, un-debuggable, saves no meaningful performance | Use explicit loops or extract helper functions |
| Global mutable state (module-level dicts/lists modified at runtime) | Makes testing impossible, creates hidden coupling, breaks parallelism | Pass state explicitly or use dependency injection |
| `eval()` or `exec()` on user input | Remote code execution vulnerability | Use `ast.literal_eval` for data, or a proper parser |
| Manual `__init__` with many `self.x = x` lines | Boilerplate, easy to forget a field, no `__eq__` or `__repr__` | Use `@dataclass` or `attrs` |

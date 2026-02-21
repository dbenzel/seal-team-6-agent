# Rust Idioms & Patterns

**Principle:** Leverage Rust's type system and ownership model to eliminate entire categories of bugs at compile time. If the compiler can enforce an invariant, it should. Write code that is impossible to misuse, not merely difficult to misuse.

---

## Rules

### 1. Use the Type System to Make Illegal States Unrepresentable

Model your domain so that invalid states cannot be constructed. If a value can only be one of three things, use an enum with three variants — not a string, not an integer, not a boolean with a comment.

```rust
// Do: Illegal states are impossible
enum ConnectionState {
    Disconnected,
    Connecting { attempt: u32 },
    Connected { session: Session },
}

// Don't: Any combination of booleans is possible, including nonsensical ones
struct ConnectionState {
    is_connected: bool,
    is_connecting: bool,
    session: Option<Session>,  // Can be Some even when disconnected
    attempt: u32,              // Meaningless when connected
}
```

### 2. Prefer `Result` and `?` Over `.unwrap()`

`.unwrap()` is a controlled panic. Panics crash the program. In production code, propagate errors with `?` and let the caller decide how to handle failure. `.unwrap()` is acceptable only in tests, examples, and cases where you can *prove* the value is always `Some`/`Ok` (and even then, prefer `.expect("reason")` to document why).

```rust
// Do: Propagate errors
fn read_config(path: &Path) -> Result<Config, ConfigError> {
    let contents = fs::read_to_string(path)?;
    let config: Config = toml::from_str(&contents)?;
    Ok(config)
}

// Don't: Crash on any failure
fn read_config(path: &Path) -> Config {
    let contents = fs::read_to_string(path).unwrap();
    toml::from_str(&contents).unwrap()
}
```

### 3. Use `thiserror` for Libraries, `anyhow` for Applications

Library crates must expose structured, matchable error types so consumers can handle specific failures. Application crates need convenience — they rarely match on error variants, they just report them.

```rust
// Do: Library error type with thiserror
#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("record not found: {id}")]
    NotFound { id: String },
    #[error("connection failed after {attempts} attempts")]
    ConnectionFailed { attempts: u32 },
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

// Do: Application error handling with anyhow
use anyhow::{Context, Result};

fn main() -> Result<()> {
    let config = load_config()
        .context("failed to load application config")?;
    run_server(config)
        .context("server exited with error")?;
    Ok(())
}

// Don't: Use anyhow in a library (consumers can't match on error variants)
// Don't: Use thiserror in a binary with 50 error types you never match on
```

### 4. Prefer Borrowed Types in Function Signatures

Accept the most general borrowed form. `&str` covers both `&String` and string literals. `&[T]` covers `&Vec<T>`, arrays, and slices. This makes your API more flexible without any cost.

```rust
// Do: Accept borrowed slices
fn process_names(names: &[String]) { /* ... */ }
fn greet(name: &str) { /* ... */ }

// Don't: Require specific owned containers
fn process_names(names: &Vec<String>) { /* ... */ }
fn greet(name: &String) { /* ... */ }
```

### 5. Use `impl Trait` for Flexibility and Simplicity

In argument position, `impl Trait` lets callers pass any type satisfying the bound. In return position, it hides the concrete type and simplifies the signature.

```rust
// Do: Accept any iterator of items
fn sum_prices(items: impl Iterator<Item = &Item>) -> Decimal {
    items.map(|item| item.price).sum()
}

// Do: Return an opaque iterator
fn active_users(users: &[User]) -> impl Iterator<Item = &User> {
    users.iter().filter(|u| u.is_active)
}

// Don't: Force a specific collection type on the caller
fn sum_prices(items: Vec<Item>) -> Decimal { /* ... */ }
```

### 6. Prefer Iterators and Combinators Over Manual Loops

Iterator chains are more readable, harder to get wrong (no off-by-one errors), and the compiler optimizes them aggressively. Use `.map()`, `.filter()`, `.filter_map()`, `.flat_map()`, `.collect()`, and friends.

```rust
// Do: Iterator chain
let active_emails: Vec<&str> = users
    .iter()
    .filter(|u| u.is_active)
    .map(|u| u.email.as_str())
    .collect();

// Don't: Manual loop with mutation
let mut active_emails = Vec::new();
for i in 0..users.len() {
    if users[i].is_active {
        active_emails.push(users[i].email.as_str());
    }
}
```

### 7. Use `derive` Macros Liberally

Derive `Debug` on everything. Derive `Clone`, `PartialEq`, `Eq`, `Hash`, `Default`, and `Serialize`/`Deserialize` when appropriate. Manual trait implementations should be the exception, not the rule.

```rust
// Do: Derive what you need
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct UserId(pub u64);

#[derive(Debug, Default)]
pub struct QueryBuilder {
    filters: Vec<Filter>,
    limit: Option<usize>,
    offset: Option<usize>,
}

// Don't: Skip Debug — you will regret it during debugging
pub struct OpaqueBlob {
    data: Vec<u8>,
    // Good luck printing this in a log
}
```

### 8. Use Newtypes for Semantic Meaning

Bare primitives carry no domain meaning. A `u64` could be a user ID, a timestamp, a byte count, or a price in cents. Newtypes prevent mixing them up — the compiler catches it, not a code reviewer.

```rust
// Do: Newtypes with clear meaning
struct UserId(u64);
struct OrderId(u64);
struct Cents(u64);

fn find_order(user_id: UserId, order_id: OrderId) -> Option<Order> {
    // Can't accidentally swap user_id and order_id
    /* ... */
}

// Don't: Bare primitives
fn find_order(user_id: u64, order_id: u64) -> Option<Order> {
    // Caller can easily swap these two u64 arguments
    /* ... */
}
```

### 9. Prefer Enums with Data Over Boolean Flags or Stringly-Typed Code

Booleans have no semantic meaning at the call site. Strings can be anything. Enums are self-documenting, exhaustively matched, and impossible to misspell.

```rust
// Do: Enum with data
enum SortOrder {
    Ascending,
    Descending,
}

fn sort_results(results: &mut [Result], order: SortOrder) { /* ... */ }

// Don't: Boolean flag
fn sort_results(results: &mut [Result], ascending: bool) { /* ... */ }
// What does `sort_results(&mut r, true)` mean at the call site? Nobody knows.

// Do: Enum for status
enum PaymentStatus {
    Pending,
    Charged { amount: Cents, at: DateTime<Utc> },
    Refunded { reason: String },
    Failed { error: PaymentError },
}

// Don't: Stringly-typed status
struct Payment {
    status: String,       // "pending", "charged", "refund", "FAILED", ...
    amount: Option<u64>,  // Only set sometimes? Who knows.
    error: Option<String>,
}
```

### 10. Avoid `clone()` as a First Resort

Cloning is not wrong, but reaching for it before understanding the borrow checker is. First, try borrowing. Then try restructuring ownership. Then try `Rc`/`Arc` if shared ownership is genuinely needed. Clone when the alternatives are worse.

```rust
// Do: Borrow when possible
fn contains_admin(users: &[User]) -> bool {
    users.iter().any(|u| u.role == Role::Admin)
}

// Don't: Clone an entire collection just to iterate
fn contains_admin(users: Vec<User>) -> bool {
    // Caller had to clone or give up ownership
    users.iter().any(|u| u.role == Role::Admin)
}
```

### 11. Use `Cow<'_, str>` When Ownership Is Conditional

When a function sometimes returns a borrowed string and sometimes an owned one, `Cow` avoids unnecessary allocation in the common case.

```rust
use std::borrow::Cow;

// Do: Cow avoids allocation when no modification is needed
fn normalize_name(name: &str) -> Cow<'_, str> {
    if name.contains(' ') {
        Cow::Owned(name.trim().to_lowercase())
    } else {
        Cow::Borrowed(name)
    }
}

// Don't: Always allocate even when the input is fine as-is
fn normalize_name(name: &str) -> String {
    if name.contains(' ') {
        name.trim().to_lowercase()
    } else {
        name.to_string() // Unnecessary allocation
    }
}
```

### 12. Avoid `unsafe` Unless Absolutely Necessary

`unsafe` disables the compiler's guarantees. Every `unsafe` block is a promise from *you* that the invariants hold. When you must use it, document exactly what invariants you're upholding and why the compiler can't verify them.

```rust
// Do: Document safety invariants
/// # Safety
/// `ptr` must be a valid, aligned pointer to an initialized `Widget`.
/// The caller must ensure no other references to this `Widget` exist.
unsafe fn read_widget(ptr: *const Widget) -> Widget {
    // SAFETY: The caller guarantees ptr is valid, aligned, and unaliased.
    // This is required by the C FFI contract documented in widget.h.
    ptr.read()
}

// Don't: Undocumented unsafe
unsafe fn read_widget(ptr: *const Widget) -> Widget {
    ptr.read()  // Why is this safe? Under what conditions? Nobody knows.
}
```

### 13. Use `#[must_use]` Where Ignoring the Return Value Is a Bug

Functions that return a `Result`, a builder, or a value that *must* be consumed should be annotated. The compiler will warn callers who ignore the return value.

```rust
// Do: Annotate functions where ignoring the result is a mistake
#[must_use = "this returns a new string and does not modify the original"]
fn to_uppercase(s: &str) -> String {
    s.to_uppercase()
}

#[must_use = "the request is not sent until .send() is called"]
fn request(url: &str) -> RequestBuilder {
    RequestBuilder::new(url)
}

// Do: Annotate types where dropping unused values is a bug
#[must_use = "futures do nothing unless polled"]
struct ResponseFuture { /* ... */ }
```

---

## Anti-Patterns

| Don't | Do Instead | Why |
|---|---|---|
| `.unwrap()` in production code | `?` operator with proper error types | Unwrap panics; panics crash the program |
| `&String` or `&Vec<T>` in signatures | `&str` or `&[T]` | Borrowed slices are strictly more flexible |
| Boolean flags in function signatures | Enums with descriptive variants | Booleans have no meaning at the call site |
| Strings for state/status/category | Enums with data | Strings can't be exhaustively matched |
| `clone()` to silence the borrow checker | Restructure ownership or borrow correctly | Cloning hides design issues and wastes allocation |
| Bare primitives for domain types | Newtypes (`struct UserId(u64)`) | Prevents mixing up same-typed arguments |
| `unsafe` without safety comments | `// SAFETY:` comment documenting invariants | Future readers need to verify the safety argument |
| Manual loops with index variables | Iterator combinators (`.map()`, `.filter()`) | Iterators prevent off-by-one errors and are optimized |
| `anyhow::Error` in library public APIs | `thiserror` with structured error enums | Library consumers need matchable error types |
| Ignoring `#[must_use]` warnings | Handle or explicitly discard with `let _ =` | Ignored results are almost always bugs |
| Giant `match` on `Option` for simple cases | `.map()`, `.and_then()`, `.unwrap_or()` | Combinator methods are more concise and idiomatic |
| `impl MyType` with 2000 lines | Split into trait impls and focused `impl` blocks | Massive impl blocks are unnavigable |

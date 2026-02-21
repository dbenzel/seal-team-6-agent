# Rust Testing

**Principle:** Tests are first-class citizens in Rust. The language has built-in testing infrastructure — use it. Unit tests live next to the code they test, integration tests exercise the public API, and doc tests keep your examples honest. TDD is the default workflow (see [docs/engineering/testing.md](../../engineering/testing.md) for the protocol).

---

## Rules

### 1. Use the Built-In `#[cfg(test)]` Module Pattern

Unit tests live in a `#[cfg(test)] mod tests` block at the bottom of the file they test. This is not a suggestion — it is the Rust convention. The module is compiled only during `cargo test`, so it adds zero overhead to production builds. Being colocated with the implementation means tests can access private functions directly.

```rust
// Do: Tests at the bottom of the same file
pub fn calculate_tax(amount: Cents, rate: TaxRate) -> Cents {
    Cents((amount.0 as f64 * rate.0) as u64)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn calculates_tax_at_standard_rate() {
        let amount = Cents(10000); // $100.00
        let rate = TaxRate(0.08);  // 8%
        assert_eq!(calculate_tax(amount, rate), Cents(800));
    }

    #[test]
    fn zero_amount_yields_zero_tax() {
        assert_eq!(calculate_tax(Cents(0), TaxRate(0.08)), Cents(0));
    }
}

// Don't: Put unit tests in a separate file away from the code
// Don't: Forget #[cfg(test)] — your test helpers will be compiled into production
```

### 2. Integration Tests Go in the `tests/` Directory

Integration tests live in the top-level `tests/` directory. Each file there is compiled as a separate crate and can only access your library's public API. This is how you verify your public interface works correctly.

```
my_crate/
  src/
    lib.rs
    parser.rs      # Unit tests at the bottom of this file
    evaluator.rs   # Unit tests at the bottom of this file
  tests/
    integration.rs     # Tests the public API end-to-end
    parser_edge_cases.rs
```

```rust
// tests/integration.rs
use my_crate::{parse, evaluate};

#[test]
fn parses_and_evaluates_simple_expression() {
    let ast = parse("2 + 3").unwrap();
    let result = evaluate(&ast).unwrap();
    assert_eq!(result, Value::Integer(5));
}
```

### 3. Use Descriptive Assertion Messages

`assert_eq!`, `assert_ne!`, and `assert!` accept an optional format string. Use it. When a test fails in CI, the message is the difference between a 10-second diagnosis and a 10-minute investigation.

```rust
// Do: Descriptive messages
#[test]
fn rejects_empty_username() {
    let result = validate_username("");
    assert!(
        result.is_err(),
        "empty username should be rejected, but got: {:?}",
        result
    );
}

#[test]
fn calculates_correct_total() {
    let cart = Cart::new(vec![item(500), item(300), item(200)]);
    assert_eq!(
        cart.total(),
        Cents(1000),
        "cart with items costing 500 + 300 + 200 should total 1000 cents"
    );
}

// Don't: Bare assertions with no context
#[test]
fn test_thing() {
    assert!(validate_username("").is_err()); // Fails with "assertion failed: false"
}
```

### 4. Use `#[should_panic]` for Panic Testing

When a function is *supposed* to panic under certain conditions, use `#[should_panic]` with the `expected` substring to verify it panics with the right message. This prevents false positives from unrelated panics.

```rust
// Do: Specify the expected panic message
#[test]
#[should_panic(expected = "index out of bounds")]
fn panics_on_invalid_index() {
    let grid = Grid::new(3, 3);
    grid.get(10, 10);  // Should panic
}

// Don't: Bare should_panic catches any panic, including unrelated ones
#[test]
#[should_panic]
fn panics_on_invalid_index() {
    let grid = Grid::new(3, 3);
    grid.get(10, 10);
    // If Grid::new itself panics due to a bug, this test still passes. Bad.
}
```

### 5. Use Property-Based Testing for Invariants

`proptest` and `quickcheck` generate random inputs and verify that properties hold across thousands of cases. Use them for functions with wide input domains, parsers, serialization round-trips, and mathematical invariants.

```rust
// Do: Property-based tests for round-trip invariants
use proptest::prelude::*;

proptest! {
    #[test]
    fn serialize_deserialize_roundtrip(value: MyStruct) {
        let json = serde_json::to_string(&value).unwrap();
        let recovered: MyStruct = serde_json::from_str(&json).unwrap();
        prop_assert_eq!(value, recovered);
    }

    #[test]
    fn sort_preserves_length(mut vec in prop::collection::vec(any::<i32>(), 0..100)) {
        let original_len = vec.len();
        vec.sort();
        prop_assert_eq!(vec.len(), original_len);
    }
}
```

### 6. TDD Is the Default Workflow

Every implementation follows the Red-Green-Refactor cycle defined in [docs/engineering/testing.md](../../engineering/testing.md). Write the test first. Watch it fail. Write the minimum implementation to pass. Refactor. This is not optional.

```rust
// Step 1: Write the test (RED — this won't even compile yet)
#[test]
fn parses_valid_email() {
    let email = Email::parse("user@example.com").unwrap();
    assert_eq!(email.domain(), "example.com");
}

// Step 2: Write the minimum implementation to pass (GREEN)
// Step 3: Refactor while keeping tests green
// Step 4: Write the next test
```

### 7. Use `mockall` for Trait Mocking

When a function depends on a trait (database, HTTP client, clock), use `mockall` to create test doubles. Mock at trait boundaries, not at implementation details.

```rust
use mockall::automock;

#[automock]
trait UserRepository {
    fn find_by_id(&self, id: UserId) -> Result<Option<User>, DbError>;
    fn save(&self, user: &User) -> Result<(), DbError>;
}

#[test]
fn returns_error_when_user_not_found() {
    let mut mock_repo = MockUserRepository::new();
    mock_repo
        .expect_find_by_id()
        .with(eq(UserId(42)))
        .returning(|_| Ok(None));

    let service = UserService::new(mock_repo);
    let result = service.get_user(UserId(42));

    assert!(matches!(result, Err(ServiceError::UserNotFound { .. })));
}
```

### 8. Use `--nocapture` to See Output During Tests

By default, `cargo test` captures stdout. When debugging a test, use `cargo test -- --nocapture` to see `println!` and `dbg!` output. Remove debug prints before committing.

```
# See output from passing and failing tests
cargo test -- --nocapture

# Run a specific test with output
cargo test test_name -- --nocapture
```

### 9. Use `#[ignore]` for Slow Tests

Tests that hit real databases, external APIs, or take more than a few seconds should be marked `#[ignore]`. They run in CI with `cargo test -- --ignored` but don't slow down the local development loop.

```rust
#[test]
#[ignore = "requires running PostgreSQL instance"]
fn test_database_migration() {
    let db = connect_to_test_db();
    run_migrations(&db).unwrap();
    assert!(db.table_exists("users"));
}
```

```
# Local development: fast tests only
cargo test

# CI: run everything, including slow tests
cargo test
cargo test -- --ignored
```

### 10. Keep Doc Tests Passing

Examples in `///` doc comments are compiled and run as tests by `cargo test`. This means your documentation is always verified against the actual implementation. If a doc example fails, either the documentation or the code is wrong — fix whichever is stale.

```rust
/// Parses a hexadecimal color string into RGB components.
///
/// # Examples
///
/// ```
/// use my_crate::parse_hex_color;
///
/// let (r, g, b) = parse_hex_color("#FF8800").unwrap();
/// assert_eq!((r, g, b), (255, 136, 0));
/// ```
///
/// ```
/// use my_crate::parse_hex_color;
///
/// // Invalid input returns an error
/// assert!(parse_hex_color("not-a-color").is_err());
/// ```
pub fn parse_hex_color(hex: &str) -> Result<(u8, u8, u8), ParseError> {
    // ...
}
```

### 11. Use `test-case` for Parameterized Tests

When you need to test the same logic with multiple inputs, `test-case` generates a separate test for each case with a descriptive name. This is cleaner than a loop inside a single test and gives better failure messages.

```rust
use test_case::test_case;

#[test_case("hello", 5 ; "ascii string")]
#[test_case("", 0 ; "empty string")]
#[test_case("cafe\u{0301}", 5 ; "string with combining character")]
#[test_case("emoji 😀", 8 ; "string with emoji")]
fn char_count_matches_expected(input: &str, expected: usize) {
    assert_eq!(input.chars().count(), expected);
}

// Each test_case generates a separate test:
//   char_count_matches_expected::ascii_string
//   char_count_matches_expected::empty_string
//   char_count_matches_expected::string_with_combining_character
//   char_count_matches_expected::string_with_emoji
```

---

## Anti-Patterns

| Don't | Do Instead | Why |
|---|---|---|
| Put unit tests in separate `tests/unit/` files | Use `#[cfg(test)] mod tests` in the same file | Colocated tests can access private functions and stay in sync |
| Write `#[test] fn test_thing() { }` with an empty body | Write a real assertion that can fail | An empty test always passes — it tests nothing |
| Use `assert!(result == expected)` | Use `assert_eq!(result, expected)` | `assert_eq!` shows both values on failure; `assert!` just says "false" |
| `#[should_panic]` without `expected` | `#[should_panic(expected = "message")]` | Without `expected`, any panic passes the test, including unrelated bugs |
| Test private implementation details | Test the public API and observable behavior | Implementation-coupled tests break on every refactor |
| One giant test that checks 10 things | One test per behavior with a descriptive name | When a multi-assertion test fails, you can't tell which behavior broke |
| Skip writing the failing test first | Always observe Red before writing implementation | Without Red, you have no proof the test validates anything |
| Leave `println!` / `dbg!` in committed tests | Remove debug output before committing | Debug output clutters test runs and logs |
| Mock concrete types directly | Define traits at boundaries and mock the traits | Mocking concrete types couples tests to implementation |
| Write flaky tests that depend on timing | Use deterministic inputs; inject clocks and randomness | Flaky tests erode trust and waste CI minutes |
| Ignore failing doc tests | Fix the doc example or the implementation | Broken doc tests mean your documentation lies to users |
| Run slow tests in the default `cargo test` | Mark with `#[ignore]` and run separately in CI | Slow tests destroy the local development feedback loop |

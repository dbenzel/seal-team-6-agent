# Python Testing Best Practices

> **Principle:** Tests are executable specifications, not afterthoughts. Every test must assert something meaningful, every fixture must earn its existence, and the test suite must run fast enough that developers never skip it. TDD is the default workflow — write the test first, watch it fail, make it pass, refactor.

---

## Rules

1. **pytest is the primary test runner. Not unittest.** pytest has better assertion introspection, fixture injection, parametrize, plugin ecosystem, and requires less boilerplate. There is no reason to use `unittest.TestCase` in new code. If you inherit a unittest-based suite, migrate incrementally — pytest runs unittest tests natively.

2. **Use fixtures for setup and teardown, not `setUp`/`tearDown` methods.** pytest fixtures are composable, scopeable (function/class/module/session), and injected by name. They make dependencies explicit. `setUp`/`tearDown` are inherited from unittest and couple setup logic to class hierarchy.

3. **Use `pytest.raises` for exception testing.** It provides clear assertion syntax, captures the exception instance for further inspection, and integrates with pytest's reporting. Always assert on the exception message or attributes — don't just assert that *an* exception was raised.

4. **Use `pytest-mock` (which wraps `unittest.mock`) for mocking.** The `mocker` fixture provides automatic cleanup (no `@patch` decorator stacking), clear scoping, and integrates with pytest's fixture lifecycle. Prefer `mocker.patch` over `unittest.mock.patch` decorators.

5. **Use `factory_boy` or `faker` for test data generation.** Hand-constructing test objects with specific field values leads to brittle, verbose tests. Factories generate valid defaults and let tests override only the fields they care about, making the test's intent explicit.

6. **Use `pytest.mark.parametrize` for data-driven tests.** When the same logic needs testing with multiple inputs, parametrize avoids copy-paste test methods and clearly separates test logic from test data. Each parameter set gets its own test ID in the output.

7. **TDD is the default workflow.** Write the failing test first. Watch it fail for the right reason. Write the minimum code to make it pass. Refactor. This is not optional — it is the standard engineering protocol. See `docs/engineering/testing.md` for the full TDD protocol, including the Red-Green-Refactor cycle and commit cadence.

8. **CRITICAL: Never use `pass` in a test body.** A test function with `pass` as its body always passes. It tests absolutely nothing. It gives false confidence. It is worse than having no test at all because it inflates your test count and makes the suite look more comprehensive than it is. If you aren't ready to write the test, use `pytest.skip("TODO: implement")` or don't write the function.

9. **CRITICAL: Never use `assert True` or `assert 1` as a placeholder.** This is a tautology — it can never fail. It is semantically identical to `pass` but more deceptive because it looks like a real assertion. Every `assert` statement must reference the system under test.

10. **Use `hypothesis` for property-based testing where applicable.** When a function has a clear contract (e.g., "sort returns elements in ascending order", "serialize then deserialize is identity"), property-based testing finds edge cases that hand-written examples miss. Use it for data transformation, parsing, serialization, and mathematical operations.

11. **Aim for meaningful coverage, not a number.** 100% line coverage with garbage assertions is worse than 80% coverage with rigorous assertions. Use `coverage` to find untested *branches and error paths*, not to chase a metric. Coverage is a tool for discovering blind spots, not a goal in itself.

---

## Examples

### Fixtures Over setUp/tearDown

```python
# DO: Composable, explicit dependency injection
import pytest
from myapp.db import Database
from myapp.models import User

@pytest.fixture
def db() -> Database:
    database = Database(":memory:")
    database.run_migrations()
    yield database
    database.close()

@pytest.fixture
def sample_user(db: Database) -> User:
    return User.create(db, name="Ada Lovelace", email="ada@example.com")

def test_user_can_update_email(db: Database, sample_user: User) -> None:
    sample_user.update_email("new@example.com")
    reloaded = User.get_by_id(db, sample_user.id)
    assert reloaded.email == "new@example.com"


# DON'T: Inherited state, implicit dependencies, class hierarchy coupling
import unittest

class TestUser(unittest.TestCase):
    def setUp(self):
        self.db = Database(":memory:")
        self.db.run_migrations()
        self.user = User.create(self.db, name="Ada Lovelace", email="ada@example.com")

    def tearDown(self):
        self.db.close()

    def test_user_can_update_email(self):
        self.user.update_email("new@example.com")
        reloaded = User.get_by_id(self.db, self.user.id)
        self.assertEqual(reloaded.email, "new@example.com")
```

### Exception Testing

```python
# DO: Assert on specific exception type and message content
import pytest
from myapp.auth import Authenticator, InvalidCredentialsError

def test_login_rejects_wrong_password(authenticator: Authenticator) -> None:
    with pytest.raises(InvalidCredentialsError, match="Invalid password for user"):
        authenticator.login(username="ada", password="wrong")

def test_login_error_contains_username(authenticator: Authenticator) -> None:
    with pytest.raises(InvalidCredentialsError) as exc_info:
        authenticator.login(username="ada", password="wrong")
    assert exc_info.value.username == "ada"
    assert exc_info.value.attempts_remaining == 2


# DON'T: Catch broad exception, no message assertion
def test_login_fails(authenticator):
    with pytest.raises(Exception):
        authenticator.login(username="ada", password="wrong")
```

### Mocking with pytest-mock

```python
# DO: mocker fixture, scoped automatically, explicit about what's replaced
from myapp.notifications import NotificationService
from myapp.orders import OrderProcessor

def test_order_sends_confirmation_email(
    mocker: MockerFixture,
    order_processor: OrderProcessor,
) -> None:
    mock_send = mocker.patch.object(
        NotificationService, "send_email", return_value=True
    )

    order_processor.complete_order(order_id=42)

    mock_send.assert_called_once_with(
        to="customer@example.com",
        subject="Order #42 confirmed",
        body=mocker.ANY,  # don't over-specify the body
    )


# DON'T: Stacked decorators, positional injection, confusing argument order
@mock.patch("myapp.orders.NotificationService.send_email")
@mock.patch("myapp.orders.InventoryService.reserve")
@mock.patch("myapp.orders.PaymentService.charge")
def test_order(mock_charge, mock_reserve, mock_send):  # reversed order!
    ...
```

### Parametrize for Data-Driven Tests

```python
# DO: Test logic written once, data clearly separated
import pytest
from myapp.validators import validate_email

@pytest.mark.parametrize(
    "email, expected_valid",
    [
        ("user@example.com", True),
        ("user+tag@example.com", True),
        ("user@sub.domain.com", True),
        ("", False),
        ("not-an-email", False),
        ("@no-local-part.com", False),
        ("user@", False),
        ("user @example.com", False),  # space in local part
    ],
    ids=lambda val: str(val),  # readable test IDs in output
)
def test_email_validation(email: str, expected_valid: bool) -> None:
    assert validate_email(email) == expected_valid


# DON'T: Copy-pasted test methods with one value changed
def test_valid_email():
    assert validate_email("user@example.com") is True

def test_valid_email_with_tag():
    assert validate_email("user+tag@example.com") is True

def test_invalid_empty():
    assert validate_email("") is False
# ... 5 more identical functions
```

### Factory Boy for Test Data

```python
# DO: Factories with sane defaults, tests override only what matters
import factory
from myapp.models import User, Order

class UserFactory(factory.Factory):
    class Meta:
        model = User

    name = factory.Faker("name")
    email = factory.LazyAttribute(lambda obj: f"{obj.name.lower().replace(' ', '.')}@example.com")
    is_active = True
    created_at = factory.Faker("date_time_this_year")

class OrderFactory(factory.Factory):
    class Meta:
        model = Order

    user = factory.SubFactory(UserFactory)
    total_cents = factory.Faker("random_int", min=100, max=100000)
    status = "pending"

def test_inactive_user_cannot_place_order(order_service: OrderService) -> None:
    user = UserFactory(is_active=False)  # only override what matters
    with pytest.raises(InactiveUserError):
        order_service.place_order(user=user, items=[...])


# DON'T: Verbose, brittle, tests full of irrelevant details
def test_inactive_user_cannot_place_order(order_service):
    user = User(
        name="Test User",
        email="test@test.com",
        is_active=False,
        created_at=datetime(2024, 1, 1),
        role="customer",
        plan="free",
        avatar_url=None,  # none of this matters for the test
    )
    ...
```

### The Pass/Assert True Anti-Pattern

```python
# DO: Every test asserts something meaningful about the system
def test_user_creation_assigns_uuid(db: Database) -> None:
    user = User.create(db, name="Ada Lovelace", email="ada@example.com")
    assert user.id is not None
    assert isinstance(user.id, uuid.UUID)

# DO: If the test isn't ready, be explicit about it
@pytest.mark.skip(reason="TODO: implement after auth module is complete")
def test_user_password_reset() -> None:
    ...

# DO: If you just want to verify no exception is raised, be explicit
def test_config_loads_without_error(tmp_path: Path) -> None:
    config_file = tmp_path / "config.toml"
    config_file.write_text('[server]\nhost = "localhost"\nport = 8080\n')
    config = Config.from_file(config_file)  # implicit: no exception raised
    assert config.server.host == "localhost"


# DON'T: These "tests" are lies — they always pass
def test_user_creation():
    pass

def test_user_deletion():
    assert True

def test_order_processing():
    assert 1
```

### Property-Based Testing with Hypothesis

```python
# DO: Express invariants, let hypothesis find edge cases
from hypothesis import given, strategies as st
from myapp.serialization import serialize, deserialize

@given(st.dictionaries(
    keys=st.text(min_size=1, max_size=50),
    values=st.one_of(st.integers(), st.text(), st.floats(allow_nan=False), st.booleans()),
    max_size=20,
))
def test_serialize_deserialize_roundtrip(data: dict) -> None:
    """Serialization followed by deserialization is the identity function."""
    assert deserialize(serialize(data)) == data

@given(st.lists(st.integers()))
def test_sort_preserves_length(xs: list[int]) -> None:
    assert len(sorted(xs)) == len(xs)

@given(st.lists(st.integers(), min_size=1))
def test_sort_produces_ascending_order(xs: list[int]) -> None:
    result = sorted(xs)
    for a, b in zip(result, result[1:]):
        assert a <= b
```

---

## Anti-Patterns

| Anti-Pattern | Why It's Harmful | What to Do Instead |
|---|---|---|
| `pass` in test body | Always passes, tests nothing, inflates test count, creates false confidence | Write a real assertion or use `pytest.skip("reason")` |
| `assert True` / `assert 1` | Tautology that can never fail — identical to `pass` but more deceptive | Assert on actual system output: `assert result == expected` |
| `unittest.TestCase` in new code | Verbose, class-based boilerplate, weaker assertion introspection | Use plain pytest functions with fixtures |
| `setUp`/`tearDown` methods | Implicit, coupled to class hierarchy, not composable | Use pytest `@pytest.fixture` with `yield` for teardown |
| Stacked `@mock.patch` decorators | Reversed argument injection order, hard to read, easy to mismatch | Use `mocker` fixture from `pytest-mock` |
| Hand-building complex test objects | Verbose, brittle, clutters test with irrelevant details | Use `factory_boy` factories with sensible defaults |
| Testing implementation instead of behavior | Tests break on every refactor, provide no confidence in correctness | Test public API and observable behavior, not internal method calls |
| `time.sleep()` in tests | Flaky, slow, race conditions still possible | Use `pytest-timeout`, mock time, or use proper async waiting |
| Asserting on exact error messages | Breaks when messages are rephrased, tests style not substance | Use `pytest.raises(match=...)` with a substring or regex |
| One giant test function with many asserts | First failure hides subsequent issues, hard to identify what broke | Split into focused tests, each with a clear name describing the scenario |
| No test isolation (shared mutable state between tests) | Test order dependency, flaky CI, impossible to run tests in parallel | Use fixtures with proper scope, reset state in teardown |
| Mocking everything | Tests become a mirror of implementation, break on any refactor, prove nothing | Mock at boundaries (I/O, network, time), test real logic directly |

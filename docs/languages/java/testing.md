# Java Testing

> **Principle:** Tests are executable specifications that prove your code works. JUnit 5 is the framework, AssertJ is the assertion language, Mockito isolates dependencies, and Testcontainers makes integration tests real. TDD is the default workflow (see [docs/engineering/testing.md](../../engineering/testing.md) for the protocol). Every test must be capable of failing -- if you remove the implementation and the test still passes, the test is broken.

---

## Rules

### 1. JUnit 5 Is the Primary Test Framework

JUnit 5 (Jupiter) is the standard. Not JUnit 4. Not TestNG. JUnit 4's `@Test` lives in `org.junit`, JUnit 5's lives in `org.junit.jupiter.api`. If you see `import org.junit.Test` in new code, it's wrong. JUnit 5 provides a modern extension model (`@ExtendWith`), parameterized tests, nested test classes, display names, and conditional execution -- none of which exist in JUnit 4 without hacks.

```java
// DO: JUnit 5
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;

// DON'T: JUnit 4
import org.junit.Test;
import org.junit.Before;
```

### 2. Use `@DisplayName` for Human-Readable Test Names

Method names are identifiers -- they can't contain spaces, punctuation, or read as natural sentences. `@DisplayName` decouples the specification from the method name. The display name should read as a requirement: what the system does under what conditions.

```java
// DO: DisplayName reads as a specification
@Test
@DisplayName("returns empty list when no users match the filter criteria")
void returnsEmptyListWhenNoUsersMatchFilter() {
    List<User> result = userService.findUsers(Filter.withRole("nonexistent"));
    assertThat(result).isEmpty();
}

// DON'T: Method name as the only description
@Test
void testFindUsers() {  // What about findUsers? What behavior? What condition?
    // ...
}
```

### 3. Use `@Nested` for Test Organization

`@Nested` groups related tests into inner classes, creating a hierarchical structure that mirrors the behavior being tested. Each nested class represents a context or scenario. This replaces the flat list of test methods that forces you to encode context in method names.

```java
@DisplayName("OrderService")
class OrderServiceTest {

    @Nested
    @DisplayName("when creating an order")
    class WhenCreatingAnOrder {

        @Test
        @DisplayName("calculates total from line items")
        void calculatesTotalFromLineItems() { /* ... */ }

        @Test
        @DisplayName("rejects empty line item list")
        void rejectsEmptyLineItemList() { /* ... */ }

        @Nested
        @DisplayName("with a discount code")
        class WithDiscountCode {

            @Test
            @DisplayName("applies percentage discount to subtotal")
            void appliesPercentageDiscount() { /* ... */ }

            @Test
            @DisplayName("rejects expired discount code")
            void rejectsExpiredDiscountCode() { /* ... */ }
        }
    }

    @Nested
    @DisplayName("when cancelling an order")
    class WhenCancellingAnOrder {
        @Test
        @DisplayName("throws if order is already shipped")
        void throwsIfAlreadyShipped() { /* ... */ }
    }
}
```

### 4. Use `@ParameterizedTest` for Data-Driven Tests

When the same logic must be verified with multiple inputs, parameterized tests eliminate duplication. Use `@ValueSource` for simple single-argument cases, `@CsvSource` for multi-argument tabular data, and `@MethodSource` for complex objects or when the test data needs computation.

```java
// DO: Parameterized with CsvSource for tabular data
@ParameterizedTest(name = "\"{0}\" should be {1}")
@CsvSource({
    "hello@example.com, true",
    "invalid-email,     false",
    "'',                false",
    "user@.com,         false",
    "user@domain.co.uk, true"
})
void validatesEmailFormat(String email, boolean expected) {
    assertThat(EmailValidator.isValid(email)).isEqualTo(expected);
}

// DO: MethodSource for complex test data
@ParameterizedTest
@MethodSource("provideInvalidOrders")
@DisplayName("rejects invalid orders with descriptive message")
void rejectsInvalidOrders(Order order, String expectedMessage) {
    assertThatThrownBy(() -> orderService.validate(order))
        .isInstanceOf(ValidationException.class)
        .hasMessageContaining(expectedMessage);
}

static Stream<Arguments> provideInvalidOrders() {
    return Stream.of(
        Arguments.of(orderWithNoItems(), "must have at least one item"),
        Arguments.of(orderWithNegativeTotal(), "total must be positive"),
        Arguments.of(orderWithNullCustomer(), "customer must not be null")
    );
}

// DON'T: Copy-pasted tests that differ only in input data
@Test void validEmail1() { assertTrue(EmailValidator.isValid("a@b.com")); }
@Test void validEmail2() { assertTrue(EmailValidator.isValid("x@y.co.uk")); }
@Test void invalidEmail1() { assertFalse(EmailValidator.isValid("bad")); }
@Test void invalidEmail2() { assertFalse(EmailValidator.isValid("")); }
```

### 5. Use Mockito with `MockitoExtension`

Mockito is the mocking framework. Register it with `@ExtendWith(MockitoExtension.class)` -- not the JUnit 4 `MockitoJUnitRunner`. Use `@Mock` for dependencies, `@InjectMocks` for the system under test, and `@Captor` for argument capture. Configure strict stubbing (the default in MockitoExtension) -- it fails if you stub something that's never called, catching copy-paste errors and dead test code.

```java
// DO: MockitoExtension with field injection
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private InventoryClient inventoryClient;

    @Mock
    private PaymentGateway paymentGateway;

    @InjectMocks
    private OrderService orderService;

    @Test
    @DisplayName("reserves inventory before charging payment")
    void reservesInventoryBeforeChargingPayment() {
        when(inventoryClient.reserve(any())).thenReturn(Reservation.confirmed());
        when(paymentGateway.charge(any())).thenReturn(PaymentResult.success());

        orderService.placeOrder(testOrder());

        var inOrder = inOrder(inventoryClient, paymentGateway);
        inOrder.verify(inventoryClient).reserve(any());
        inOrder.verify(paymentGateway).charge(any());
    }
}

// DON'T: Manual mock setup without the extension
class OrderServiceTest {
    @Test
    void test() {
        InventoryClient mock = Mockito.mock(InventoryClient.class); // verbose
        // ... no strict stubbing, no automatic validation
    }
}
```

### 6. Use AssertJ for Fluent Assertions

AssertJ provides a fluent, readable assertion API that is strictly superior to JUnit's `assertEquals`/`assertTrue`. AssertJ assertions read as sentences, provide detailed failure messages by default, and offer type-specific assertions (collections, exceptions, dates, strings) that JUnit's built-in asserts cannot match.

```java
// DO: AssertJ -- readable, informative failures, type-specific
import static org.assertj.core.api.Assertions.*;

assertThat(users).hasSize(3)
    .extracting(User::email)
    .containsExactlyInAnyOrder("alice@example.com", "bob@example.com", "carol@example.com");

assertThat(account.balance()).isCloseTo(BigDecimal.valueOf(99.95), within(BigDecimal.valueOf(0.01)));

assertThatThrownBy(() -> service.withdraw(negativeAmount))
    .isInstanceOf(IllegalArgumentException.class)
    .hasMessageContaining("must be positive");

assertThat(response.headers()).containsEntry("Content-Type", "application/json");

// DON'T: JUnit assertions -- positional arguments, no context, limited API
assertEquals(3, users.size());           // which is expected, which is actual?
assertTrue(users.contains(alice));       // failure message: "expected true" -- useless
assertEquals("application/json", contentType); // positional confusion
```

### 7. Use Testcontainers for Integration Tests

Testcontainers spins up real Docker containers for databases, message brokers, and external services during tests. This eliminates the "works with H2 but fails with Postgres" problem. Use `@Testcontainers` and `@Container` annotations. Define containers as `static` fields for one-per-class lifecycle or instance fields for one-per-test. Use `@DynamicPropertySource` to wire container connection details into Spring's configuration.

```java
// DO: Real database in a container
@Testcontainers
@SpringBootTest
class UserRepositoryIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Test
    @DisplayName("persists and retrieves user with all fields intact")
    void persistsAndRetrievesUser() {
        var user = new User("alice", "alice@example.com");
        userRepository.save(user);

        var found = userRepository.findByEmail("alice@example.com");
        assertThat(found).isPresent()
            .get()
            .extracting(User::username, User::email)
            .containsExactly("alice", "alice@example.com");
    }
}

// DON'T: In-memory database that behaves differently from production
// H2 in PostgreSQL compatibility mode does NOT support window functions,
// CTEs with recursive, jsonb, or dozens of other Postgres features.
@DataJpaTest  // defaults to H2 -- your tests pass, your production code doesn't
class UserRepositoryTest { /* ... */ }
```

### 8. TDD Is the Default Workflow

Every implementation follows Red-Green-Refactor. Write a failing test first. Make it pass with the minimum implementation. Refactor while green. This is the protocol defined in [docs/engineering/testing.md](../../engineering/testing.md). In Java, TDD works naturally with interfaces: define the contract (interface), write the test against the contract, then implement the class. The test compiles before the implementation exists because it programs to the interface.

### 9. Use `@BeforeEach`, Not `@Before`

JUnit 5 renamed the lifecycle annotations. `@Before` is JUnit 4. `@BeforeEach` is JUnit 5. Same for `@After` vs `@AfterEach`, `@BeforeClass` vs `@BeforeAll`, `@AfterClass` vs `@AfterAll`. Mixing JUnit 4 and 5 annotations in the same test class causes silent test failures -- the JUnit 4 annotations are simply ignored by the Jupiter engine.

```java
// DO: JUnit 5 lifecycle annotations
@BeforeEach
void setUp() {
    orderService = new OrderService(mockInventory, mockPayment);
}

@AfterEach
void tearDown() {
    // cleanup if needed
}

// DON'T: JUnit 4 annotations -- silently ignored in JUnit 5
@Before  // This method will NEVER run under JUnit 5
public void setUp() { /* ... */ }
```

### 10. Never Leave Test Methods Empty

An empty test always passes and validates nothing. It's worse than no test because it creates a false sense of coverage. If a test exists, it must contain at least one assertion that can fail. If you're writing a test as a placeholder, write the assertion first (Red), even before the implementation exists -- that's TDD.

```java
// DON'T: Empty test body -- always passes, proves nothing
@Test
void testUserCreation() {
    // TODO: add assertions later
}

// DON'T: Test with no assertions
@Test
void testProcess() {
    service.process(input); // no assertion -- what are we verifying?
}

// DO: Assertion that defines the expected behavior
@Test
@DisplayName("creates user with hashed password")
void createsUserWithHashedPassword() {
    User user = userService.create("alice", "plaintext");
    assertThat(user.passwordHash()).isNotEqualTo("plaintext");
    assertThat(passwordEncoder.matches("plaintext", user.passwordHash())).isTrue();
}
```

### 11. Use `assertThrows` for Exception Testing

JUnit 5's `assertThrows` returns the thrown exception for further inspection. Do not wrap test code in `try/catch` -- it's verbose, and if the exception is never thrown, the test silently passes.

```java
// DO: assertThrows -- concise, returns the exception for inspection
@Test
@DisplayName("throws IllegalArgumentException when age is negative")
void throwsWhenAgeIsNegative() {
    var exception = assertThrows(IllegalArgumentException.class,
        () -> new Person("Alice", -1));
    assertThat(exception.getMessage()).contains("age must be non-negative");
}

// DO: AssertJ's exception assertions -- even more fluent
@Test
@DisplayName("throws when withdrawing more than balance")
void throwsWhenOverdrawing() {
    assertThatThrownBy(() -> account.withdraw(BigDecimal.valueOf(1000)))
        .isInstanceOf(InsufficientFundsException.class)
        .hasMessageContaining("balance")
        .hasFieldOrPropertyWithValue("requestedAmount", BigDecimal.valueOf(1000));
}

// DON'T: try/catch in test -- if exception isn't thrown, test passes silently
@Test
void testNegativeAge() {
    try {
        new Person("Alice", -1);
        fail("Expected exception"); // easy to forget this line
    } catch (IllegalArgumentException e) {
        assertEquals("age must be non-negative", e.getMessage());
    }
}
```

### 12. Use ArchUnit for Architecture Enforcement Tests

ArchUnit lets you write tests that enforce architectural rules: dependency direction, naming conventions, layer boundaries, annotation usage, and package structure. These rules catch architectural drift before code review.

```java
// DO: Enforce architecture with ArchUnit
@AnalyzeClasses(packages = "com.example.myapp")
class ArchitectureTest {

    @ArchTest
    static final ArchRule servicesShouldNotDependOnControllers =
        noClasses().that().resideInAPackage("..service..")
            .should().dependOnClassesThat().resideInAPackage("..controller..");

    @ArchTest
    static final ArchRule repositoriesShouldOnlyBeAccessedByServices =
        noClasses().that().resideOutsideOfPackage("..service..")
            .should().dependOnClassesThat().resideInAPackage("..repository..")
            .as("Only services should access repositories directly");

    @ArchTest
    static final ArchRule domainModelShouldNotDependOnSpring =
        noClasses().that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAPackage("org.springframework..");

    @ArchTest
    static final ArchRule controllersShouldBeAnnotated =
        classes().that().resideInAPackage("..controller..")
            .should().beAnnotatedWith(RestController.class)
            .orShould().beAnnotatedWith(Controller.class);

    @ArchTest
    static final ArchRule noFieldInjection =
        noFields().should().beAnnotatedWith(Autowired.class)
            .as("Use constructor injection, not field injection");
}
```

---

## Anti-Patterns

| Anti-Pattern | Why It's Harmful | What to Do Instead |
|---|---|---|
| JUnit 4 annotations (`@Before`, `@After`, `@Test` from `org.junit`) in new code | Silently ignored by JUnit 5 engine; test setup never runs | Use JUnit 5: `@BeforeEach`, `@AfterEach`, `org.junit.jupiter.api.Test` |
| Empty test methods or tests with no assertions | Always pass, create false confidence, validate nothing | Every test must assert expected behavior; start with the assertion (TDD) |
| `try/catch` for exception testing | If the exception isn't thrown, the test silently passes | Use `assertThrows` or AssertJ's `assertThatThrownBy` |
| `assertEquals(expected, actual)` with no message context | Failure output is "expected X but was Y" with no business context | Use AssertJ: `assertThat(actual).isEqualTo(expected)` with fluent chaining |
| Testing with H2 in "compatibility mode" for Postgres/MySQL | H2 doesn't support vendor-specific features; tests pass, production fails | Use Testcontainers with the real database engine |
| Copy-pasted tests that differ only in input | Duplication; adding a new case means copying again | Use `@ParameterizedTest` with `@CsvSource` or `@MethodSource` |
| Flat list of 50+ test methods with no grouping | Hard to find tests, hard to understand what's covered | Use `@Nested` classes to group by context or scenario |
| Mocking the system under test (SUT) | Tests the mock, not the code; proves nothing | Mock dependencies only; the SUT should be a real instance |
| Tests that depend on execution order | Fragile; fails when run in isolation or in parallel | Each test must set up its own state in `@BeforeEach` |
| Stubbing everything in a unit test | Test becomes a mirror of the implementation; breaks on any refactor | Stub only what the test needs; prefer state-based testing over interaction-based |
| `@SpringBootTest` for every test | Loads the full application context; tests take minutes | Use `@SpringBootTest` only for integration tests; use plain JUnit + Mockito for unit tests |
| No architecture enforcement | Dependency violations and layer breaches accumulate undetected | Add ArchUnit tests for package dependencies, naming, and annotation rules |

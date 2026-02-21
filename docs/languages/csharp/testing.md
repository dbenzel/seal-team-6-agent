# C# Testing

**Principle:** TDD is the default workflow. xUnit is the framework, FluentAssertions is the assertion language, NSubstitute isolates dependencies, and Testcontainers makes integration tests real. Every test must be capable of failing — if you remove the implementation and the test still passes, the test is broken. See `docs/engineering/testing.md` for the full TDD protocol.

---

## Rules

### 1. xUnit as the Primary Test Framework

xUnit is the standard for modern .NET. Not MSTest, not NUnit. xUnit's design — constructor injection for setup, `IDisposable` for teardown, isolated test class instances — aligns with how .NET developers already think.

```csharp
// DO: xUnit
using Xunit;

public class OrderServiceTests
{
    [Fact]
    public async Task PlaceOrder_WithValidItems_ReturnsConfirmation()
    {
        // Arrange, Act, Assert
    }
}

// DON'T: MSTest or NUnit in new projects
[TestClass] // MSTest
[TestFixture] // NUnit
```

### 2. `[Fact]` for Single Cases, `[Theory]` for Parameterized

Use `[Fact]` for tests with one scenario. Use `[Theory]` with `[InlineData]`, `[MemberData]`, or `[ClassData]` for data-driven tests.

```csharp
// DO: Theory with InlineData for simple parameterization
[Theory]
[InlineData("alice@example.com", true)]
[InlineData("invalid-email", false)]
[InlineData("", false)]
[InlineData("user@.com", false)]
public void IsValidEmail_ReturnsExpected(string email, bool expected)
{
    EmailValidator.IsValid(email).Should().Be(expected);
}

// DO: MemberData for complex test data
[Theory]
[MemberData(nameof(InvalidOrderCases))]
public void Validate_RejectsInvalidOrders(Order order, string expectedError)
{
    var result = _validator.Validate(order);
    result.Errors.Should().ContainSingle(e => e.Message.Contains(expectedError));
}

public static IEnumerable<object[]> InvalidOrderCases()
{
    yield return new object[] { OrderWithNoItems(), "at least one item" };
    yield return new object[] { OrderWithNegativeTotal(), "total must be positive" };
}
```

### 3. FluentAssertions for Readable Assertions

FluentAssertions provide fluent, expressive assertions with detailed failure messages. Strictly superior to xUnit's `Assert.*` for readability and diagnostics.

```csharp
// DO: FluentAssertions — reads as a specification
users.Should().HaveCount(3)
    .And.OnlyContain(u => u.IsActive)
    .And.ContainSingle(u => u.Email == "admin@example.com");

result.Should().BeOfType<NotFoundResult>()
    .Which.StatusCode.Should().Be(404);

action.Should().ThrowAsync<ValidationException>()
    .WithMessage("*email*");

// DON'T: xUnit Assert — positional, limited, weak failure messages
Assert.Equal(3, users.Count);
Assert.True(users.All(u => u.IsActive)); // "Expected: True, Actual: False" — useless
Assert.IsType<NotFoundResult>(result);
```

### 4. NSubstitute for Mocking

NSubstitute provides the cleanest mocking syntax in .NET. Preferred over Moq for readability.

```csharp
// DO: NSubstitute — reads naturally
var repository = Substitute.For<IOrderRepository>();
repository.GetByIdAsync(42).Returns(testOrder);

var service = new OrderService(repository, Substitute.For<ILogger<OrderService>>());
var result = await service.GetOrderAsync(42);

result.Should().BeEquivalentTo(testOrder);
await repository.Received(1).GetByIdAsync(42);

// DON'T: Verbose Moq setup
var mock = new Mock<IOrderRepository>();
mock.Setup(r => r.GetByIdAsync(42)).ReturnsAsync(testOrder);
mock.Verify(r => r.GetByIdAsync(42), Times.Once);
```

### 5. Shared Setup with Fixtures

Use `IClassFixture<T>` for expensive setup shared across tests in one class. Use `ICollectionFixture<T>` for setup shared across multiple test classes.

```csharp
// DO: Class fixture for expensive shared resource
public class DatabaseFixture : IAsyncLifetime
{
    public NpgsqlConnection Connection { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        Connection = new NpgsqlConnection(connectionString);
        await Connection.OpenAsync();
    }

    public async Task DisposeAsync() => await Connection.DisposeAsync();
}

public class UserRepositoryTests : IClassFixture<DatabaseFixture>
{
    private readonly DatabaseFixture _db;
    public UserRepositoryTests(DatabaseFixture db) => _db = db;

    [Fact]
    public async Task FindByEmail_ReturnsMatchingUser() { /* uses _db.Connection */ }
}
```

### 6. Testcontainers for Integration Tests

Use Testcontainers to spin up real databases and services in Docker. No more "works with SQLite, fails with Postgres."

```csharp
public class OrderRepositoryIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .Build();

    public async Task InitializeAsync() => await _postgres.StartAsync();
    public async Task DisposeAsync() => await _postgres.DisposeAsync();

    [Fact]
    public async Task Save_PersistsOrderWithAllFields()
    {
        await using var context = CreateDbContext(_postgres.GetConnectionString());
        var repository = new OrderRepository(context);

        var order = new Order { CustomerId = 1, Total = 99.95m };
        await repository.SaveAsync(order);

        var saved = await repository.GetByIdAsync(order.Id);
        saved.Should().BeEquivalentTo(order);
    }
}
```

### 7. WebApplicationFactory for ASP.NET Core Tests

Use `WebApplicationFactory<T>` for integration tests that exercise the full HTTP pipeline without deploying.

```csharp
public class UsersEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public UsersEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureTestServices(services =>
            {
                services.AddSingleton(Substitute.For<IEmailService>());
            });
        }).CreateClient();
    }

    [Fact]
    public async Task GetUsers_ReturnsOkWithUserList()
    {
        var response = await _client.GetAsync("/api/users");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var users = await response.Content.ReadFromJsonAsync<List<UserDto>>();
        users.Should().NotBeEmpty();
    }
}
```

### 8. Bogus for Test Data

Use Bogus to generate realistic test data instead of hardcoded magic strings.

```csharp
// DO: Bogus faker with overrides for what matters
private static readonly Faker<User> UserFaker = new Faker<User>()
    .RuleFor(u => u.Name, f => f.Person.FullName)
    .RuleFor(u => u.Email, f => f.Internet.Email())
    .RuleFor(u => u.CreatedAt, f => f.Date.Past());

[Fact]
public void Validate_RejectsUserWithEmptyEmail()
{
    var user = UserFaker.Clone().RuleFor(u => u.Email, string.Empty).Generate();
    var result = _validator.Validate(user);
    result.IsValid.Should().BeFalse();
}
```

### 9. Never Leave Test Methods Empty

An empty test always passes and tests nothing. Worse than no test — it creates false confidence.

```csharp
// DON'T: Empty test — always passes
[Fact]
public void TestOrderCreation()
{
    // TODO: implement later
}

// DON'T: No assertion
[Fact]
public void ProcessOrder()
{
    _service.Process(order); // What are we verifying?
}

// DO: Real assertion that can fail
[Fact]
public void Process_SetsStatusToConfirmed()
{
    var order = CreateTestOrder();
    _service.Process(order);
    order.Status.Should().Be(OrderStatus.Confirmed);
}
```

### 10. Architecture Tests

Use NetArchTest or ArchUnitNET to enforce architectural rules as tests.

```csharp
[Fact]
public void Domain_ShouldNotDependOn_Infrastructure()
{
    Types.InAssembly(typeof(Order).Assembly)
        .ShouldNot()
        .HaveDependencyOn("MyApp.Infrastructure")
        .GetResult()
        .IsSuccessful.Should().BeTrue();
}

[Fact]
public void Controllers_ShouldNotDirectlyAccessRepositories()
{
    Types.InAssembly(typeof(UsersController).Assembly)
        .That().ResideInNamespace("MyApp.Api.Controllers")
        .ShouldNot()
        .HaveDependencyOn("MyApp.Domain.Repositories")
        .GetResult()
        .IsSuccessful.Should().BeTrue();
}
```

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| MSTest or NUnit in new projects | xUnit with FluentAssertions |
| `Assert.Equal(expected, actual)` | `actual.Should().Be(expected)` — no positional confusion |
| Empty test methods or tests with no assertions | Every test must assert behavior that can fail |
| `Assert.True(condition)` with no context | FluentAssertions with expressive chain |
| Moq's verbose Setup/Verify syntax | NSubstitute's natural language API |
| SQLite/in-memory for integration tests | Testcontainers with the real database engine |
| Copy-pasted tests differing only in input | `[Theory]` with `[InlineData]` or `[MemberData]` |
| Manual `HttpClient` setup for API tests | `WebApplicationFactory<T>.CreateClient()` |
| Hardcoded "test@test.com" magic strings | Bogus/Faker for realistic generated data |
| `try/catch` for exception testing | `action.Should().ThrowAsync<T>()` |

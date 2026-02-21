# C# Idioms

**Principle:** Modern C# is expressive, type-safe, and allocation-conscious. Lean on the type system to prevent bugs at compile time, use records and pattern matching to express intent clearly, and let async/await flow end-to-end without blocking.

---

## Rules

### 1. Enable Nullable Reference Types

Set `<Nullable>enable</Nullable>` in your project file. Treat nullable warnings as errors. This is the single highest-impact setting for preventing `NullReferenceException` at compile time rather than runtime.

```xml
<PropertyGroup>
  <Nullable>enable</Nullable>
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
</PropertyGroup>
```

```csharp
// DO: Express nullability in the type system
public User? FindById(int id) => _users.GetValueOrDefault(id);

// DON'T: Return null without declaring it
public User FindById(int id) => _users.GetValueOrDefault(id); // Caller has no warning
```

### 2. Use Records for Immutable Data

Records provide value equality, immutability, `with` expressions, and deconstruction for free. Use `record` for reference types, `record struct` for small value types.

```csharp
// DO: Record for data carriers
public record UserCreated(int UserId, string Email, DateTime CreatedAt);
public record struct Point(double X, double Y);

// DON'T: Manual class with boilerplate equality
public class UserCreated
{
    public int UserId { get; }
    public string Email { get; }
    // ... constructor, Equals, GetHashCode, ToString
}
```

### 3. Exhaustive Pattern Matching

Use `switch` expressions with discard `_` to ensure all cases are handled. The compiler warns on non-exhaustive matches — treat those warnings as errors.

```csharp
// DO: Exhaustive switch expression
public decimal CalculateDiscount(CustomerTier tier) => tier switch
{
    CustomerTier.Bronze => 0.05m,
    CustomerTier.Silver => 0.10m,
    CustomerTier.Gold   => 0.20m,
    _ => throw new ArgumentOutOfRangeException(nameof(tier))
};

// DO: Pattern matching with type checks
public string Describe(Shape shape) => shape switch
{
    Circle { Radius: > 100 } => "large circle",
    Circle c => $"circle with radius {c.Radius}",
    Rectangle { Width: var w, Height: var h } when w == h => "square",
    Rectangle r => $"rectangle {r.Width}x{r.Height}",
    _ => "unknown shape"
};
```

### 4. Use `var` When Type Is Obvious

`var` reduces noise when the type is clear from the right-hand side. Don't use it when the type would be ambiguous to a reader.

```csharp
// DO: Type is obvious
var users = new List<User>();
var stream = File.OpenRead(path);
var config = JsonSerializer.Deserialize<AppConfig>(json);

// DON'T: Type is not obvious
var result = Process(input);   // What type is result?
var data = GetData();           // What type is data?
```

### 5. Async/Await End-to-End

Never block on async code with `.Result` or `.Wait()` — it causes deadlocks in UI and ASP.NET contexts. Async should flow from the entry point through to the I/O boundary.

```csharp
// DO: Async all the way
public async Task<User> GetUserAsync(int id)
{
    var response = await _httpClient.GetAsync($"/users/{id}");
    response.EnsureSuccessStatusCode();
    return await response.Content.ReadFromJsonAsync<User>();
}

// DON'T: Block on async — deadlock risk
public User GetUser(int id)
{
    var response = _httpClient.GetAsync($"/users/{id}").Result; // DEADLOCK
    return response.Content.ReadFromJsonAsync<User>().Result;
}
```

### 6. Use `IAsyncEnumerable<T>` for Streaming

When producing or consuming sequences of async values, use `IAsyncEnumerable<T>` instead of materializing entire collections.

```csharp
// DO: Stream results as they arrive
public async IAsyncEnumerable<LogEntry> StreamLogsAsync(
    [EnumeratorCancellation] CancellationToken ct = default)
{
    await foreach (var line in ReadLinesAsync(ct))
    {
        yield return ParseLogEntry(line);
    }
}
```

### 7. Span-Based APIs for Performance

Use `Span<T>` and `ReadOnlySpan<T>` to avoid heap allocations when slicing or processing memory.

```csharp
// DO: Zero-allocation substring parsing
public static bool TryParseVersion(ReadOnlySpan<char> input, out int major, out int minor)
{
    var dot = input.IndexOf('.');
    return int.TryParse(input[..dot], out major)
        && int.TryParse(input[(dot + 1)..], out minor);
}
```

### 8. Collection Expressions (C# 12+)

Use collection expressions for concise, readable initialization.

```csharp
// DO: Collection expressions
int[] numbers = [1, 2, 3, 4, 5];
List<string> names = ["Alice", "Bob"];
ReadOnlySpan<byte> header = [0x00, 0xFF, 0xAA];

// DON'T: Verbose initialization
int[] numbers = new int[] { 1, 2, 3, 4, 5 };
var names = new List<string> { "Alice", "Bob" };
```

### 9. Required and Init Properties

Use `required` for properties that must be set at initialization. Use `init` for immutable properties.

```csharp
// DO: Required + init for compile-time enforcement
public class CreateUserRequest
{
    public required string Email { get; init; }
    public required string Name { get; init; }
    public string? Phone { get; init; }
}

// Compiler error if Email or Name is missing:
var request = new CreateUserRequest { Email = "a@b.com", Name = "Alice" };
```

### 10. Using Declarations

Use `using` declarations (no braces) for cleaner resource cleanup. The resource is disposed at the end of the enclosing scope.

```csharp
// DO: Using declaration
using var stream = File.OpenRead(path);
using var reader = new StreamReader(stream);
var content = await reader.ReadToEndAsync();

// DON'T: Nested using blocks
using (var stream = File.OpenRead(path))
{
    using (var reader = new StreamReader(stream))
    {
        var content = await reader.ReadToEndAsync();
    }
}
```

### 11. Avoid `dynamic`

`dynamic` defeats the type system. Every `dynamic` call is a runtime binding — no IntelliSense, no refactoring support, no compile-time errors.

```csharp
// DON'T
dynamic config = GetConfig();
var port = config.Server.Port; // No compiler check — runtime failure if wrong

// DO: Use a typed model
var config = GetConfig<ServerConfig>();
var port = config.Server.Port; // Compile-time verified
```

### 12. Primary Constructors (C# 12)

Use primary constructors for simple dependency injection in classes and structs.

```csharp
// DO: Primary constructor
public class OrderService(IOrderRepository repository, ILogger<OrderService> logger)
{
    public async Task<Order> GetOrderAsync(int id)
    {
        logger.LogInformation("Fetching order {OrderId}", id);
        return await repository.GetByIdAsync(id);
    }
}

// DON'T: Boilerplate constructor + fields for DI
public class OrderService
{
    private readonly IOrderRepository _repository;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository repository, ILogger<OrderService> logger)
    {
        _repository = repository;
        _logger = logger;
    }
}
```

### 13. String Interpolation

Use interpolated strings (`$""`) over `String.Format` or concatenation. Use raw string literals (`"""`) for multi-line content.

```csharp
// DO
var message = $"User {user.Name} logged in from {user.IpAddress}";
var json = $$"""{"name": "{{user.Name}}", "age": {{user.Age}}}""";

// DON'T
var message = String.Format("User {0} logged in from {1}", user.Name, user.IpAddress);
var message = "User " + user.Name + " logged in from " + user.IpAddress;
```

### 14. Comments: Less Is More

Readable code and descriptive names should be self-documenting. Reserve comments for genuinely unintuitive logic, workarounds, or non-obvious business rules.

```csharp
// DON'T: Comment restates the code
// Increment the counter
counter++;

// DO: Comment explains WHY
// Offset by 1 because the vendor API uses 1-based page indexing
var apiPage = page + 1;
```

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Ignore nullable warnings | Enable `<Nullable>enable</Nullable>`, treat warnings as errors |
| Manual equality on data classes | Use `record` or `record struct` |
| `if/else if/else if` chains for type dispatch | Use `switch` expression with pattern matching |
| `.Result` or `.Wait()` on async code | `await` end-to-end |
| `dynamic` for flexible typing | Use generics, interfaces, or `JsonElement` |
| Nested `using` blocks | `using` declarations (no braces) |
| `new int[] { 1, 2, 3 }` | Collection expressions `[1, 2, 3]` |
| String concatenation in loops | `StringBuilder` or `string.Join` |
| Comments explaining what code does | Rename variables/methods to be self-documenting |
| Mutable DTOs with public setters | Records with `init` or `required init` properties |

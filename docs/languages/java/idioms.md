# Java Idioms: Patterns and Anti-Patterns

> **Principle:** Modern Java (17+) is an expressive, type-safe language with powerful modeling capabilities. Use records, sealed types, and pattern matching to make illegal states unrepresentable. Prefer immutability by default, fail fast on invalid input, and let the type system carry as much meaning as possible. Code that compiles should be code that works.

---

## Rules

1. **Use records for immutable data carriers (Java 16+).** A record is a transparent, immutable data class with `equals()`, `hashCode()`, and `toString()` generated correctly. If you're writing a class with `final` fields, a constructor that assigns them, and boilerplate getters, it's a record. Records also work as local classes inside methods, as keys in `Map` and `Set` (because `equals`/`hashCode` are correct by default), and as compact carriers for intermediate results. The compact constructor form lets you validate input without repeating the field assignments.

2. **Use sealed classes and interfaces for closed type hierarchies (Java 17+).** When a type has a fixed, known set of subtypes, seal it. Sealed types give the compiler exhaustiveness information for pattern matching, document the type hierarchy in the declaration itself, and prevent third-party code from adding unexpected subtypes. Use `sealed` with `permits` to define the closed set. Every permitted subclass must be `final`, `sealed`, or `non-sealed`.

3. **Use pattern matching with `instanceof` (Java 16+) and `switch` (Java 21+).** Pattern matching eliminates the cast-after-check boilerplate and makes control flow declarative. `instanceof` patterns bind the narrowed type to a variable in a single expression. Switch pattern matching (Java 21 finalized) enables exhaustive matching over sealed hierarchies, guarded patterns, and null handling in switch. Prefer pattern matching over visitor patterns and `instanceof` chains.

4. **Prefer `Optional` over null returns -- never use Optional as a field or parameter type.** `Optional` exists for one purpose: a return type that explicitly communicates "this might not have a value." It forces the caller to handle absence. But `Optional` as a field doubles memory overhead and breaks serialization. `Optional` as a parameter is worse -- it forces callers to wrap values for no benefit. Fields should be nullable or use a domain-specific default. Parameters should be overloaded or use a builder.

5. **Use streams judiciously -- simple loops are fine when streams reduce readability.** Streams excel at declarative transformations: filter-map-collect pipelines, grouping, partitioning, and flat-mapping. But a stream that spans 15 lines, uses multiple `peek()` calls for side effects, or requires a custom collector for a simple accumulation is worse than a `for` loop. If you need an index, need to break early, or need to mutate local variables, a loop is the right tool. Never use streams for side effects alone -- `forEach` at the end of a stream is a code smell when the stream does nothing else.

6. **Use `var` for local variables when the type is obvious from the right-hand side.** `var` reduces noise when the type is immediately apparent from the constructor, factory method, or literal on the right side. `var users = new ArrayList<User>()` is fine. `var result = processData(input)` is not -- the type is invisible to the reader. Never use `var` for numeric types where the difference between `int`, `long`, `float`, and `double` matters. Never use `var` for method return types or fields -- it's local variables only.

7. **Prefer composition over inheritance -- favor interfaces with default methods.** Java's single inheritance model makes deep class hierarchies brittle. One wrong design decision in a base class propagates to every subclass. Prefer small, focused interfaces. Use default methods on interfaces to provide shared behavior without forcing an inheritance chain. Use delegation (passing a dependency) over extending a class. The exception is extending framework classes where the framework requires it (e.g., `HttpServlet`, `AbstractController`) -- but even then, keep the hierarchy shallow.

8. **Use `List.of()`, `Map.of()`, `Set.of()` for immutable collections.** These factory methods (Java 9+) create compact, truly immutable collections. They reject `null` elements, throw on mutation attempts, and are more memory-efficient than wrapping mutable collections with `Collections.unmodifiableList()`. Use them for constants, default values, and any collection that has no reason to change. For building a collection from computation, use `Collectors.toUnmodifiableList()` (Java 10+) or `Stream.toList()` (Java 16+).

9. **Avoid raw types -- always parameterize generics.** Raw types (`List` instead of `List<String>`) bypass the entire generic type system. The compiler can't check element types, casts are deferred to runtime, and `ClassCastException` is the inevitable result. Even for empty collections, use `List.of()` (which infers the type parameter) or `Collections.<String>emptyList()`. Suppress warnings with `@SuppressWarnings("unchecked")` only when you can prove type safety and always add a comment explaining why.

10. **Use `try-with-resources` for all `AutoCloseable` resources.** Every `InputStream`, `OutputStream`, `Connection`, `PreparedStatement`, `ResultSet`, `Lock` (via wrapper), or custom `AutoCloseable` must be in a try-with-resources block. Manual `try/finally` is verbose and gets the exception-masking behavior wrong (the close exception suppresses the original). Try-with-resources handles suppressed exceptions correctly and guarantees cleanup even on `Error`. Multiple resources can be declared in one block.

11. **Prefer `StringBuilder` over string concatenation in loops.** The compiler optimizes single-line concatenation (`a + b + c`) into `StringBuilder` or `invokedynamic` (Java 9+ with `StringConcatFactory`). But concatenation inside a loop creates a new `StringBuilder` on every iteration. Use `StringBuilder` explicitly in loops, and `String.join()` or `StringJoiner` when building a delimited list. For template-style formatting, use `String.formatted()` (Java 15+) or `MessageFormat` for localized strings.

12. **Use `Objects.requireNonNull()` for fail-fast null checks at method entry.** Public methods that cannot accept null parameters should validate immediately. `Objects.requireNonNull(param, "param must not be null")` throws a `NullPointerException` with a clear message at the call site, not three method calls deep where the null finally dereferences. Place null checks at the top of the method body, before any state mutation. For constructors, this ensures the object is never created in an invalid state.

13. **Avoid checked exceptions for programming errors -- use unchecked exceptions.** Checked exceptions are for recoverable conditions the caller is expected to handle: file not found, network timeout, invalid user input. Programming errors -- null dereferences, illegal arguments, index out of bounds, illegal state -- should be unchecked (`RuntimeException` subclasses). A caller cannot meaningfully recover from a bug in your code. Throwing a checked exception for a programming error forces every caller to write a catch block that can't do anything useful.

14. **Use `final` for fields that don't change after construction.** Marking fields `final` communicates immutability intent, enables safe publication in concurrent contexts (the Java Memory Model guarantees visibility of `final` fields after construction), and prevents accidental reassignment. In practice, most fields should be `final`. If a field is not `final`, it should be because it genuinely needs to change -- not because you forgot. Records enforce this automatically; for regular classes, make it the default.

---

## Examples

### Records

```java
// DO: Record for an immutable data carrier with validation
public record Money(BigDecimal amount, Currency currency) {
    public Money {
        Objects.requireNonNull(amount, "amount must not be null");
        Objects.requireNonNull(currency, "currency must not be null");
        if (amount.scale() > currency.getDefaultFractionDigits()) {
            throw new IllegalArgumentException(
                "amount scale %d exceeds currency precision %d".formatted(
                    amount.scale(), currency.getDefaultFractionDigits()));
        }
    }

    public Money add(Money other) {
        if (!this.currency.equals(other.currency)) {
            throw new IllegalArgumentException("Cannot add different currencies");
        }
        return new Money(this.amount.add(other.amount), this.currency);
    }
}

// DON'T: Mutable POJO with boilerplate for what is clearly a value type
public class Money {
    private BigDecimal amount;
    private Currency currency;

    public Money(BigDecimal amount, Currency currency) {
        this.amount = amount;
        this.currency = currency;
    }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; } // mutable!
    public Currency getCurrency() { return currency; }
    public void setCurrency(Currency currency) { this.currency = currency; }

    @Override public boolean equals(Object o) { /* 15 lines of boilerplate */ }
    @Override public int hashCode() { /* more boilerplate */ }
    @Override public String toString() { /* even more */ }
}
```

### Sealed Types and Pattern Matching

```java
// DO: Sealed hierarchy with exhaustive pattern matching
public sealed interface Shape
    permits Circle, Rectangle, Triangle {
}

public record Circle(double radius) implements Shape {}
public record Rectangle(double width, double height) implements Shape {}
public record Triangle(double base, double height) implements Shape {}

// Java 21+ switch pattern matching -- compiler verifies exhaustiveness
public double area(Shape shape) {
    return switch (shape) {
        case Circle c    -> Math.PI * c.radius() * c.radius();
        case Rectangle r -> r.width() * r.height();
        case Triangle t  -> 0.5 * t.base() * t.height();
        // No default needed -- sealed + exhaustive
    };
}

// DON'T: instanceof chain with manual casting
public double area(Shape shape) {
    if (shape instanceof Circle) {
        Circle c = (Circle) shape;
        return Math.PI * c.radius() * c.radius();
    } else if (shape instanceof Rectangle) {
        Rectangle r = (Rectangle) shape;
        return r.width() * r.height();
    } else if (shape instanceof Triangle) {
        Triangle t = (Triangle) shape;
        return 0.5 * t.base() * t.height();
    }
    throw new IllegalArgumentException("Unknown shape: " + shape);
}
```

### Optional

```java
// DO: Optional as a return type to communicate possible absence
public Optional<User> findByEmail(String email) {
    return Optional.ofNullable(userMap.get(email));
}

// Caller is forced to handle the absent case
String displayName = userService.findByEmail(email)
    .map(User::displayName)
    .orElse("Unknown User");

// DON'T: Optional as a field -- doubles memory, breaks serialization
public class UserProfile {
    private Optional<String> nickname; // NO -- just use @Nullable String
}

// DON'T: Optional as a parameter -- forces callers to wrap
public void sendEmail(String to, Optional<String> cc) { // NO
    // Callers must write: sendEmail("a@b.com", Optional.empty())
}

// DO instead: overload or use @Nullable
public void sendEmail(String to) { sendEmail(to, null); }
public void sendEmail(String to, @Nullable String cc) { /* ... */ }
```

### Streams vs Loops

```java
// DO: Stream for a clear filter-map-collect pipeline
List<String> activeEmails = users.stream()
    .filter(User::isActive)
    .map(User::email)
    .sorted()
    .toList();

// DO: Loop when you need index, early exit, or mutation
int firstFailureIndex = -1;
for (int i = 0; i < results.size(); i++) {
    if (results.get(i).isFailed()) {
        firstFailureIndex = i;
        break;
    }
}

// DON'T: Stream abused for side effects
users.stream().forEach(user -> {
    user.setActive(false);        // mutation inside stream
    auditLog.record(user.id());   // side effect
    emailService.sendDeactivation(user); // another side effect
});
// Just use a for loop -- this isn't a transformation, it's a procedure
```

### var

```java
// DO: Type is obvious from the right-hand side
var users = new ArrayList<User>();
var connection = DriverManager.getConnection(url);
var mapper = new ObjectMapper();
var entry = Map.entry("key", "value");

// DON'T: Type is not obvious -- reader must chase down the return type
var result = service.process(input);   // What type is result?
var data = parseResponse(raw);         // What does this return?
var x = calculate(a, b, c);           // Meaningless variable name + hidden type
```

### Immutable Collections

```java
// DO: Immutable factory methods
List<String> colors = List.of("red", "green", "blue");
Map<String, Integer> ports = Map.of("http", 80, "https", 443);
Set<String> keywords = Set.of("final", "static", "void");

// DO: Collecting to unmodifiable from a stream (Java 16+)
List<String> names = users.stream()
    .map(User::name)
    .toList(); // returns unmodifiable list

// DON'T: Mutable collection disguised as immutable
List<String> colors = Collections.unmodifiableList(
    Arrays.asList("red", "green", "blue") // backed by a mutable array
);

// DON'T: new ArrayList<>(Arrays.asList(...)) when the list never changes
List<String> colors = new ArrayList<>(Arrays.asList("red", "green", "blue"));
```

### Try-With-Resources

```java
// DO: Multiple resources in one block
try (var connection = dataSource.getConnection();
     var statement = connection.prepareStatement(sql);
     var resultSet = statement.executeQuery()) {
    while (resultSet.next()) {
        results.add(mapRow(resultSet));
    }
}

// DON'T: Manual try/finally nesting hell
Connection connection = null;
PreparedStatement statement = null;
ResultSet resultSet = null;
try {
    connection = dataSource.getConnection();
    statement = connection.prepareStatement(sql);
    resultSet = statement.executeQuery();
    // ...
} finally {
    if (resultSet != null) try { resultSet.close(); } catch (SQLException e) { /* swallowed */ }
    if (statement != null) try { statement.close(); } catch (SQLException e) { /* swallowed */ }
    if (connection != null) try { connection.close(); } catch (SQLException e) { /* swallowed */ }
}
```

### Null Checks

```java
// DO: Fail-fast at method entry
public Order createOrder(Customer customer, List<LineItem> items) {
    Objects.requireNonNull(customer, "customer must not be null");
    Objects.requireNonNull(items, "items must not be null");
    if (items.isEmpty()) {
        throw new IllegalArgumentException("items must not be empty");
    }
    // Safe to proceed -- invariants are established
    return new Order(customer, List.copyOf(items));
}

// DON'T: Let null propagate until it explodes somewhere unrelated
public Order createOrder(Customer customer, List<LineItem> items) {
    var order = new Order();
    order.setCustomer(customer);         // null stored silently
    order.setItems(items);               // null stored silently
    order.calculateTotal();              // NullPointerException HERE -- miles from the cause
    return order;
}
```

### Checked vs Unchecked Exceptions

```java
// DO: Unchecked for programming errors (caller can't recover)
public void setAge(int age) {
    if (age < 0 || age > 150) {
        throw new IllegalArgumentException("Age must be between 0 and 150, got: " + age);
    }
    this.age = age;
}

// DO: Checked for recoverable external failures (caller should handle)
public User loadUser(Path file) throws IOException {
    // IOException is recoverable -- caller can retry, use a fallback, or report to user
    return objectMapper.readValue(file.toFile(), User.class);
}

// DON'T: Checked exception for a bug -- caller can't do anything useful
public User getUser(String id) throws UserNotFoundException {
    // If the ID was validated upstream, this is a programming error -- use unchecked
    // If this is user input that might not match, return Optional<User> instead
}
```

---

## Anti-Patterns

| Anti-Pattern | Why It's Harmful | What to Do Instead |
|---|---|---|
| Mutable POJOs with getters/setters for value types | Boilerplate explosion, broken `equals`/`hashCode`, mutation bugs | Use `record` for immutable value types (Java 16+) |
| Open class hierarchies where the set of subtypes is known | No exhaustiveness checking, anyone can add a subtype, fragile `instanceof` chains | Use `sealed` interfaces/classes with `permits` (Java 17+) |
| `instanceof` check followed by manual cast | Verbose, error-prone, duplicates the type name | Use `instanceof` pattern matching: `if (obj instanceof String s)` |
| Returning `null` from methods that might not find a value | Callers forget to check, `NullPointerException` at an unrelated location | Return `Optional<T>` for query methods |
| `Optional` as a field, parameter, or collection element type | Memory overhead, breaks serialization, forces callers to wrap values | Use `@Nullable` annotation for fields/params; `Optional` for return types only |
| Raw types (`List` instead of `List<String>`) | Bypasses generics, defers type errors to runtime `ClassCastException` | Always parameterize: `List<String>`, `Map<K, V>` |
| String concatenation in a loop (`result += item`) | Creates a new `String` and `StringBuilder` on every iteration -- O(n^2) | Use `StringBuilder` or `StringJoiner` explicitly |
| `try/catch/finally` for `AutoCloseable` resources | Verbose, gets exception suppression wrong, easy to leak resources | Use `try-with-resources` |
| Catching `Exception` or `Throwable` broadly | Masks programming errors (`NullPointerException`, `ClassCastException`) | Catch the specific exception type you can actually handle |
| Deep class inheritance (3+ levels) | Fragile base class problem, tight coupling, hard to test in isolation | Composition with interfaces, delegation, and dependency injection |
| `var` for non-obvious types | Reader must trace through method calls to determine the type | Use `var` only when the type is visible on the right-hand side |
| `Collections.unmodifiableList(mutableList)` | The wrapper is a view -- the backing list can still be mutated elsewhere | Use `List.of()`, `List.copyOf()`, or `Stream.toList()` |

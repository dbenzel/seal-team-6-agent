# Architecture

**Principle:** Good architecture makes the system easy to change. Design for the requirements you have, not the requirements you imagine.

---

## Rules

### 1. Separation of Concerns

Each module/component should have one reason to change:

- **Business logic** doesn't know about HTTP, databases, or file systems
- **Data access** doesn't know about presentation or business rules
- **Presentation** doesn't know about data storage
- **Configuration** is separate from code

When you need to change how data is stored, you shouldn't have to modify the UI. When you change a business rule, you shouldn't have to touch the database layer.

### 2. SOLID — Applied Pragmatically

| Principle | Practical Meaning |
|---|---|
| **Single Responsibility** | A module has one reason to change. If you're modifying a file for two unrelated reasons, it should be two files. |
| **Open/Closed** | Extend behavior through composition, not by modifying existing working code. |
| **Liskov Substitution** | Subtypes must honor the contract of their parent. If you override a method, don't surprise callers. |
| **Interface Segregation** | Don't force consumers to depend on methods they don't use. Smaller interfaces > fat interfaces. |
| **Dependency Inversion** | High-level modules depend on abstractions, not concrete implementations. Pass dependencies in, don't hardcode them. |

**Pragmatic caveat:** SOLID is a guide, not a law. Don't split a 30-line file into 5 files to satisfy Single Responsibility. Apply these when they reduce complexity, not when they add it.

### 3. Dependencies Flow Inward

```
  Presentation → Business Logic → Data Access
       ↓               ↓              ↓
     (calls)        (defines)      (implements)
```

- Outer layers depend on inner layers, never the reverse
- Inner layers define interfaces; outer layers implement them
- This makes the core business logic testable without infrastructure

### 4. When to Abstract

Create an abstraction **only** when:
- You have 3+ concrete cases (the Rule of Three)
- The abstraction makes the code simpler, not just shorter
- The abstraction has a clear, stable contract

**Don't abstract** when:
- You have only one implementation
- You're guessing at future requirements
- The abstraction adds indirection without reducing complexity

### 5. Package/Module Boundaries

- Group by feature/domain, not by technical layer (prefer `users/` over `controllers/`)
- Minimize cross-module dependencies — if everything imports everything, you have a ball of mud
- Keep public APIs small — expose the minimum needed, keep implementation details private
- A module's public API is its contract — changing it should be deliberate

### 6. Configuration and Environment

- Separate configuration from code — no hardcoded URLs, ports, or credentials
- Use environment variables or config files for deployment-specific values
- Provide sensible defaults where possible
- Fail fast on missing required configuration — don't silently use wrong values

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Create an interface for a single implementation | Just use the concrete type; extract later if needed |
| Put everything in one God class/module | Split by responsibility |
| Create `utils/` as a dumping ground | Name modules by their domain purpose |
| Pass 10 parameters through 5 layers | Use dependency injection or context objects |
| Design for hypothetical future requirements | Build for current needs; refactor when requirements actually change |

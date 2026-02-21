# TypeScript Idioms

**Principle:** TypeScript's value is its type system. Every pattern you adopt should make the compiler your first line of defense — not something you work around. If you find yourself casting, asserting, or suppressing errors, you're fighting the language instead of using it.

---

## Rules

### 1. Strict Mode, Always

Enable `strict: true` in `tsconfig.json`. This is the baseline, not the ceiling. Strict mode enables `strictNullChecks`, `noImplicitAny`, `strictFunctionTypes`, and more. Code written without strict mode is a different language — it looks like TypeScript but provides almost none of the safety guarantees.

```jsonc
// tsconfig.json — non-negotiable baseline
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

If you're migrating a codebase from JavaScript and can't enable strict globally yet, enable it per-file with `// @ts-strict` or use a `tsconfig.strict.json` that extends the base config and add files incrementally. Never leave strict off permanently.

### 2. Prefer `unknown` Over `any`

`any` disables type checking. It's a trapdoor that silently infects every value it touches. `unknown` is the type-safe counterpart — it forces you to narrow before use.

```typescript
// Do: Use unknown and narrow
function parseInput(raw: unknown): string {
  if (typeof raw === "string") {
    return raw; // TypeScript knows this is a string
  }
  throw new Error(`Expected string, got ${typeof raw}`);
}

// Don't: Use any — disables all checking downstream
function parseInput(raw: any): string {
  return raw.trim(); // No error at compile time, even if raw is a number
}
```

The only legitimate uses of `any` are: interop with untyped third-party libraries (and even then, declare a proper type), and very rare generic utility types where `any` is structurally required (e.g., some conditional type constraints). If you're reaching for `any`, you're likely skipping the work of defining the actual type.

### 3. Use Discriminated Unions Over Type Casting

Discriminated unions let the compiler verify exhaustiveness. Type casting (`as`) tells the compiler to trust you — and you're not trustworthy at 2 AM.

```typescript
// Do: Discriminated union — compiler enforces exhaustive handling
type Result =
  | { status: "success"; data: User }
  | { status: "error"; error: AppError }
  | { status: "loading" };

function handleResult(result: Result) {
  switch (result.status) {
    case "success":
      return renderUser(result.data); // TypeScript knows data exists
    case "error":
      return renderError(result.error); // TypeScript knows error exists
    case "loading":
      return renderSpinner();
  }
  // No default needed — TypeScript verifies all cases are handled
  // (with --strict and a satisfies never check, this is airtight)
}

// Don't: Type casting to force a shape
const response = await fetch("/api/user");
const user = (await response.json()) as User; // Lies to the compiler
```

When dealing with external data (API responses, JSON parsing, user input), use a runtime validation library like Zod, Valibot, or ArkType — not `as`.

### 4. Prefer `interface` for Object Shapes, `type` for Unions and Intersections

This is a convention, not a hard rule from the compiler — but it communicates intent clearly. `interface` declares a contract for an object shape. `type` is for everything else: unions, intersections, mapped types, conditional types.

```typescript
// Do: interface for object shapes
interface User {
  id: string;
  email: string;
  role: UserRole;
}

// Do: type for unions and computed types
type UserRole = "admin" | "editor" | "viewer";
type Nullable<T> = T | null;
type UserWithPosts = User & { posts: Post[] };

// Don't: type for plain object shapes (loses declaration merging, error readability)
type User = {
  id: string;
  email: string;
};

// Don't: interface for unions (doesn't work)
// interface Result = Success | Error; // Syntax error
```

### 5. Use `readonly` and `as const` for Immutability

Mutation is the source of an entire class of bugs. TypeScript gives you tools to prevent it — use them.

```typescript
// Do: readonly properties
interface Config {
  readonly apiUrl: string;
  readonly timeout: number;
}

// Do: readonly arrays
function processItems(items: readonly string[]) {
  // items.push("x"); // Compile error
  return items.map((item) => item.toUpperCase()); // Fine — creates new array
}

// Do: as const for literal types
const ROLES = ["admin", "editor", "viewer"] as const;
type Role = (typeof ROLES)[number]; // "admin" | "editor" | "viewer"

// Don't: mutable config that gets modified in unpredictable places
const config = { apiUrl: "https://api.example.com", timeout: 5000 };
config.timeout = -1; // Nobody catches this
```

### 6. Avoid Enums — Use Const Objects or Union Types

TypeScript enums have surprising runtime behavior: they generate JavaScript objects, numeric enums allow reverse mapping to arbitrary numbers, and they don't tree-shake well. Union types and const objects are simpler, more predictable, and more idiomatic.

```typescript
// Do: Union type for simple sets of values
type Direction = "north" | "south" | "east" | "west";

// Do: Const object when you need runtime access to the values
const HttpStatus = {
  OK: 200,
  NOT_FOUND: 404,
  INTERNAL_ERROR: 500,
} as const;

type HttpStatus = (typeof HttpStatus)[keyof typeof HttpStatus]; // 200 | 404 | 500

// Don't: Enum
enum Direction {
  North,  // 0 — but Direction[0] === "North", Direction[42] is also valid (!)
  South,  // 1
  East,   // 2
  West,   // 3
}
```

The one edge case where `const enum` is acceptable is in performance-critical paths where you need inlining — but even then, you lose cross-project compatibility with `--isolatedModules`.

### 7. Never Use `!` Non-Null Assertion — Narrow Properly

The `!` postfix operator tells TypeScript "trust me, this isn't null." It's a lie waiting to happen. Narrow with control flow instead.

```typescript
// Do: Narrow with control flow
function getLength(value: string | null): number {
  if (value === null) {
    throw new Error("Value must not be null");
  }
  return value.length; // TypeScript knows it's a string here
}

// Do: Narrow with optional chaining + nullish coalescing
const name = user?.profile?.displayName ?? "Anonymous";

// Don't: Non-null assertion
const name = user!.profile!.displayName!; // Three lies in one line
```

### 8. Prefer `Map`/`Set` Over Plain Objects for Dynamic Keys

Plain objects work well as records with known, static keys. When keys are dynamic (user IDs, cache keys, arbitrary strings), `Map` and `Set` are the right tools — they have proper semantics for iteration, size checking, and key types.

```typescript
// Do: Map for dynamic key-value stores
const userSessions = new Map<string, Session>();
userSessions.set(userId, session);
userSessions.has(userId); // true
userSessions.size; // actual count

// Do: Set for unique collections
const activeIds = new Set<string>();
activeIds.add(id);
activeIds.has(id); // O(1) lookup

// Don't: Plain object as a map
const userSessions: Record<string, Session> = {};
userSessions[userId] = session;
Object.keys(userSessions).length; // Wasteful — creates an array just to count
// Also: "toString" and "__proto__" are valid keys that can collide with builtins
```

### 9. Use Template Literal Types for String Patterns

Template literal types let you encode string structure in the type system. Use them to prevent invalid string construction at compile time.

```typescript
// Do: Template literal types for structured strings
type EventName = `${string}:${string}`;
type CssUnit = `${number}px` | `${number}rem` | `${number}em`;
type ApiRoute = `/api/${string}`;
type Locale = `${string}-${string}`; // "en-US", "ja-JP"

function on(event: EventName, handler: () => void) { /* ... */ }
on("user:login", handleLogin);  // OK
on("click", handleClick);        // Compile error — no colon

// Do: Template literal types for object key patterns
type DataAttributes = `data-${string}`;
type AriaAttributes = `aria-${string}`;

// Don't: Bare string types that accept anything
function on(event: string, handler: () => void) { /* ... */ }
on("literally anything", noop); // No compile-time feedback
```

### 10. Avoid Class Inheritance — Prefer Composition

Deep class hierarchies are brittle, hard to test, and create tight coupling. Prefer composition: small interfaces, plain objects, and functions that combine behaviors.

```typescript
// Do: Composition with interfaces and functions
interface Logger {
  log(message: string): void;
}

interface Retryable {
  retry<T>(fn: () => Promise<T>, attempts: number): Promise<T>;
}

function createApiClient(logger: Logger, retrier: Retryable) {
  return {
    async fetch(url: string) {
      logger.log(`Fetching ${url}`);
      return retrier.retry(() => globalThis.fetch(url), 3);
    },
  };
}

// Don't: Inheritance chains
class BaseService {
  // ...
}
class LoggingService extends BaseService {
  // ...
}
class RetryableLoggingService extends LoggingService {
  // Need retry without logging? Too bad.
  // Need to change the logging implementation? Modify the entire chain.
}
```

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| `any` as a type for function parameters or return values | Use `unknown` and narrow, or define the actual type |
| `as Type` to force a type on external data | Use Zod, Valibot, or ArkType to validate at runtime |
| `!` non-null assertion to silence null errors | Narrow with `if`, optional chaining, or nullish coalescing |
| `enum` for sets of related constants | Union types for simple values, `as const` objects for runtime access |
| Deep class inheritance hierarchies | Composition with interfaces, plain objects, and factory functions |
| `// @ts-ignore` to suppress errors | Fix the type error — if you can't, `// @ts-expect-error` with a comment explaining why |
| Plain objects as dynamic key-value stores | `Map<K, V>` for key-value, `Set<V>` for unique collections |
| `strict: false` in tsconfig | `strict: true` always — migrate incrementally if needed |
| `interface` for union types or computed types | `type` for unions, intersections, and mapped types |
| Mutable module-level constants | `readonly` properties, `as const`, and `Readonly<T>` |

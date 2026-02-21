# TypeScript Testing

**Principle:** TypeScript tests should be as strongly typed as the production code they exercise. Bypassing the type system in tests — via `as any`, loose mocks, or untyped fixtures — defeats the purpose of having types in the first place. If your tests don't catch type errors, they'll ship to production.

For the TDD protocol (red-green-refactor cycle, what to test, testing pyramid), see `docs/engineering/testing.md`. This document covers TypeScript-specific tooling, patterns, and pitfalls.

---

## Rules

### 1. Use Vitest or Jest as the Primary Test Runner

Vitest is the default choice for new projects — it's faster, has native ESM support, and integrates seamlessly with Vite-based projects. Jest is acceptable for existing codebases that already use it. Don't mix both in the same project.

```typescript
// Vitest — preferred for new projects
import { describe, it, expect } from "vitest";

describe("parseEmail", () => {
  it("returns the local part and domain for a valid email", () => {
    const result = parseEmail("user@example.com");
    expect(result).toEqual({ local: "user", domain: "example.com" });
  });

  it("throws when the email has no @ symbol", () => {
    expect(() => parseEmail("invalid")).toThrow("Invalid email format");
  });
});
```

### 2. Use `describe`/`it` Blocks with Behavioral Descriptions

Test names are specifications. They should read as sentences that describe the expected behavior, not the implementation. Start `describe` blocks with the unit under test. Start `it` blocks with what the unit does under specific conditions.

```typescript
// Do: Behavioral descriptions that read as specifications
describe("ShoppingCart", () => {
  describe("addItem", () => {
    it("increases the total by the item price", () => { /* ... */ });
    it("increments the quantity when the same item is added twice", () => { /* ... */ });
    it("throws when the item is out of stock", () => { /* ... */ });
  });

  describe("checkout", () => {
    it("applies the discount code before calculating tax", () => { /* ... */ });
    it("rejects expired discount codes", () => { /* ... */ });
  });
});

// Don't: Vague or implementation-focused names
describe("ShoppingCart", () => {
  it("works", () => { /* ... */ });
  it("test addItem", () => { /* ... */ });
  it("should call calculateTotal", () => { /* ... */ });
});
```

### 3. Type-Test with `expectTypeOf` (Vitest) or tsd

Production code isn't just behavior — it's also a type-level API. If your function's return type narrows based on input, or your generic constrains certain shapes, test it. Vitest ships `expectTypeOf` built-in. For Jest, use the `tsd` package.

```typescript
import { expectTypeOf } from "vitest";

// Test that return types are correct
it("returns a User when id is found", () => {
  const result = getUserById("123");
  expectTypeOf(result).toEqualTypeOf<User | null>();
});

// Test that generics propagate correctly
it("infers the correct type from the schema", () => {
  const schema = z.object({ name: z.string(), age: z.number() });
  type Inferred = z.infer<typeof schema>;
  expectTypeOf<Inferred>().toEqualTypeOf<{ name: string; age: number }>();
});

// Test that invalid inputs are rejected at the type level
it("rejects non-string keys", () => {
  // @ts-expect-error — number keys should not be allowed
  createLookup<number, string>();
});
```

### 4. Mock Modules, Not Implementations

Mock at the module boundary — replace entire imported modules, not individual functions inside the system under test. This keeps your tests decoupled from internal wiring. Use `vi.mock` (Vitest) or `jest.mock` (Jest) for module-level mocking.

```typescript
// Do: Mock the module boundary
import { describe, it, expect, vi } from "vitest";
import { sendEmail } from "../email-service";
import { registerUser } from "../registration";

vi.mock("../email-service", () => ({
  sendEmail: vi.fn().mockResolvedValue({ sent: true }),
}));

describe("registerUser", () => {
  it("sends a welcome email after creating the account", async () => {
    await registerUser({ email: "new@example.com", name: "Test" });

    expect(sendEmail).toHaveBeenCalledWith(
      expect.objectContaining({ to: "new@example.com", template: "welcome" }),
    );
  });
});

// Don't: Reach into the implementation to mock internals
// Don't mock private methods, internal state, or things the consumer can't see
```

When mocking gets painful, it's often a design smell — the code under test has too many dependencies or insufficient separation of concerns. Fix the design, don't paper over it with more mocks.

### 5. Use `faker` for Test Data, Not Hardcoded Strings

Hardcoded test data creates invisible assumptions. Using `@faker-js/faker` generates realistic, varied test data that exposes edge cases you wouldn't think to write manually.

```typescript
import { faker } from "@faker-js/faker";

// Do: Factory functions with faker
function buildUser(overrides: Partial<User> = {}): User {
  return {
    id: faker.string.uuid(),
    email: faker.internet.email(),
    name: faker.person.fullName(),
    createdAt: faker.date.past(),
    ...overrides,
  };
}

it("returns the user's display name", () => {
  const user = buildUser({ name: "Ada Lovelace" }); // Override only what matters to this test
  expect(getDisplayName(user)).toBe("Ada Lovelace");
});

// Don't: Hardcoded data that obscures what's relevant
it("returns the user's display name", () => {
  const user = {
    id: "123",           // Is this id important? Who knows.
    email: "test@test",  // Is this a valid email? Does it matter?
    name: "Test User",   // This is the only relevant field.
    createdAt: new Date("2024-01-01"),
  };
  expect(getDisplayName(user)).toBe("Test User");
});
```

Use factory functions (`buildUser`, `buildOrder`, etc.) that accept partial overrides. Each test overrides only the fields relevant to what it's testing — everything else is random and realistic.

### 6. Use `supertest` or Similar for HTTP Endpoint Testing

Don't test API routes by mocking `req`/`res` objects manually. Use `supertest` (Express/Koa), or your framework's built-in test client (Hono's `app.request()`, Fastify's `inject()`), to make real HTTP calls against your app without starting a network server.

```typescript
import { describe, it, expect } from "vitest";
import supertest from "supertest";
import { app } from "../app";

describe("GET /api/users/:id", () => {
  it("returns 200 with the user data for a valid id", async () => {
    const response = await supertest(app)
      .get("/api/users/123")
      .expect(200);

    expect(response.body).toMatchObject({
      id: "123",
      email: expect.stringContaining("@"),
    });
  });

  it("returns 404 when the user does not exist", async () => {
    await supertest(app)
      .get("/api/users/nonexistent")
      .expect(404);
  });

  it("returns 400 when the id format is invalid", async () => {
    const response = await supertest(app)
      .get("/api/users/;;;drop-table")
      .expect(400);

    expect(response.body.error).toBeDefined();
  });
});
```

### 7. TDD Is the Default Workflow

Every implementation starts with a failing test. See `docs/engineering/testing.md` for the full red-green-refactor protocol. In TypeScript specifically, this means:

1. Write the test with proper types — import the function that doesn't exist yet
2. See the compile error (this is your "red" — the function/type doesn't exist)
3. Create the type signature and minimal implementation to compile and fail the runtime assertion
4. Run the test — confirm it fails for the right reason (the assertion, not a compile error)
5. Implement until green
6. Refactor

```typescript
// Step 1: Write the test (the import will be red)
import { calculateDiscount } from "../pricing";

it("applies a 10% discount for orders over $100", () => {
  const result = calculateDiscount({ subtotal: 150, code: "SAVE10" });
  expect(result).toBe(15);
});

// Step 2-3: Create the function with correct types, minimal implementation
export function calculateDiscount(order: { subtotal: number; code: string }): number {
  return 0; // Will fail the test — good
}

// Step 4: Run test, confirm it fails (expected 15, got 0)
// Step 5: Implement
// Step 6: Refactor
```

### 8. Never Use `as any` in Tests to Bypass Type Errors

`as any` in tests is a red flag. It means either: (a) the production types are wrong and need fixing, (b) the test is wrong and is testing something impossible, or (c) the mock setup is insufficient. Fix the root cause.

```typescript
// Do: Properly typed test setup
import type { User } from "../types";

const mockUser: User = {
  id: "123",
  email: "test@example.com",
  name: "Test User",
  role: "viewer",
  createdAt: new Date(),
};

// Do: Use Partial<T> or Pick<T> when you legitimately need a subset
function buildPartialUser(overrides: Partial<User>): User {
  return { ...defaultUser, ...overrides };
}

// Don't: as any to dodge type errors
const mockUser = {
  id: "123",
  name: "Test User",
  // Missing required fields? as any hides the problem.
} as any as User;

// Don't: as any to make mocks compile
vi.mocked(getUser).mockReturnValue({ id: "123" } as any);
// If the mock's return value doesn't match the real return type,
// your test is lying about what the code actually does.
```

If a mock is hard to type correctly, consider whether the interface is too complex (design smell) or whether you need a more complete mock factory.

---

## Test Organization

### File Placement

Colocate test files next to the code they test. Use the `.test.ts` or `.spec.ts` suffix.

```
src/
  pricing/
    calculate-discount.ts
    calculate-discount.test.ts    # Right next to the implementation
    apply-coupon.ts
    apply-coupon.test.ts
  users/
    get-user.ts
    get-user.test.ts
```

For integration and E2E tests that span multiple modules, use a top-level `tests/` directory:

```
tests/
  integration/
    checkout-flow.test.ts
  e2e/
    user-registration.test.ts
```

### Setup and Teardown

Use `beforeEach` for per-test setup, `afterEach` for cleanup. Avoid `beforeAll`/`afterAll` unless the setup is genuinely expensive (database connections, server startup) — shared state between tests is a flakiness factory.

```typescript
describe("UserRepository", () => {
  let db: TestDatabase;

  beforeEach(async () => {
    db = await createTestDatabase();
  });

  afterEach(async () => {
    await db.cleanup();
  });

  it("inserts a user and returns the generated id", async () => {
    const id = await db.users.insert(buildUser());
    expect(id).toBeDefined();
  });
});
```

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| `as any` to make tests compile | Fix the types — use proper mocks, factories, or `Partial<T>` |
| Hardcoded UUIDs, emails, and dates in every test | Use `@faker-js/faker` with factory functions |
| Mock internal implementation details | Mock at module boundaries with `vi.mock` / `jest.mock` |
| Vague test names: `"it works"`, `"test 1"` | Behavioral descriptions: `"returns 404 when the user does not exist"` |
| `// @ts-ignore` or `// @ts-expect-error` to silence test type errors | Fix the type error — it's telling you something is wrong |
| Manual `req`/`res` object construction for API tests | Use `supertest` or your framework's test client |
| `beforeAll` with shared mutable state across tests | `beforeEach` with fresh state per test |
| Skipping tests with `xit` / `it.skip` instead of fixing them | Fix or delete — skipped tests are dead weight |
| Testing implementation: `"calls the database method"` | Testing behavior: `"returns the user when the id exists"` |
| Snapshot tests for logic or data | Snapshots are for rendered output only; use explicit assertions for data |

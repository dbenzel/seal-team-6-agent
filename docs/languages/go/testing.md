# Go Testing

**Principle:** Go's standard `testing` package is not a limitation — it is a feature. It gives you everything you need without magic, annotation processing, or framework lock-in. Write tests that are simple, fast, and readable. Table-driven tests are the default. TDD is the workflow (see `docs/engineering/testing.md` for the protocol).

---

## Rules

### 1. Use the Standard `testing` Package

Go's `testing` package is the foundation. You do not need a test framework. The standard library gives you `t.Run`, `t.Helper`, `t.Parallel`, `t.Cleanup`, subtests, benchmarks, and fuzzing — all with zero dependencies.

```go
// Do: Standard testing package
func TestAdd(t *testing.T) {
    got := Add(2, 3)
    if got != 5 {
        t.Errorf("Add(2, 3) = %d, want 5", got)
    }
}

// Don't: Pull in a framework just to avoid writing if statements
// "BDD-style" frameworks that add layers of Describe/Context/It
// are solving a problem Go doesn't have.
```

### 2. Table-Driven Tests as the Default Pattern

Every test with more than one case should be table-driven. This is the canonical Go testing pattern. It makes adding cases trivial, keeps assertions consistent, and produces clear failure output.

```go
func TestFormatBytes(t *testing.T) {
    tests := []struct {
        name  string
        bytes int64
        want  string
    }{
        {name: "zero", bytes: 0, want: "0 B"},
        {name: "bytes", bytes: 512, want: "512 B"},
        {name: "kilobytes", bytes: 1536, want: "1.5 KB"},
        {name: "megabytes", bytes: 1048576, want: "1.0 MB"},
        {name: "gigabytes", bytes: 1073741824, want: "1.0 GB"},
        {name: "negative", bytes: -1, want: "0 B"},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := FormatBytes(tt.bytes)
            if got != tt.want {
                t.Errorf("FormatBytes(%d) = %q, want %q", tt.bytes, got, tt.want)
            }
        })
    }
}
```

Name each test case. The `name` field is not optional — it shows up in failure output and `go test -run` filters. A test failure that says `TestFormatBytes/negative` is immediately useful; `TestFormatBytes/#4` is not.

### 3. `testify` for Cleaner Assertions (Optional but Recommended)

The standard library's `t.Errorf` is verbose for complex comparisons. `testify/assert` and `testify/require` reduce boilerplate for equality checks, nil checks, and error assertions.

```go
import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestUserService_Create(t *testing.T) {
    svc := NewUserService(mockRepo)

    user, err := svc.Create(ctx, validInput)

    // require stops the test immediately on failure — use for preconditions
    require.NoError(t, err)
    require.NotNil(t, user)

    // assert continues execution — use for verifying multiple properties
    assert.Equal(t, "alice@example.com", user.Email)
    assert.False(t, user.CreatedAt.IsZero())
}
```

Use `require` for conditions that must hold for the rest of the test to make sense (non-nil, no error). Use `assert` for everything else. Mixing them up leads to nil pointer panics in tests — a failing test should never crash.

### 4. Use `httptest` for HTTP Handler Testing

Never start a real server to test HTTP handlers. The `net/http/httptest` package gives you an in-process test server and a response recorder for direct handler testing.

```go
// Do: Test handlers directly with httptest.NewRecorder
func TestHealthHandler(t *testing.T) {
    req := httptest.NewRequest("GET", "/health", nil)
    w := httptest.NewRecorder()

    HealthHandler(w, req)

    resp := w.Result()
    assert.Equal(t, http.StatusOK, resp.StatusCode)

    body, _ := io.ReadAll(resp.Body)
    assert.JSONEq(t, `{"status":"ok"}`, string(body))
}

// Do: Use httptest.NewServer for integration-style tests against a full mux
func TestAPIIntegration(t *testing.T) {
    srv := httptest.NewServer(setupRouter())
    defer srv.Close()

    resp, err := http.Get(srv.URL + "/api/users")
    require.NoError(t, err)
    defer resp.Body.Close()

    assert.Equal(t, http.StatusOK, resp.StatusCode)
}

// Don't: Bind to a real port
func TestHealthHandler(t *testing.T) {
    go http.ListenAndServe(":8080", handler)  // port conflict, slow, unreliable
    resp, _ := http.Get("http://localhost:8080/health")
    // ...
}
```

### 5. Use `t.Helper()` in Test Helper Functions

When you extract shared test setup or assertion logic into helper functions, call `t.Helper()` at the top. This makes failure output report the caller's line number, not the helper's — which is where the actual problem is.

```go
// Do: Mark helpers so failures point to the right line
func assertJSONResponse(t *testing.T, w *httptest.ResponseRecorder, status int, expected string) {
    t.Helper()  // failures will report the caller's file:line, not this one
    assert.Equal(t, status, w.Code)
    assert.JSONEq(t, expected, w.Body.String())
}

func TestGetUser(t *testing.T) {
    w := httptest.NewRecorder()
    handler.ServeHTTP(w, req)
    assertJSONResponse(t, w, 200, `{"name":"Alice"}`)  // failure points here
}

// Don't: Forget t.Helper()
func assertJSONResponse(t *testing.T, w *httptest.ResponseRecorder, status int, expected string) {
    // no t.Helper() — failures point to this function, not the caller
    assert.Equal(t, status, w.Code)
}
```

### 6. Use `t.Parallel()` for Independent Tests

Tests that don't share state should run in parallel. This surfaces data races and makes the test suite faster.

```go
func TestUserValidation(t *testing.T) {
    tests := []struct {
        name    string
        input   User
        wantErr bool
    }{
        {name: "valid user", input: User{Name: "Alice", Email: "a@b.com"}, wantErr: false},
        {name: "missing name", input: User{Email: "a@b.com"}, wantErr: true},
        {name: "missing email", input: User{Name: "Alice"}, wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()  // each subtest runs concurrently
            err := tt.input.Validate()
            if (err != nil) != tt.wantErr {
                t.Errorf("Validate() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

Do not use `t.Parallel()` on tests that share mutable state — fix the shared state first (pass it through, or use `t.Cleanup` to reset it).

### 7. Use `testcontainers-go` for Integration Tests with Real Dependencies

Mocking databases, message queues, and caches hides bugs. For integration tests, spin up real containers with `testcontainers-go`. These tests are slower, so guard them behind build tags or short-mode checks.

```go
//go:build integration

func TestUserRepository_Postgres(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }

    ctx := context.Background()
    container, err := postgres.Run(ctx,
        "postgres:16-alpine",
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("database system is ready to accept connections").
                WithOccurrence(2).
                WithStartupTimeout(5*time.Second),
        ),
    )
    require.NoError(t, err)
    t.Cleanup(func() { container.Terminate(ctx) })

    connStr, err := container.ConnectionString(ctx, "sslmode=disable")
    require.NoError(t, err)

    db, err := sql.Open("postgres", connStr)
    require.NoError(t, err)
    t.Cleanup(func() { db.Close() })

    repo := NewUserRepository(db)
    // test against real Postgres...
}
```

### 8. TDD in Go

For the full red-green-refactor protocol, see `docs/engineering/testing.md`. In Go, TDD typically means adding a table-driven test case first, running `go test ./...` to see it fail, then implementing.

### 9. Use `t.Run` for Subtests

`t.Run` gives you named subtests that can be filtered, run in parallel, and produce structured output. Use it for every case in a table-driven test and for grouping related assertions in larger tests.

```go
func TestOrderService(t *testing.T) {
    svc := setupOrderService(t)

    t.Run("placing an order", func(t *testing.T) {
        t.Run("succeeds with valid items", func(t *testing.T) {
            order, err := svc.Place(ctx, validOrder)
            require.NoError(t, err)
            assert.NotEmpty(t, order.ID)
        })

        t.Run("fails when inventory is insufficient", func(t *testing.T) {
            _, err := svc.Place(ctx, outOfStockOrder)
            assert.ErrorIs(t, err, ErrInsufficientInventory)
        })
    })
}
```

Run a specific subtest: `go test -run TestOrderService/placing_an_order/fails_when_inventory_is_insufficient`.

### 10. Benchmarks with `testing.B` for Performance-Critical Code

When performance matters, prove it with a benchmark. Do not guess. Run benchmarks before and after changes to measure impact.

```go
func BenchmarkSortUsers(b *testing.B) {
    users := generateUsers(10000)

    b.ResetTimer()  // exclude setup time
    for i := 0; i < b.N; i++ {
        // copy to avoid sorting an already-sorted slice
        input := make([]User, len(users))
        copy(input, users)
        SortByLastName(input)
    }
}

// Run with: go test -bench=BenchmarkSortUsers -benchmem ./...
// Compare runs with: benchstat old.txt new.txt
```

Use `b.ResetTimer()` to exclude setup. Use `-benchmem` to see allocations. Use `benchstat` to compare before/after results with statistical rigor.

### 11. Use `go test -race` to Catch Data Races

The race detector is not optional for concurrent code. Run it in CI and during development.

```bash
# Run tests with race detection
go test -race ./...

# Run a specific test with race detection
go test -race -run TestConcurrentAccess ./pkg/cache/
```

The race detector has zero false positives. If it fires, you have a bug. Fix it immediately — data races are undefined behavior in Go. Do not "fix" race detector output by adding `//nolint` or restructuring tests to be sequential. Fix the code.

---

## Test Organization

### File Placement

```
pkg/
  user/
    service.go          # implementation
    service_test.go     # unit tests (same package — can test unexported)
    service_integration_test.go  # integration tests (build-tagged)
```

- Unit tests: same package, same directory, `_test.go` suffix
- Integration tests: same directory, build-tagged with `//go:build integration`
- Test helpers: `testutil/` package or `_test.go` files with shared helpers

### Test Fixtures

Use `testdata/` directories for golden files, fixture data, and test inputs. Go's tooling ignores `testdata/` directories during builds.

```go
func TestParseConfig(t *testing.T) {
    data, err := os.ReadFile("testdata/valid_config.yaml")
    require.NoError(t, err)

    cfg, err := ParseConfig(data)
    require.NoError(t, err)
    assert.Equal(t, "production", cfg.Environment)
}
```

### `t.Cleanup` Over `defer`

Prefer `t.Cleanup` for test teardown. It runs after the test and all its subtests complete, even if the test calls `t.Parallel()`. `defer` only runs when the enclosing function returns — which is not the same thing in parallel subtests.

```go
func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()
    db, err := sql.Open("postgres", testDSN)
    require.NoError(t, err)
    t.Cleanup(func() { db.Close() })
    return db
}
```

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Pull in a BDD framework (Ginkgo, GoConvey) for simple tests | Standard `testing` + table-driven tests cover most cases |
| Write test helper functions without `t.Helper()` | Always call `t.Helper()` first — failure output should point to the caller |
| Skip the race detector in CI | Run `go test -race ./...` in every CI pipeline |
| Mock the database for repository tests | Use `testcontainers-go` for integration tests against a real database |
| Share mutable state between parallel tests | Each test gets its own state; use `t.Cleanup` to tear down |
| Test private functions by exporting them | Test behavior through the public API; if that is insufficient, use `_test.go` in the same package |
| Write benchmarks without `b.ResetTimer()` | Exclude setup time so results reflect only the code under test |
| Put test helpers in a `utils_test.go` grab bag | Name test helper files by what they help with, or use a `testutil` package |
| Use `time.Sleep` to wait for async operations in tests | Use channels, `sync.WaitGroup`, or polling with a deadline |
| Run integration tests without build tags | Guard them with `//go:build integration` so `go test ./...` stays fast |

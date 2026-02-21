# Go Idioms & Patterns

**Principle:** Go rewards simplicity and explicitness. The language was designed to make the right thing easy and the wrong thing obvious. Write code that reads like prose to a Go programmer — no magic, no cleverness, no framework gymnastics. If your Go code needs a comment explaining *what* it does, rewrite it until it doesn't.

---

## Rules

### 1. Accept Interfaces, Return Structs

Functions should accept the narrowest interface that satisfies their needs and return concrete types. This gives callers maximum flexibility while preserving your ability to evolve the implementation.

```go
// Do: Accept an interface, return the concrete type
func NewUserService(repo UserRepository) *UserService {
    return &UserService{repo: repo}
}

// Don't: Accept a concrete type, return an interface
func NewUserService(repo *PostgresUserRepo) UserRepository {
    return &UserService{repo: repo}
}
```

Returning interfaces hides what the caller actually gets, makes it impossible to access type-specific methods without assertion, and creates a false abstraction boundary. The caller already knows what they're constructing — let them have the real type.

### 2. Errors Are Values — Handle Them, Never Ignore Them

Every error return must be checked. The `_` discard on an error is a bug, not a style choice.

```go
// Do: Handle every error
data, err := os.ReadFile(path)
if err != nil {
    return fmt.Errorf("reading config from %s: %w", path, err)
}

// Don't: Discard errors
data, _ := os.ReadFile(path)  // silent corruption waiting to happen
```

If you genuinely believe an error cannot occur, assert that belief explicitly:

```go
// Acceptable: Panic on "impossible" errors (e.g., marshaling a known-good type)
data, err := json.Marshal(knownValidStruct)
if err != nil {
    panic(fmt.Sprintf("bug: failed to marshal known type: %v", err))
}
```

### 3. Use `errors.Is` and `errors.As` for Error Inspection

Never match errors by comparing strings. Error messages are not an API surface — they change without notice.

```go
// Do: Use errors.Is for sentinel errors
if errors.Is(err, os.ErrNotExist) {
    return createDefault()
}

// Do: Use errors.As for error types
var pathErr *os.PathError
if errors.As(err, &pathErr) {
    log.Printf("operation %s failed on path %s", pathErr.Op, pathErr.Path)
}

// Don't: String matching
if strings.Contains(err.Error(), "not found") {  // fragile, untestable
    return createDefault()
}
```

### 4. Wrap Errors with Context Using `%w`

Every error that crosses a function boundary should gain context. Use `fmt.Errorf` with the `%w` verb to preserve the error chain.

```go
// Do: Add context and preserve the chain
func (s *OrderService) Place(ctx context.Context, order Order) error {
    if err := s.inventory.Reserve(ctx, order.Items); err != nil {
        return fmt.Errorf("placing order %s: reserving inventory: %w", order.ID, err)
    }
    return nil
}

// Don't: Return raw errors with no context
func (s *OrderService) Place(ctx context.Context, order Order) error {
    if err := s.inventory.Reserve(ctx, order.Items); err != nil {
        return err  // caller has no idea what operation failed
    }
    return nil
}

// Don't: Use %v — it breaks errors.Is/errors.As
return fmt.Errorf("reserving inventory: %v", err)  // unwrap chain is severed
```

### 5. Small Interfaces — The Bigger the Interface, the Weaker the Abstraction

Interfaces in Go should be small: one or two methods. The standard library models this perfectly — `io.Reader`, `io.Writer`, `fmt.Stringer`, `error`. If your interface has five methods, you've probably designed it wrong.

```go
// Do: Small, focused interfaces
type Validator interface {
    Validate() error
}

type Repository interface {
    FindByID(ctx context.Context, id string) (*Entity, error)
}

// Don't: Kitchen sink interfaces
type UserManager interface {
    Create(user User) error
    Update(user User) error
    Delete(id string) error
    FindByID(id string) (*User, error)
    FindByEmail(email string) (*User, error)
    List(filter Filter) ([]*User, error)
    Count() (int, error)
    Validate(user User) error
    SendWelcomeEmail(user User) error
}
```

Define interfaces at the point of consumption, not at the point of implementation. The consumer knows what it needs — let it declare that.

### 6. Table-Driven Tests

Table-driven tests are Go's canonical testing pattern. They make it trivial to add cases, eliminate test logic duplication, and produce clear failure messages.

```go
// Do: Table-driven
func TestParseSize(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int64
        wantErr bool
    }{
        {name: "bytes", input: "100B", want: 100},
        {name: "kilobytes", input: "2KB", want: 2048},
        {name: "empty string", input: "", wantErr: true},
        {name: "negative", input: "-5B", wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseSize(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("ParseSize(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
                return
            }
            if got != tt.want {
                t.Errorf("ParseSize(%q) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}

// Don't: Copy-paste test functions
func TestParseSizeBytes(t *testing.T) { /* ... */ }
func TestParseSizeKilobytes(t *testing.T) { /* ... */ }
func TestParseSizeEmpty(t *testing.T) { /* ... */ }
```

### 7. Goroutines: Always Know How They Exit

Never fire-and-forget a goroutine. Every goroutine must have a clear, observable exit path. If you can't answer "how does this goroutine stop?", you have a goroutine leak.

```go
// Do: Controlled lifecycle with cancellation
func (s *Server) processQueue(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case msg := <-s.queue:
            if err := s.handle(msg); err != nil {
                s.logger.Error("handling message", "err", err)
            }
        }
    }
}

// Do: Use errgroup for coordinated goroutines
g, ctx := errgroup.WithContext(ctx)
for _, url := range urls {
    g.Go(func() error {
        return fetch(ctx, url)
    })
}
if err := g.Wait(); err != nil {
    return fmt.Errorf("fetching urls: %w", err)
}

// Don't: Fire and forget
go processItem(item)  // who waits for this? what if it panics?
```

### 8. Use `context.Context` for Cancellation and Timeouts

Every function that performs I/O, calls an external service, or could block should accept a `context.Context` as its first parameter. This is not optional — it's how Go programs compose timeout and cancellation behavior.

```go
// Do: Context as first parameter, plumbed through the call chain
func (c *Client) FetchUser(ctx context.Context, id string) (*User, error) {
    req, err := http.NewRequestWithContext(ctx, "GET", c.baseURL+"/users/"+id, nil)
    if err != nil {
        return nil, fmt.Errorf("building request: %w", err)
    }
    // ...
}

// Don't: Ignore context or use context.Background() to "make it compile"
func (c *Client) FetchUser(id string) (*User, error) {
    req, _ := http.NewRequest("GET", c.baseURL+"/users/"+id, nil)  // no cancellation, no timeout
    // ...
}
```

Never store `context.Context` in a struct. It is a request-scoped value that flows through the call chain.

### 9. Prefer Composition Over Embedding

Embedding promotes the embedded type's methods to the outer type. This looks like inheritance and creates the same coupling problems. Prefer explicit composition where you delegate intentionally.

```go
// Do: Explicit composition — you control the surface area
type UserService struct {
    repo   UserRepository
    cache  Cache
    logger *slog.Logger
}

func (s *UserService) FindByID(ctx context.Context, id string) (*User, error) {
    // explicitly calls repo — clear delegation
    return s.repo.FindByID(ctx, id)
}

// Don't: Embed and accidentally expose internal methods
type UserService struct {
    *PostgresRepo  // all of PostgresRepo's methods are now on UserService
    *RedisCache    // all of RedisCache's methods too — method set collision risk
}
```

Embedding is appropriate for composing interfaces and for types that intentionally *are* the embedded type (e.g., `sync.Mutex` in a struct that genuinely acts as a synchronized container).

### 10. Use Sync Primitives Appropriately

The `sync` package provides purpose-built tools. Use the right one for the job.

```go
// sync.Once — exactly-once initialization
var (
    dbOnce sync.Once
    dbConn *sql.DB
)
func getDB() *sql.DB {
    dbOnce.Do(func() {
        dbConn = mustConnect()
    })
    return dbConn
}

// sync.Map — concurrent map when keys are stable and reads dominate writes
// Don't reach for sync.Map by default. A regular map + sync.RWMutex is usually clearer.

// sync.Pool — reusable temporary objects to reduce GC pressure
var bufPool = sync.Pool{
    New: func() any {
        return new(bytes.Buffer)
    },
}
func process(data []byte) {
    buf := bufPool.Get().(*bytes.Buffer)
    defer func() {
        buf.Reset()
        bufPool.Put(buf)
    }()
    // use buf...
}
```

### 11. Avoid `init()` Functions

`init()` functions run before `main()` in an order that depends on import graphs. This makes programs hard to test, hard to reason about, and impossible to control.

```go
// Do: Explicit initialization controlled by the caller
func main() {
    cfg := loadConfig()
    db := connectDB(cfg.DatabaseURL)
    srv := NewServer(db, cfg)
    srv.Run()
}

// Don't: Hidden initialization via init()
func init() {
    db = connectDB(os.Getenv("DATABASE_URL"))  // runs on import, untestable
}
```

The only acceptable use of `init()` is for side-effect-only imports like database driver registration (`_ "github.com/lib/pq"`) where the Go ecosystem has established this as convention.

### 12. Named Return Values — Sparingly

Named return values are for documentation, not for naked returns. Using naked returns makes functions harder to read because the returned values aren't visible at the return site.

```go
// Do: Named returns for documentation, explicit return
func (r *Ring) Position() (latitude, longitude float64) {
    return r.lat, r.lon
}

// Don't: Naked returns — the reader has to scroll up to know what's returned
func (r *Ring) Position() (latitude, longitude float64) {
    latitude = r.lat
    longitude = r.lon
    return  // what is being returned? reader must check the signature
}
```

### 13. Channel Direction Types in Function Signatures

When a function only sends to or receives from a channel, declare the direction in the parameter type. This makes intent clear and is enforced at compile time.

```go
// Do: Declare direction — sender can't accidentally receive, receiver can't send
func produce(ch chan<- Event) { /* can only send */ }
func consume(ch <-chan Event) { /* can only receive */ }

// Don't: Bidirectional channels everywhere
func produce(ch chan Event) { /* could accidentally receive too */ }
func consume(ch chan Event) { /* could accidentally send too */ }
```

### 14. Avoid Package-Level State

Global variables (package-level `var`) are shared mutable state. They make functions impure, break test isolation, and create hidden coupling between packages.

```go
// Do: Pass dependencies explicitly
type Server struct {
    db     *sql.DB
    logger *slog.Logger
    config Config
}

// Don't: Package-level globals
var db *sql.DB
var logger *slog.Logger

func HandleRequest(w http.ResponseWriter, r *http.Request) {
    user, err := db.QueryRow(...)  // hidden dependency, untestable
}
```

If you must have package-level state (e.g., metrics registries, feature flags), protect it with `sync.Once` or `sync.Mutex` and provide an explicit initialization function.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| `data, _ := json.Marshal(v)` — discard error | Check every error; panic on "impossible" ones with an explanation |
| `if err.Error() == "not found"` — string matching | `errors.Is(err, ErrNotFound)` — use sentinel errors or error types |
| `return fmt.Errorf("failed: %v", err)` — `%v` wrapping | `return fmt.Errorf("failed: %w", err)` — `%w` preserves the chain |
| 8-method interfaces defined at the implementation site | 1-2 method interfaces defined at the consumer site |
| `go doWork()` with no lifecycle management | `errgroup`, context cancellation, or `sync.WaitGroup` with clear exit |
| `context.Background()` as a shortcut in production code | Plumb the real `context.Context` from the entry point |
| Embedding structs to "inherit" behavior | Composition with explicit delegation |
| `init()` for database connections or config loading | Explicit initialization in `main()` or a constructor |
| Naked `return` in functions with named return values | Explicit `return lat, lon` even when returns are named |
| `var db *sql.DB` at package level | Struct fields with dependency injection |
| `chan Event` in a function that only sends | `chan<- Event` — declare the direction |
| `sync.Map` as a default concurrent map | `map` + `sync.RWMutex` unless you have a stable-key, read-heavy workload |

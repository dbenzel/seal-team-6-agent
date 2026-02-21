# Go Tooling

**Principle:** Go's toolchain is one of its greatest strengths — fast, opinionated, and batteries-included. Use the standard tools as your baseline, supplement with established community tools where they add clear value, and never fight the toolchain. A Go project with consistent tooling is a project where any engineer can be productive on day one.

---

## Rules

### 1. `go mod` for Dependency Management — Always Use Modules

Go modules are the only supported dependency management system. There is no alternative. Every Go project must have a `go.mod` file at the root.

```bash
# Initialize a new module
go mod init github.com/yourorg/yourproject

# Add a dependency (automatically updates go.mod and go.sum)
go get github.com/lib/pq@latest

# Remove unused dependencies
go mod tidy

# Vendor dependencies (for reproducible builds in CI or air-gapped environments)
go mod vendor
```

**Rules for `go.mod` hygiene:**

- Run `go mod tidy` before every commit — no stale dependencies
- Commit `go.sum` — it is the lockfile and ensures reproducible builds
- Pin major versions explicitly — `go get github.com/foo/bar/v2` not `github.com/foo/bar`
- Use `go mod vendor` in CI if you need hermetic builds or want to avoid network dependencies during build
- Never edit `go.mod` or `go.sum` by hand unless you understand exactly what you're changing

```go
// Don't: Use dep, glide, or GOPATH-based workflows
// These are dead. Modules won the tooling war. Move on.
```

### 2. `gofmt` / `goimports` — Non-Negotiable Formatting

Go has a single canonical format. There is no debate about tabs vs. spaces, brace placement, or import ordering. `gofmt` enforces this. `goimports` extends `gofmt` by also managing import grouping and removal.

```bash
# Format all Go files in the project
gofmt -w .

# Better: use goimports (formats + manages imports)
goimports -w .
```

**This is non-negotiable.** Every Go file must be formatted with `gofmt` before commit. Configure your editor to format on save. Configure CI to reject unformatted code.

```bash
# CI check: fail if any file is not formatted
test -z "$(gofmt -l .)"
```

Import grouping convention (enforced by `goimports`):

```go
import (
    // Standard library
    "context"
    "fmt"
    "net/http"

    // Third-party
    "github.com/go-chi/chi/v5"
    "github.com/stretchr/testify/assert"

    // Internal/project packages
    "github.com/yourorg/yourproject/internal/auth"
    "github.com/yourorg/yourproject/pkg/middleware"
)
```

Three groups, separated by blank lines: stdlib, third-party, internal. `goimports` handles this automatically.

### 3. `golangci-lint` with a Curated Set of Linters

`golangci-lint` is the standard Go linter aggregator. It runs dozens of linters in parallel, fast. Do not run linters individually — use `golangci-lint` as the single entry point.

```bash
# Install
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Run all configured linters
golangci-lint run ./...

# Run with auto-fix where supported
golangci-lint run --fix ./...
```

**Recommended `.golangci.yml` configuration:**

```yaml
run:
  timeout: 5m

linters:
  enable:
    # Bug detection
    - errcheck        # unchecked errors
    - gosec           # security issues
    - bodyclose       # unclosed HTTP response bodies
    - nilerr          # returning nil when err is not nil
    - sqlclosecheck   # unclosed sql.Rows

    # Style and correctness
    - govet           # go vet checks
    - staticcheck     # comprehensive static analysis
    - unused          # unused code
    - ineffassign     # ineffectual assignments
    - misspell        # spelling mistakes in comments and strings
    - unconvert       # unnecessary type conversions
    - unparam         # unused function parameters
    - revive          # extensible linter, replacement for golint

    # Complexity
    - gocyclo         # cyclomatic complexity
    - gocognit        # cognitive complexity

    # Performance
    - prealloc        # suggest preallocating slices
    - gocritic        # opinionated Go source code linter

linters-settings:
  gocyclo:
    min-complexity: 15
  gocognit:
    min-complexity: 20
  revive:
    rules:
      - name: unexported-return
        disabled: true  # accept interfaces return structs pattern
  errcheck:
    check-type-assertions: true
    check-blank: true

issues:
  exclude-use-default: false
  max-issues-per-linter: 0
  max-same-issues: 0
```

Do not disable linters to make CI green. If a linter finds something, either fix it or add a targeted `//nolint:lintername` comment with a justification. Blanket `//nolint` without a linter name is prohibited.

```go
// Do: Targeted nolint with justification
//nolint:errcheck // fire-and-forget logging; error is non-actionable
logger.Sync()

// Don't: Blanket suppression
//nolint
doSomethingDangerous()
```

### 4. `go vet` as the Minimum Static Analysis Baseline

`go vet` is built into the Go toolchain and catches real bugs: printf format mismatches, unreachable code, incorrect struct tags, and more. It is the absolute minimum — never skip it.

```bash
# Run go vet on all packages
go vet ./...
```

`go vet` runs automatically as part of `go test` since Go 1.10. If `golangci-lint` is your CI tool (and it should be), `govet` is included. But if you only have time to add one check, `go vet ./...` is it.

### 5. Use `govulncheck` for Vulnerability Scanning

`govulncheck` analyzes your dependency graph and binary against the Go vulnerability database. Unlike generic CVE scanners, it checks whether your code actually *calls* the vulnerable function — reducing false positives dramatically.

```bash
# Install
go install golang.org/x/vuln/cmd/govulncheck@latest

# Scan the project
govulncheck ./...

# Scan a built binary
govulncheck -mode=binary ./path/to/binary
```

Run `govulncheck` in CI on every build. It is fast, accurate, and maintained by the Go team. There is no reason not to run it.

```yaml
# Example CI step (GitHub Actions)
- name: Vulnerability check
  run: |
    go install golang.org/x/vuln/cmd/govulncheck@latest
    govulncheck ./...
```

### 6. Build with `-trimpath` and `-ldflags` for Reproducible Builds

Production binaries should be reproducible, stripped of local filesystem paths, and injected with version metadata.

```bash
# Production build
go build \
  -trimpath \
  -ldflags="-s -w -X main.version=${GIT_TAG} -X main.commit=${GIT_SHA} -X main.buildDate=${BUILD_DATE}" \
  -o bin/myapp \
  ./cmd/myapp/

# Flags explained:
# -trimpath       Remove local filesystem paths from the binary (security + reproducibility)
# -ldflags="-s"   Strip symbol table (smaller binary)
# -ldflags="-w"   Strip DWARF debug info (smaller binary)
# -ldflags="-X"   Inject build-time variables
```

**Version injection pattern:**

```go
// cmd/myapp/main.go
package main

var (
    version   = "dev"
    commit    = "none"
    buildDate = "unknown"
)

func main() {
    if os.Args[1] == "--version" {
        fmt.Printf("myapp %s (commit: %s, built: %s)\n", version, commit, buildDate)
        os.Exit(0)
    }
    // ...
}
```

Never build production binaries without `-trimpath`. Leaking your local filesystem structure into the binary is an information disclosure issue.

### 7. Use `go generate` for Code Generation

`go generate` runs commands embedded in Go source files via `//go:generate` directives. Use it for generating mocks, Protocol Buffer code, string methods for enums, and other derived code.

```go
// In the source file where generated code is needed
//go:generate mockgen -source=repository.go -destination=mock_repository_test.go -package=user
//go:generate stringer -type=Status

type Status int

const (
    StatusPending Status = iota
    StatusActive
    StatusSuspended
)
```

```bash
# Run all generate directives in the project
go generate ./...
```

**Rules for `go generate`:**

- Commit generated code — do not require consumers to run `go generate`
- Add a CI check that verifies generated code is up to date:

```bash
go generate ./...
git diff --exit-code  # fails if generate produced changes not committed
```

- Use `//go:generate` only in the file closest to the type/interface being generated for
- Never put secrets, API keys, or environment-dependent values in generate commands

### 8. Use `air` or `watchexec` for Hot Reload During Development

Go compiles fast, but restarting manually is slow. Use `air` or `watchexec` to rebuild and restart on file changes during development.

```bash
# Install air
go install github.com/air-verse/air@latest

# Run with defaults (looks for .air.toml in the project root)
air
```

**Recommended `.air.toml`:**

```toml
root = "."
tmp_dir = "tmp"

[build]
  bin = "./tmp/main"
  cmd = "go build -o ./tmp/main ./cmd/myapp/"
  delay = 1000
  exclude_dir = ["assets", "tmp", "vendor", "testdata", "node_modules"]
  exclude_file = []
  exclude_regex = ["_test.go"]
  exclude_unchanged = false
  follow_symlink = false
  include_ext = ["go", "tpl", "tmpl", "html", "yaml", "yml", "toml"]
  kill_delay = "0s"
  log = "build-errors.log"
  send_interrupt = false
  stop_on_error = true

[log]
  time = false

[misc]
  clean_on_exit = true
```

**Alternative: `watchexec`** — language-agnostic, no config file needed:

```bash
# Install
brew install watchexec  # or cargo install watchexec-cli

# Watch and rebuild
watchexec -r -e go -- go run ./cmd/myapp/
```

`air` is purpose-built for Go. `watchexec` is more general and works across polyglot projects. Pick one and standardize across the team.

---

## CI Pipeline Recommendations

A minimal CI pipeline for a Go project should run these steps in order:

```bash
# 1. Format check — reject unformatted code
test -z "$(gofmt -l .)"

# 2. Vet — catch basic bugs
go vet ./...

# 3. Lint — comprehensive static analysis
golangci-lint run ./...

# 4. Test — with race detector and coverage
go test -race -coverprofile=coverage.out ./...

# 5. Vulnerability scan
govulncheck ./...

# 6. Verify generated code is up to date
go generate ./...
git diff --exit-code

# 7. Build — confirm it compiles
go build -trimpath ./...
```

Steps 1-3 catch issues before the expensive test phase. Step 4 runs all tests with race detection. Steps 5-7 verify supply chain, generated code, and build integrity.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Use `dep`, `glide`, or `GOPATH` mode | Use `go mod` — modules are the only supported system |
| Have unformatted Go code in the repo | Run `gofmt` or `goimports` on save and in CI |
| Run individual linters (`errcheck`, `govet`, etc.) separately | Use `golangci-lint` as a single aggregated runner |
| Skip `go vet` because "the linter handles it" | Run `go vet` as the minimum baseline; `golangci-lint` includes it anyway |
| Ignore `govulncheck` because "we trust our deps" | Run `govulncheck` in CI — transitive vulnerabilities are invisible otherwise |
| Build production binaries with `go build ./cmd/app` | Add `-trimpath` and `-ldflags` for security and version injection |
| Require `go generate` to be run manually by consumers | Commit generated code; verify it's up to date in CI |
| Restart the server manually after every code change | Use `air` or `watchexec` for automatic rebuild on file change |
| Use `//nolint` without a linter name or justification | Always specify `//nolint:lintername` with a comment explaining why |
| Edit `go.mod` by hand to add dependencies | Use `go get` to add, `go mod tidy` to clean up |

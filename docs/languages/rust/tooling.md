# Rust Tooling

**Principle:** Rust's toolchain is one of the strongest in any language ecosystem. Use it fully. Formatting, linting, auditing, and benchmarking are not optional add-ons — they are built into the standard workflow. A project without `cargo fmt` and `cargo clippy` in CI is a project that will accumulate preventable defects.

---

## Rules

### 1. `cargo fmt` Is Non-Negotiable

All Rust code is formatted with `rustfmt` via `cargo fmt`. No debates about style, no manual formatting, no exceptions. Configure it once in `rustfmt.toml` if needed, then enforce it in CI.

```toml
# rustfmt.toml — keep it minimal, the defaults are good
edition = "2021"
max_width = 100
use_small_heuristics = "Max"
```

```bash
# Format everything
cargo fmt

# Check formatting in CI (fails if any file isn't formatted)
cargo fmt -- --check
```

Every PR that fails `cargo fmt -- --check` is rejected automatically. Developers should configure their editor to format on save so this never comes up in review.

### 2. `cargo clippy` — Treat Warnings as Errors in CI

Clippy catches hundreds of common mistakes, performance issues, and non-idiomatic patterns. In CI, run it with `-D warnings` so any Clippy lint is a hard failure. Locally, run it frequently during development.

```bash
# Local development
cargo clippy

# CI: warnings are errors
cargo clippy -- -D warnings

# Check all targets (tests, benches, examples)
cargo clippy --all-targets -- -D warnings
```

If a Clippy lint is genuinely wrong for your case, suppress it with an `#[allow(...)]` attribute and a comment explaining why — not with a blanket suppression in `Cargo.toml` or `lib.rs`.

```rust
// Do: Targeted suppression with justification
#[allow(clippy::needless_pass_by_value)]
// This function takes ownership intentionally because it sends the value to another thread.
fn spawn_worker(config: Config) { /* ... */ }

// Don't: Blanket suppression that hides real issues
#![allow(clippy::all)]
```

### 3. `cargo audit` for Vulnerability Scanning

`cargo audit` checks your dependency tree against the RustSec Advisory Database. Run it in CI on every build. A known vulnerability in a dependency is a blocker for deployment.

```bash
# Install once
cargo install cargo-audit

# Run in CI
cargo audit

# Deny warnings too (yanked crates, etc.)
cargo audit --deny warnings
```

Integrate this into your CI pipeline as a required check. Do not ship code with known vulnerable dependencies.

### 4. `cargo deny` for License and Dependency Policy

`cargo deny` enforces license compliance, bans specific crates, detects duplicate dependencies, and catches advisories. Define your policy in `deny.toml` and enforce it in CI.

```toml
# deny.toml
[licenses]
unlicensed = "deny"
allow = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"]
deny = ["GPL-3.0"]

[bans]
multiple-versions = "warn"
deny = [
    # We use rustls, not openssl
    { name = "openssl-sys", wrappers = [] },
]

[advisories]
vulnerability = "deny"
unmaintained = "warn"
```

```bash
# Install once
cargo install cargo-deny

# Run all checks
cargo deny check

# Run in CI
cargo deny check advisories licenses bans sources
```

### 5. Use Cargo Workspaces for Monorepos

When a project has multiple crates (library, CLI, server, shared types), use a Cargo workspace. It shares a single `Cargo.lock`, compiles shared dependencies once, and keeps everything in sync.

```toml
# Root Cargo.toml
[workspace]
members = [
    "crates/core",
    "crates/api",
    "crates/cli",
    "crates/shared-types",
]

# Share dependency versions across the workspace
[workspace.dependencies]
serde = { version = "1", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
anyhow = "1"
```

```toml
# crates/api/Cargo.toml
[dependencies]
serde = { workspace = true }
tokio = { workspace = true }
core = { path = "../core" }
shared-types = { path = "../shared-types" }
```

Do not use multiple independent `Cargo.lock` files in a monorepo. That is not a monorepo — it is multiple repos pretending to be one.

### 6. `cargo bench` with `criterion` for Benchmarking

The built-in `cargo bench` is unstable and unreliable for statistical analysis. Use `criterion` for proper benchmarking with statistical rigor, comparison reports, and regression detection.

```toml
# Cargo.toml
[dev-dependencies]
criterion = { version = "0.5", features = ["html_reports"] }

[[bench]]
name = "parser_benchmark"
harness = false
```

```rust
// benches/parser_benchmark.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};
use my_crate::parse;

fn benchmark_parser(c: &mut Criterion) {
    let input = include_str!("../fixtures/large_input.txt");

    c.bench_function("parse large input", |b| {
        b.iter(|| parse(black_box(input)))
    });
}

criterion_group!(benches, benchmark_parser);
criterion_main!(benches);
```

```bash
# Run benchmarks
cargo bench

# Compare against a baseline
cargo bench -- --save-baseline main
# ... make changes ...
cargo bench -- --baseline main
```

### 7. Use `rust-analyzer` as the IDE Extension

`rust-analyzer` is the official language server for Rust. It provides completions, go-to-definition, inline type hints, error diagnostics, and refactoring tools. Do not use the old RLS — it is deprecated.

Recommended editor settings for VS Code:

```json
{
    "rust-analyzer.check.command": "clippy",
    "rust-analyzer.cargo.features": "all",
    "rust-analyzer.procMacro.enable": true,
    "editor.formatOnSave": true,
    "[rust]": {
        "editor.defaultFormatter": "rust-lang.rust-analyzer"
    }
}
```

Setting `check.command` to `clippy` means you see Clippy warnings inline as you type, not just when you run CI.

### 8. Use Feature Flags for Optional Functionality

Cargo features let consumers opt in to functionality they need and avoid compiling what they don't. Use them for optional dependencies, performance-sensitive codepaths, and platform-specific code.

```toml
# Cargo.toml
[features]
default = ["json"]
json = ["dep:serde_json"]
yaml = ["dep:serde_yaml"]
tracing = ["dep:tracing", "dep:tracing-subscriber"]

[dependencies]
serde_json = { version = "1", optional = true }
serde_yaml = { version = "0.9", optional = true }
tracing = { version = "0.1", optional = true }
tracing-subscriber = { version = "0.3", optional = true }
```

```rust
#[cfg(feature = "json")]
pub fn from_json(s: &str) -> Result<Config, Error> {
    serde_json::from_str(s).map_err(Error::from)
}

#[cfg(feature = "yaml")]
pub fn from_yaml(s: &str) -> Result<Config, Error> {
    serde_yaml::from_str(s).map_err(Error::from)
}
```

Do not hide critical functionality behind features. Features should be additive — enabling a feature should never remove capabilities.

### 9. Pin the Rust Toolchain with `rust-toolchain.toml`

Every project should have a `rust-toolchain.toml` that specifies the exact Rust version. This ensures all developers and CI use the same compiler. No more "works on my machine" because someone is on nightly and you are on stable.

```toml
# rust-toolchain.toml
[toolchain]
channel = "1.78.0"
components = ["rustfmt", "clippy", "rust-src"]
targets = ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin"]
```

When upgrading the Rust version, update this file, run the full test suite and Clippy, fix any new warnings, and commit it all together.

### 10. Use `cargo-nextest` for Faster Test Execution

`cargo-nextest` runs tests in parallel processes (not threads), provides better output formatting, retries flaky tests, and is significantly faster than the default test runner for large projects.

```bash
# Install once
cargo install cargo-nextest

# Run tests (faster than cargo test for projects with many tests)
cargo nextest run

# Run with retries for flaky test detection
cargo nextest run --retries 2

# Run specific tests
cargo nextest run -E 'test(parse)'

# Generate JUnit XML for CI
cargo nextest run --profile ci
```

Configure it in `.config/nextest.toml`:

```toml
# .config/nextest.toml
[profile.default]
retries = 0
slow-timeout = { period = "30s", terminate-after = 2 }
fail-fast = true

[profile.ci]
retries = 2
fail-fast = false
```

Use `cargo-nextest` in CI. Use the default `cargo test` only when you need doc tests (nextest does not run doc tests — run those separately with `cargo test --doc`).

---

## Recommended CI Pipeline

A minimal CI pipeline for a Rust project should run these steps in order:

```yaml
# Example: GitHub Actions
steps:
  - name: Format check
    run: cargo fmt -- --check

  - name: Clippy
    run: cargo clippy --all-targets -- -D warnings

  - name: Unit and integration tests
    run: cargo nextest run

  - name: Doc tests
    run: cargo test --doc

  - name: Ignored / slow tests
    run: cargo nextest run --run-ignored ignored-only

  - name: Security audit
    run: cargo audit --deny warnings

  - name: License and dependency check
    run: cargo deny check
```

Every step is a gate. If formatting is wrong, nothing else runs. If Clippy has warnings, tests don't run. This catches the cheapest problems first.

---

## Anti-Patterns

| Don't | Do Instead | Why |
|---|---|---|
| Skip `cargo fmt` because "my style is fine" | Run `cargo fmt` on save and in CI | Formatting debates waste review time; automation eliminates them |
| Allow Clippy warnings to accumulate | `-D warnings` in CI; fix or `#[allow]` with justification | Clippy warnings become noise, hiding real issues |
| Blanket `#![allow(clippy::all)]` | Targeted `#[allow(clippy::specific_lint)]` with comments | Blanket allows disable legitimate catches |
| Ignore `cargo audit` findings | Block merges on known vulnerabilities | Shipping known-vulnerable code is a security incident waiting to happen |
| Multiple `Cargo.lock` files in a monorepo | Single workspace with `workspace.dependencies` | Independent locks drift, causing version conflicts and duplicate builds |
| Use `#[bench]` with the built-in harness | Use `criterion` with `harness = false` | Built-in bench is unstable and lacks statistical rigor |
| No `rust-toolchain.toml` | Pin the exact Rust version in `rust-toolchain.toml` | Different compiler versions produce different warnings and behavior |
| Run all tests in the default `cargo test` | Use `cargo-nextest` for fast parallel execution | Default runner is single-threaded per test binary; nextest is faster |
| Additive and subtractive feature flags | Features should only add capabilities, never remove them | Subtractive features break user expectations and cause subtle bugs |
| Deploy without running `cargo audit` | Audit in CI on every build | New advisories are published constantly; today's clean build is tomorrow's vulnerability |

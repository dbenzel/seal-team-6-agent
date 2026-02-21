# Python Tooling Best Practices

> **Principle:** The Python ecosystem has historically suffered from fragmented, overlapping tooling. That era is over. Consolidate on a minimal, fast, modern toolchain — `pyproject.toml` for config, `uv` for packages, `ruff` for style, `mypy`/`pyright` for types. Every check runs in pre-commit. No developer should ever need to think about which tool handles what.

---

## Rules

1. **`pyproject.toml` is the single source of project configuration.** All project metadata, dependencies, build config, tool settings (`[tool.ruff]`, `[tool.mypy]`, `[tool.pytest.ini_options]`) live in one file. Do not create `setup.py`, `setup.cfg`, `requirements.txt`, `tox.ini`, `.flake8`, `.isort.cfg`, or `mypy.ini` as separate files. Every tool that matters reads `pyproject.toml` natively. One file, one truth.

2. **Use `uv` or `poetry` for dependency management. Prefer `uv` for speed.** `uv` is 10-100x faster than pip and poetry for resolution and installation. It handles virtual environments, lockfiles, and Python version management. If your team already uses poetry and it works, don't migrate for the sake of it — but for new projects, `uv` is the default choice. Never use raw `pip install` without a lockfile in CI.

3. **Use `ruff` for linting AND formatting.** `ruff` replaces `black`, `isort`, `flake8`, `pyflakes`, `pycodestyle`, `pydocstyle`, `pylint` (partially), and dozens of flake8 plugins — in a single Rust-based tool that runs in milliseconds. Configure it once in `pyproject.toml`. There is no reason to run multiple Python linters in 2024+.

4. **Use `mypy` or `pyright` for type checking — run in strict mode.** Gradual typing without a type checker is just comments. Run `mypy --strict` or `pyright` with `typeCheckingMode = "strict"` in CI. Fix violations immediately — do not accumulate a backlog of `type: ignore` comments. If you must suppress an error, use `type: ignore[specific-error-code]` with a comment explaining why.

5. **Always use virtual environments. Never install packages globally.** Every project gets its own isolated environment. Use `uv venv`, `python -m venv`, or let `uv` manage it implicitly with `uv run`. Global installs cause version conflicts, pollute the system Python, and make builds non-reproducible. This applies to development machines AND CI.

6. **Use pre-commit hooks for automated checks.** Every lint, format, and type check runs automatically before code is committed. Developers should never need to remember to run these manually. Use the `pre-commit` framework with `.pre-commit-config.yaml`. At minimum: `ruff check`, `ruff format`, `mypy` (or `pyright`). Optional but recommended: `detect-secrets`, `check-toml`, `check-yaml`.

7. **Use `python -m` to run modules.** Running `python -m pytest` instead of `pytest` ensures the correct Python interpreter is used and the current directory is on `sys.path`. This avoids the class of bugs where a script imports from the wrong package or a different Python version's site-packages. This matters especially in CI and when multiple Python versions are installed.

---

## Examples

### pyproject.toml as Single Config Source

```toml
# DO: Everything in one file
[project]
name = "myapp"
version = "1.2.0"
requires-python = ">=3.11"
dependencies = [
    "httpx>=0.27",
    "pydantic>=2.0",
    "sqlalchemy>=2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-mock>=3.12",
    "pytest-cov>=5.0",
    "hypothesis>=6.0",
    "factory-boy>=3.3",
    "mypy>=1.8",
    "ruff>=0.3",
    "pre-commit>=3.6",
]

[tool.ruff]
target-version = "py311"
line-length = 99

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "SIM",  # flake8-simplify
    "TCH",  # flake8-type-checking
    "RUF",  # ruff-specific rules
]

[tool.ruff.lint.isort]
known-first-party = ["myapp"]

[tool.mypy]
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-ra --strict-markers --strict-config"
markers = [
    "slow: marks tests as slow (deselect with '-m not slow')",
    "integration: marks integration tests",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

```
# DON'T: Config scattered across 7 files
setup.py
setup.cfg
requirements.txt
requirements-dev.txt
.flake8
.isort.cfg
mypy.ini
tox.ini
pytest.ini
```

### uv for Dependency Management

```bash
# DO: Fast, reproducible, lockfile-based
uv init myproject
cd myproject
uv add httpx pydantic sqlalchemy
uv add --dev pytest pytest-mock ruff mypy
uv lock                    # generates uv.lock
uv run pytest              # runs in managed venv
uv run python -m myapp     # runs your app

# In CI:
uv sync --frozen           # installs exactly what's in lockfile, fails if stale


# DON'T: Slow, no lockfile, non-reproducible
pip install httpx pydantic sqlalchemy
pip install pytest pytest-mock ruff mypy
pip freeze > requirements.txt   # pins transitive deps you didn't choose
pip install -r requirements.txt # "works on my machine"
```

### Ruff for Linting and Formatting

```bash
# DO: One tool, milliseconds, consistent
ruff check .               # lint (finds ~800 rule categories)
ruff check . --fix         # auto-fix what can be auto-fixed
ruff format .              # format (replaces black + isort)

# In pre-commit:
ruff check --fix && ruff format

# In CI:
ruff check . && ruff format --check .


# DON'T: Four separate tools, each with its own config
black .                    # formatting
isort .                    # import sorting
flake8 .                   # linting
pylint .                   # more linting (30 seconds later...)
```

### Type Checking in Strict Mode

```bash
# DO: Strict mode, specific suppressions
# In pyproject.toml:
# [tool.mypy]
# strict = true

mypy src/
# or
pyright --pythonversion 3.11 src/

# When you must suppress, be specific:
value = cast(str, get_value())  # type: ignore[redundant-cast]  # upstream types are wrong
```

```python
# DON'T: Loose mode with blanket ignores
# mypy.ini
# [mypy]
# ignore_missing_imports = True   # hides real import errors
# disallow_untyped_defs = False   # defeats the purpose

result = some_function()  # type: ignore  # suppresses ALL errors on this line
```

### Virtual Environments

```bash
# DO: Isolated per project, explicit activation
uv venv                            # creates .venv/
source .venv/bin/activate          # explicit activation
# or skip activation entirely:
uv run python -m pytest            # uv handles the venv

# In CI:
uv sync --frozen
uv run python -m pytest


# DON'T: Global installs, version conflicts, "works on my machine"
sudo pip install flask             # pollutes system Python
pip install --user package         # ~/.local collisions
pip install package                # which Python? which site-packages?
```

### Pre-commit Configuration

```yaml
# .pre-commit-config.yaml
# DO: Automated, consistent, fast
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.10.0
    hooks:
      - id: mypy
        additional_dependencies: [pydantic>=2.0, types-requests]
        args: [--strict]

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: check-toml
      - id: check-yaml
      - id: check-added-large-files
        args: [--maxkb=500]
      - id: debug-statements        # catches leftover breakpoint()
      - id: trailing-whitespace
      - id: end-of-file-fixer
```

```bash
# Install once per repo clone
pre-commit install

# Run manually on all files (useful for initial setup)
pre-commit run --all-files


# DON'T: Rely on developers remembering to run checks
# "Please run black and flake8 before committing" (narrator: they didn't)
```

### Running Modules with `python -m`

```bash
# DO: Explicit interpreter, correct sys.path
python -m pytest tests/
python -m mypy src/
python -m myapp.cli --config prod.toml
uv run python -m pytest tests/

# DON'T: Rely on PATH resolution (which python? which pytest?)
pytest tests/          # might use system pytest with wrong Python version
mypy src/              # might use globally installed mypy
python myapp/cli.py    # sys.path won't include project root correctly
```

---

## Anti-Patterns

| Anti-Pattern | Why It's Harmful | What to Do Instead |
|---|---|---|
| Config split across `setup.py`, `setup.cfg`, `requirements.txt`, `.flake8`, etc. | Multiple sources of truth, easy to get out of sync, confusing for new developers | Consolidate everything into `pyproject.toml` |
| Raw `pip install` without a lockfile | Non-reproducible builds, transitive dependency changes break things silently | Use `uv lock` / `poetry lock` and install from lockfile in CI |
| Running `black` + `isort` + `flake8` separately | Three tools, three configs, three CI steps, contradictory settings possible | Use `ruff` for all three in one pass |
| `mypy` without `--strict` | Catches almost nothing by default, false sense of type safety | Enable `strict = true` in `pyproject.toml`, fix violations as they arise |
| Installing packages globally / `sudo pip install` | Version conflicts between projects, pollutes system Python, breaks OS tools | Always use virtual environments (`uv venv`, `python -m venv`) |
| No pre-commit hooks | Developers forget to lint/format, inconsistent code lands in PRs | Install `pre-commit` with ruff + mypy hooks |
| `requirements.txt` as primary dependency spec | No distinction between direct and transitive deps, no resolution metadata | Use `pyproject.toml` `[project.dependencies]` with a proper lockfile |
| Running `pytest` instead of `python -m pytest` | Wrong Python interpreter, missing `sys.path` entries, import confusion | Always use `python -m pytest` or `uv run python -m pytest` |
| Pinning exact versions in `pyproject.toml` (`httpx==0.27.0`) | Prevents compatible updates, creates resolution conflicts with other packages | Use compatible ranges (`httpx>=0.27`), pin exact versions only in lockfile |
| `# type: ignore` without error code | Suppresses all type errors on the line, hides real issues introduced later | Use `# type: ignore[specific-code]` with explanation |
| `tox` for simple test matrix | Over-engineered for most projects, slow, duplicates CI config | Use CI matrix (GitHub Actions `strategy.matrix`) for Python version testing |
| Manually managing Python versions | Version mismatch between dev and CI, "works on my machine" | Use `uv python install 3.12` or `pyenv` with `.python-version` file |

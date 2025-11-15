# Git Hooks

This directory contains git hooks that enforce code quality and prevent common issues before commits and pushes.

## Installation

Run the setup script to enable hooks:

```bash
./.githooks/setup.sh
```

This configures git to use `.githooks/` as the hooks directory.

## Available Hooks

### pre-commit (Fast Checks)

Runs on every `git commit` to catch basic issues early:

**Checks:**
- Code formatting (`mix format --check-formatted`)
- Compilation (`mix compile --warnings-as-errors`)
- Static analysis (`mix credo`)
- Ash resource migrations check (`mix ash.codegen --check`)

**Execution time:** ~10-30 seconds

**To bypass:** `git commit --no-verify`

### pre-push (Thorough Checks)

Runs on every `git push` for comprehensive validation:

**Checks:**
- Type checking (`mix dialyzer`)
- Security analysis (`mix sobelow`)
- Dependency security audit (`mix deps.audit`)
- Unused dependencies check (`mix deps.unlock --check-unused`)
- Usage rules validation (`mix usage_rules.check`)
- Test suite (`mix test`)

**Execution time:** ~1-8 minutes (depending on PLT cache and test count)

**To bypass:** `git push --no-verify`

## Shift-Left CI/CD Strategy

These hooks implement a "shift-left" approach to CI/CD:

1. **Pre-commit** (Phase 1): Fast feedback on code quality
2. **Pre-push** (Phase 2): Comprehensive validation before code reaches CI
3. **GitHub Actions** (Phase 3): Final verification and deployment

This catches issues locally before they waste CI/CD resources and time.

## Hook Execution Flow

```
┌─────────────────┐
│  git commit     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Pre-Commit Hook (Fast)         │
│  - Format check                 │
│  - Compilation                  │
│  - Static analysis (Credo)      │
│  - Ash migrations check         │
└────────┬────────────────────────┘
         │ ✓ Pass
         ▼
┌─────────────────┐
│  Commit Created │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  git push       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Pre-Push Hook (Thorough)       │
│  - Type checking (Dialyzer)     │
│  - Security (Sobelow)           │
│  - Dependency audit             │
│  - Usage rules                  │
│  - Tests                        │
└────────┬────────────────────────┘
         │ ✓ Pass
         ▼
┌─────────────────┐
│  Pushed to      │
│  Remote         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  GitHub Actions │
│  CI Pipeline    │
└─────────────────┘
```

## Troubleshooting

### Hooks not running

If hooks aren't executing:

```bash
# Check current hooks path
git config core.hooksPath

# Should output: .githooks
# If not, run setup again
./.githooks/setup.sh
```

### Hooks fail with "command not found"

Ensure you have the required tools installed:

- **Elixir**: `elixir --version` (1.18+)
- **Mix**: `mix --version`

### First Dialyzer run is slow

First time running Dialyzer will build PLT (Persistent Lookup Table) which takes 2-5 minutes. Subsequent runs use the cached PLT and are much faster (~30 seconds).

### Format check fails

Run formatter before committing:

```bash
mix format
```

### Tests fail

Run tests locally to fix issues:

```bash
mix test
# Or run specific test
mix test path/to/test_file.exs
```

## Customization

To modify hook behavior:

1. Edit the hook files in `.githooks/`
2. Adjust checks to match your needs
3. Update timing estimates in this README
4. Commit changes

## Disabling Hooks

To temporarily disable all hooks:

```bash
git config core.hooksPath ""
```

To re-enable:

```bash
./.githooks/setup.sh
```

## CI/CD Integration

These hooks complement the GitHub Actions workflow in `.github/workflows/ci.yml`:

- **Local hooks**: Fast feedback during development
- **GitHub Actions**: Comprehensive checks on push/PR
- **Both use same tools**: Ensures consistency

This eliminates surprises where local passes but CI fails.

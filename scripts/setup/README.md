# Setup Scripts

One-time setup scripts for project initialization and configuration.

## Available Scripts

### install-git-hooks.sh

**Install Git hooks for automation**

```bash
./scripts/setup/install-git-hooks.sh
```

**What it does:**
- Installs pre-commit hooks
- Sets up post-commit hooks
- Configures Git automation
- Links hooks from `.githooks/` to `.git/hooks/`

**When to use:**
- Initial project setup
- After cloning repository
- Setting up new developer environment
- After Git hooks are updated

**Hooks installed:**

1. **Pre-commit**:
   - Code formatting checks (`mix format --check-formatted`)
   - Linting with Credo
   - Prevents commits with syntax errors

2. **Post-commit**:
   - ExDoc generation (when lib/ files change)
   - Documentation updates
   - Prompts to commit updated docs

---

## Usage

### First Time Setup

Run this script once when setting up your development environment:

```bash
# After cloning the repository
cd ehs_enforcement

# Install dependencies
mix deps.get

# Install Git hooks
./scripts/setup/install-git-hooks.sh

# Start development
./scripts/development/ehs-dev.sh
```

### What to Expect

**During installation:**
```
🔧 Installing Git hooks for EHS Enforcement project
✓ Checking .githooks directory
✓ Installing pre-commit hook
✓ Installing post-commit hook
✓ Making hooks executable
✓ Git hooks installed successfully!

Next steps:
- Git hooks will run automatically on commit
- Pre-commit checks code formatting and style
- Post-commit updates documentation when needed
```

**During commits:**
```bash
git commit -m "feat: add new feature"

# Pre-commit hook runs:
# - Checking code formatting...
# - Running Credo...
# - All checks passed ✓

# Post-commit hook runs (if lib/ files changed):
# - Detecting changes to lib/ files
# - Generating ExDoc documentation...
# - Documentation updated
# - Commit updated docs? (y/n)
```

---

## Git Hooks Details

### Pre-commit Hook

**Purpose**: Ensure code quality before committing

**Checks:**
1. **Code Formatting**:
   ```bash
   mix format --check-formatted
   ```
   - Ensures code follows Elixir style guide
   - Fails if code needs formatting
   - Run `mix format` to fix

2. **Linting**:
   ```bash
   mix credo --strict
   ```
   - Checks for code issues
   - Enforces best practices
   - Suggests improvements

**If checks fail**:
```bash
# Fix formatting
mix format

# Fix Credo issues
# Review output and fix issues

# Try commit again
git commit -m "your message"
```

### Post-commit Hook

**Purpose**: Keep documentation up to date

**Behavior:**
- Monitors changes to:
  - `lib/` directory (source code)
  - `mix.exs` (dependencies)
  - `README.md` (main docs)

- When changes detected:
  1. Generates updated ExDoc
  2. Prompts to commit documentation
  3. Provides commit command

**Smart detection**:
- Only runs when necessary
- Skips for test files
- Skips for config files
- Fast execution

---

## Troubleshooting

### Hook Installation Fails

```bash
# Check .githooks directory exists
ls -la .githooks/

# Make install script executable
chmod +x scripts/setup/install-git-hooks.sh

# Run with verbose output
bash -x scripts/setup/install-git-hooks.sh
```

### Pre-commit Hook Fails

```bash
# Format code
mix format

# Fix Credo issues
mix credo

# Bypass hook (emergency only!)
git commit --no-verify -m "message"
```

### Post-commit Hook Issues

```bash
# Regenerate docs manually
mix docs

# Check ExDoc installed
mix deps.get

# Skip post-commit hook
# (commits normally, hook runs after)
```

### Hooks Not Running

```bash
# Check hooks are installed
ls -la .git/hooks/

# Check hooks are executable
ls -la .git/hooks/pre-commit
ls -la .git/hooks/post-commit

# Reinstall
./scripts/setup/install-git-hooks.sh
```

---

## Customizing Hooks

### Modify Hook Behavior

Edit hooks in `.githooks/` directory:

```bash
# Edit pre-commit behavior
vim .githooks/pre-commit

# Edit post-commit behavior
vim .githooks/post-commit

# Reinstall after changes
./scripts/setup/install-git-hooks.sh
```

### Disable Hooks Temporarily

```bash
# Disable pre-commit for one commit
git commit --no-verify -m "message"

# Disable all hooks temporarily
mv .git/hooks .git/hooks.disabled

# Re-enable
mv .git/hooks.disabled .git/hooks
```

---

## Team Workflow

### New Team Members

All developers should run during initial setup:

```bash
./scripts/setup/install-git-hooks.sh
```

### Hook Updates

When hooks are updated in `.githooks/`:

1. **Announce to team**: "Please reinstall Git hooks"
2. **Team members run**:
   ```bash
   ./scripts/setup/install-git-hooks.sh
   ```
3. **Verify**: Make a test commit

---

## CI/CD Integration

The same checks run in CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Check formatting
  run: mix format --check-formatted

- name: Run Credo
  run: mix credo --strict

- name: Generate docs
  run: mix docs
```

**Local hooks** = faster feedback
**CI/CD checks** = enforce for all commits

---

## Future Setup Scripts

Additional setup scripts that may be added:

- `setup_secrets.sh` - Configure environment variables
- `setup_dependencies.sh` - Install system dependencies
- `setup_docker.sh` - Configure Docker environment
- `setup_editors.sh` - Configure editors/IDEs

---

## Related Documentation

- **[docs-dev/GETTING_STARTED.md](../../docs-dev/GETTING_STARTED.md)** - Initial setup guide
- **[docs-dev/DEVELOPMENT_WORKFLOW.md](../../docs-dev/DEVELOPMENT_WORKFLOW.md)** - Development workflow
- **[docs-dev/DOCS_PLAN.md](../../docs-dev/DOCS_PLAN.md)** - Documentation automation

---

**Parent README**: [scripts/README.md](../README.md)

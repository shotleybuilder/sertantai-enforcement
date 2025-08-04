# ExDoc Automation Setup Guide

This guide helps you set up intelligent ExDoc automation that only regenerates documentation when your source code changes.

## Quick Setup (5 minutes)

### 1. Install Git Hooks (Local Development)
```bash
# Run from project root
./scripts/install-git-hooks.sh
```

**What this does:**
- ✅ Installs post-commit hook that watches for `lib/`, `mix.exs`, `README.md` changes
- ✅ Automatically regenerates ExDoc when you commit relevant changes
- ✅ Prompts you to commit updated documentation
- ✅ Skips regeneration for irrelevant files (tests, config, etc.)

### 2. Verify ExDoc Configuration
```bash
# Check that ExDoc is configured correctly
mix docs
```

**Expected output:**
- ExDoc generates to `docs_dev/exdoc/`
- No errors during generation
- Documentation includes all your modules

### 3. Test the Automation
```bash
# Make a small change to any file in lib/
echo "# Test comment" >> lib/ehs_enforcement.ex

# Commit the change
git add lib/ehs_enforcement.ex
git commit -m "test: trigger ExDoc automation"

# You should see:
# - Hook detects lib/ file change
# - ExDoc regenerates automatically
# - Prompt to commit updated docs
```

## How It Works

### Intelligent Triggers
**ExDoc regenerates ONLY when these files change:**
- `lib/**` - Your source code
- `mix.exs` - Dependencies or project config
- `README.md` - Main documentation file

**ExDoc SKIPS regeneration for:**  
- `test/**` - Test files
- `config/**` - Configuration files
- `docs/**` - User documentation (separate from API docs)
- `priv/**` - Private application files
- `scripts/**` - Utility scripts

### Local Development Flow
1. **Make changes** to source code in `lib/`
2. **Commit normally** - no special commands needed
3. **Hook activates** and detects relevant file changes
4. **ExDoc regenerates** automatically in background
5. **Get prompted** to commit updated documentation
6. **Choose yes/no** - your documentation stays current

### CI/CD Flow (GitHub Actions)
1. **Push commits** to GitHub
2. **GitHub Actions checks** what files changed
3. **Conditionally runs** ExDoc generation job
4. **Auto-commits** updated documentation
5. **Adds PR comments** showing documentation status

## Advanced Configuration

### Customize Trigger Patterns
Edit `.githooks/post-commit` to modify which files trigger ExDoc:

```bash
# Add new patterns to this array
EXDOC_TRIGGER_PATTERNS=(
    "^lib/"                    # Source code
    "^mix\.exs$"              # Project config
    "^README\.md$"            # Main docs
    "^your_custom_pattern/"   # Add your own
)
```

### Disable for Specific Commits
```bash
# Skip ExDoc automation for one commit
SKIP_EXDOC=1 git commit -m "WIP: temporary changes"
```

### Manual ExDoc Generation
```bash
# Generate docs manually anytime
mix docs

# Or use the helper script
./scripts/docs_workflow.sh
```

## Troubleshooting

### Hook Not Running
```bash
# Check if hook is installed and executable
ls -la .git/hooks/post-commit

# Reinstall if missing
./scripts/install-git-hooks.sh
```

### ExDoc Not Found
```bash
# Install ExDoc dependency
mix deps.get

# Verify it's working
mix help docs
```

### Hook Running But No Prompt
```bash
# Check if you're in a terminal that supports interactivity
# Hooks may not prompt in some Git GUI tools
# Use command line Git for full functionality
```

### Documentation Not Updating
```bash
# Check if there are actually changes
git status docs_dev/exdoc/

# Manual regeneration to test
mix docs
git status docs_dev/exdoc/
```

## Benefits

✅ **Never forget** to update documentation - it happens automatically  
✅ **Only runs when needed** - no wasted time on unnecessary regeneration  
✅ **Works locally and CI/CD** - consistent across environments  
✅ **Team-friendly** - everyone gets the same automation  
✅ **Traceable** - clear commit messages show what triggered updates  
✅ **Optional** - you can still choose whether to commit updated docs  

## Team Adoption

### For New Team Members
1. Clone the repository
2. Run `./scripts/install-git-hooks.sh`
3. Start coding - automation works immediately

### For Existing Team Members  
1. Pull latest changes (includes hook files)
2. Run `./scripts/install-git-hooks.sh` 
3. Continue normal development workflow

The automation is designed to be **invisible when not needed** and **helpful when triggered**. Your development workflow stays the same, but your documentation stays current automatically.
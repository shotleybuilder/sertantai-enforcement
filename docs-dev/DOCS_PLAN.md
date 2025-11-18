# Documentation Plan

## Overview
Two-tier documentation system for EHS Enforcement project:
- **User Documentation**: Public via GitHub Pages
- **Developer Documentation**: Private, repo-access only

## Structure

```
ehs_enforcement/
├── docs/                          # → GitHub Pages (Public User Docs)
│   ├── index.md                   # Landing page
│   ├── installation.md            # Installation guide
│   ├── user-guide.md             # User manual
│   ├── tutorials/                # Step-by-step guides
│   └── _config.yml               # Jekyll config
├── docs_dev/                     # → Private Developer Docs
│   ├── architecture.md           # System architecture
│   ├── development.md            # Dev setup & workflows
│   ├── deployment.md             # Deployment procedures
│   ├── api/                      # ExDoc output
│   └── internal/                 # Admin guides
├── CLAUDE.md                     # Dev guidelines (stays in root)
└── .github/workflows/docs.yml    # CI automation
```

## Visibility & Access

### Public User Docs (`/docs` → GitHub Pages)
- **URL**: `https://username.github.io/ehs_enforcement`
- **Content**: Installation, user guides, tutorials, public API
- **Access**: Public internet
- **Technology**: Jekyll (GitHub default) or custom generator

### Private Developer Docs (`/docs_dev`)
- **Access**: Repository collaborators only
- **Content**: Architecture, development setup, admin procedures, ExDoc API
- **Technology**: Markdown files + ExDoc generated content

## Automation Scripts

### 1. Smart ExDoc Generation (Git Hooks)
```bash
#!/bin/bash
# .githooks/post-commit
# Automatically regenerates ExDoc when relevant files change

# Only regenerate when these file patterns change:
# - lib/ directory (source code)
# - mix.exs (dependencies/configuration)
# - README.md (included in documentation)

# Features:
# - Detects changes in last commit
# - Only runs when necessary
# - Prompts to commit updated docs
# - Colored output for better UX
```

### 2. Hook Installation
```bash
#!/bin/bash
# scripts/install-git-hooks.sh
# Team members run this once to set up automatic ExDoc updates

# Installs post-commit hook
# Checks ExDoc dependency availability
# Provides setup instructions
```

### 3. GitHub Actions CI (Smart CI/CD)
```yaml
# .github/workflows/docs.yml
name: Documentation

on:
  push:
    branches: [ main ]
    paths:
      - 'lib/**'        # Source code changes
      - 'mix.exs'       # Dependency changes
      - 'README.md'     # Documentation changes
      - 'docs/**'       # User docs changes

jobs:
  # Check if ExDoc regeneration is needed
  check-docs-needed:
    runs-on: ubuntu-latest
    outputs:
      docs-needed: ${{ steps.changes.outputs.docs }}
    steps:
      - name: Check for documentation-relevant changes
        run: |
          # Intelligently detect if ExDoc should regenerate
          # Only run when lib/, mix.exs, or README.md change
          # Skip unnecessary CI runs for other file changes

  # Generate ExDoc only when needed
  generate-exdoc:
    needs: check-docs-needed
    if: needs.check-docs-needed.outputs.docs-needed == 'true'
    steps:
      - name: Generate ExDoc
        run: mix docs
      - name: Commit updated docs
        run: |
          # Auto-commit updated ExDoc files
          # Include commit hash in message for traceability

  # Deploy user docs to GitHub Pages
  deploy-pages:
    steps:
      - name: Build with Jekyll
        # Deploy public user documentation
      - name: Deploy to GitHub Pages
        # Make user docs available publicly
```

### 3. Development Helper Script
```bash
#!/bin/bash
# scripts/docs_workflow.sh

echo "🔄 EHS Enforcement Documentation Workflow"
echo "=========================================="

# Generate ExDoc
echo "1. Generating ExDoc..."
mix docs --output docs_dev/api --main "EhsEnforcement"

# Check for changes in user docs
if git diff --quiet docs/; then
    echo "✅ No changes in user docs"
else
    echo "📝 User docs changed - will auto-deploy via GitHub Pages"
fi

# Check for changes in dev docs
if git diff --quiet docs_dev/; then
    echo "✅ No changes in developer docs"
else
    echo "📝 Developer docs updated"
fi

echo ""
echo "Next steps:"
echo "- Commit changes: git add . && git commit -m 'Update documentation'"
echo "- Push to trigger CI: git push"
echo "- User docs will auto-deploy to GitHub Pages"
echo "- Dev docs available to repo collaborators"
```

## Setup Instructions

### 1. Initialize User Docs
```bash
# Create docs structure
mkdir -p docs/{tutorials,api}

# Initialize Jekyll (optional)
cd docs
echo "theme: minima" > _config.yml
echo "title: EHS Enforcement Documentation" >> _config.yml
```

### 2. Configure GitHub Pages
1. Go to repository Settings → Pages
2. Source: "Deploy from a branch"
3. Branch: `main` / Folder: `/docs`

### 3. Configure ExDoc
```elixir
# mix.exs
def project do
  [
    # ... other config
    docs: [
      main: "EhsEnforcement",
      output: "docs_dev/api",
      extras: ["README.md"]
    ]
  ]
end
```

### 4. Make Scripts Executable
```bash
chmod +x scripts/generate_dev_docs.sh
chmod +x scripts/docs_workflow.sh
```

## Workflow

### For User Documentation Changes
1. Edit files in `/docs`
2. Commit and push
3. GitHub Actions automatically deploys to Pages

### For Developer Documentation
1. Run `scripts/docs_workflow.sh`
2. Review generated ExDoc in `docs_dev/api/`
3. Commit changes (include `[docs]` in commit message for CI)
4. Push to repository

### For ExDoc Updates
- Triggered automatically when:
  - Commit message contains `[docs]`
  - Changes in `lib/` directory
  - Changes in `mix.exs`

## Intelligent ExDoc Automation System

### How It Works
The system uses **smart detection** to only regenerate ExDoc when necessary:

**Local Development (Git Hooks):**
1. **Post-commit hook** checks files in each commit
2. **Triggers only when** `lib/`, `mix.exs`, or `README.md` change
3. **Prompts user** to commit updated documentation
4. **Skips regeneration** for other file changes (tests, config, docs, etc.)

**CI/CD (GitHub Actions):**
1. **Path-based triggers** only run workflow for relevant file changes
2. **Conditional job execution** - ExDoc job only runs when needed
3. **Automatic commits** of updated documentation
4. **PR comments** with documentation status updates

### File Patterns That Trigger ExDoc Regeneration
- `lib/**` - Any source code changes
- `mix.exs` - Dependency or project configuration changes
- `README.md` - Main documentation file included in ExDoc

### File Patterns That DON'T Trigger ExDoc
- `test/**` - Test files don't affect API documentation
- `config/**` - Configuration files don't change public API
- `docs/**` - User documentation is separate from API docs
- `priv/**` - Private files don't affect public API
- `scripts/**` - Utility scripts don't affect API

### View ExDoc
- `cd /home/jason/Desktop/ehs-enforcement`
- `python3 -m http.server 8080`

http://localhost:8080/docs_dev/exdoc/index.html

### Setup Instructions

**For Team Members:**
1. Run `scripts/install-git-hooks.sh` once to install local automation
2. Commit changes normally - ExDoc updates automatically when needed
3. Follow prompts to commit updated documentation

**For New Repositories:**
1. Copy `.githooks/post-commit` to your `.githooks/` directory
2. Copy `.github/workflows/docs.yml` for CI/CD automation
3. Update `mix.exs` with ExDoc configuration
4. Run hook installer script

### Benefits

✅ **Intelligent**: Only regenerates when source code changes
✅ **Efficient**: Skips unnecessary documentation updates
✅ **Automated**: Works locally and in CI/CD without manual intervention
✅ **User-Friendly**: Clear prompts and colored output
✅ **Traceable**: Commit messages include triggering file information
✅ **Secure**: Dev docs private, user docs public
✅ **Maintainable**: Clear separation of concerns
✅ **Professional**: GitHub Pages provides excellent UX
✅ **Version Controlled**: All docs tracked in Git

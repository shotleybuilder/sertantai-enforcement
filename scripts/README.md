# EHS Enforcement Scripts Reference

Organized collection of helper scripts for development, deployment, data management, and operations.

## 📋 Quick Reference

### Most Common Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `development/ehs-dev.sh` | Start dev environment | `./scripts/development/ehs-dev.sh` |
| `data/airtable_import.sh` | Import from Airtable | `./scripts/data/airtable_import.sh dev --cases --limit 100` |
| `deployment/deploy-prod.sh` | Deploy to production | `./scripts/deployment/deploy-prod.sh --migrate --logs` |
| `ops/backup.sh` | Backup database | `./scripts/ops/backup.sh production` |

## 📁 Directory Structure

```
scripts/
├── README.md                  # This file
├── MIGRATION.md              # Migration guide for path changes
├── development/              # 🔧 Development environment scripts
│   ├── README.md
│   ├── ehs-dev.sh           # Start dev with Docker
│   ├── ehs-dev-no-docker.sh # Start dev without Docker
│   ├── start-dev.sh         # Quick start server
│   ├── docker-manual.sh     # Manual Docker management
│   └── setup_database.sh    # Database setup helper
├── data/                     # 📊 Data management scripts
│   ├── README.md
│   ├── airtable_import.sh   # Import from Airtable
│   ├── airtable_sync.sh     # Sync with Airtable
│   ├── import*.exs          # Various import scripts
│   ├── clean*.exs           # Database cleaning scripts
│   ├── fix_offender*.exs    # Data maintenance scripts
│   └── verify_import.exs    # Verification scripts
├── deployment/               # 🚀 Deployment automation
│   ├── README.md
│   ├── build.sh             # Build Docker image
│   ├── push.sh              # Push to GHCR
│   ├── deploy-prod.sh       # Deploy to production
│   └── test-container.sh    # Test container locally
├── ops/                      # ⚙️  Operations scripts
│   ├── README.md
│   ├── backup.sh            # Database backup/restore
│   ├── update.sh            # Update from git
│   └── monitor.sh           # Health monitoring
├── setup/                    # 🛠️  One-time setup
│   ├── README.md
│   └── install-git-hooks.sh # Install Git hooks
├── config/                   # ⚙️  Configuration tests
│   └── [test scripts]
└── legacy/                   # ⚠️  Deprecated scripts
    ├── DEPRECATED.md
    └── deploy.sh            # Old deployment (don't use)
```

## 🔧 Development Scripts

**Directory**: `scripts/development/`

Scripts for local development environment setup and management.

**See**: [development/README.md](development/README.md) for complete documentation

### Quick Start

```bash
# Start development environment with Docker
./scripts/development/ehs-dev.sh

# Or without Docker
./scripts/development/ehs-dev-no-docker.sh

# Quick server start (if DB already running)
./scripts/development/start-dev.sh
```

### Available Scripts

- **ehs-dev.sh** - Complete dev setup with Docker PostgreSQL
- **ehs-dev-no-docker.sh** - Dev setup with local PostgreSQL
- **start-dev.sh** - Quick Phoenix server start
- **docker-manual.sh** - Manual Docker container management
- **setup_database.sh** - Database setup and connectivity check

---

## 📊 Data Management Scripts

**Directory**: `scripts/data/`

Scripts for importing, cleaning, and maintaining data.

**See**: [data/README.md](data/README.md) for complete documentation

### Quick Start

```bash
# Import sample cases from Airtable
./scripts/data/airtable_import.sh dev --cases --limit 100

# Verify imported data
mix run scripts/data/verify_import.exs

# Clean database (dev only!)
mix run scripts/data/clean_dev_db.exs
```

### Categories

**Import Scripts**:
- `airtable_import.sh` - Import from Airtable
- `airtable_sync.sh` - Bidirectional sync
- `import_1000_cases.exs` - Test data import
- `import_1000_notices.exs` - Notice test data

**Cleaning Scripts**:
- `clean_dev_db.exs` - Clean database
- `clean_and_import_notices.exs` - Clean and reimport notices
- `clean_and_reimport.exs` - Complete reset

**Maintenance Scripts**:
- `fix_offender_names.exs` - Fix name formatting
- `update_offender_fields.exs` - Bulk updates
- `cleanup_legislation_duplicates.exs` - Remove duplicates
- `setup_agencies.exs` - Initialize agencies

**Verification**:
- `verify_import.exs` - Verify data integrity
- `test_notice_import.exs` - Test imports

---

## 🚀 Deployment Scripts

**Directory**: `scripts/deployment/`

Scripts for building and deploying to production.

**See**: [deployment/README.md](deployment/README.md) for complete documentation

### Deployment Workflow

```bash
# 1. Build Docker image
./scripts/deployment/build.sh

# 2. Push to GitHub Container Registry
./scripts/deployment/push.sh

# 3. Deploy to production
./scripts/deployment/deploy-prod.sh --migrate --logs

# Optional: Test locally first
./scripts/deployment/test-container.sh
```

### Available Scripts

- **build.sh** - Build production Docker image
- **push.sh** - Push image to GHCR
- **deploy-prod.sh** - Deploy to production server (sertantai)
- **test-container.sh** - Test container locally

**Production Details**:
- Server: sertantai (Digital Ocean)
- URL: https://legal.sertantai.com
- Container: ehs_enforcement_app
- Port: 4002 (internal, proxied by nginx)

---

## ⚙️ Operations Scripts

**Directory**: `scripts/ops/`

Scripts for monitoring, backup, and operational maintenance.

**See**: [ops/README.md](ops/README.md) for complete documentation

### Quick Start

```bash
# Backup production database
./scripts/ops/backup.sh production

# Monitor application health
./scripts/ops/monitor.sh production

# Update from git
./scripts/ops/update.sh production
```

### Available Scripts

- **backup.sh** - Create/restore database backups
- **monitor.sh** - Health monitoring and alerts
- **update.sh** - Update from git with safety checks

### Common Operations

```bash
# Pre-deployment: Backup
./scripts/ops/backup.sh production

# Deploy (see deployment/)
./scripts/deployment/deploy-prod.sh --migrate

# Post-deployment: Monitor
./scripts/ops/monitor.sh production --continuous
```

---

## 🛠️ Setup Scripts

**Directory**: `scripts/setup/`

One-time setup scripts for project initialization.

**See**: [setup/README.md](setup/README.md) for complete documentation

### Initial Setup

```bash
# After cloning repository
./scripts/setup/install-git-hooks.sh
```

### Available Scripts

- **install-git-hooks.sh** - Install pre-commit and post-commit hooks

**Git Hooks**:
- Pre-commit: Code formatting and linting checks
- Post-commit: ExDoc generation when needed

---

## ⚙️ Configuration Scripts

**Directory**: `scripts/config/`

Test scripts for configuration system validation.

**⚠️ Note**: These are test scripts, not proper ExUnit tests. Use for manual validation only. Prefer proper tests in `test/` directory.

### Available Scripts

```bash
mix run scripts/config/feature_flags_test.exs
mix run scripts/config/config_integration_test.exs
mix run scripts/config/settings_test.exs
mix run scripts/config/validator_test.exs
mix run scripts/config/environment_test.exs
mix run scripts/config/config_manager_test.exs
```

---

## ⚠️ Legacy Scripts

**Directory**: `scripts/legacy/`

**WARNING**: These scripts are deprecated and kept for reference only.

**See**: [legacy/DEPRECATED.md](legacy/DEPRECATED.md) for details

- **deploy.sh** - Old docker-compose deployment (superseded by `deployment/` scripts)

**Use modern alternatives in `scripts/deployment/` instead!**

---

## 🚀 Common Workflows

### Daily Development

```bash
# 1. Start dev environment
./scripts/development/ehs-dev.sh

# 2. Import test data (optional)
./scripts/data/airtable_import.sh dev --cases --limit 50

# 3. Make changes, test, commit
git add . && git commit -m "feat: ..."

# 4. Push
git push
```

### Testing with Data

```bash
# 1. Clean database
mix run scripts/data/clean_dev_db.exs

# 2. Import substantial data
./scripts/data/airtable_import.sh dev --full --limit 1000

# 3. Verify import
mix run scripts/data/verify_import.exs

# 4. Test your feature
mix test
```

### Deployment to Production

```bash
# 1. Build and test locally
./scripts/deployment/build.sh
./scripts/deployment/test-container.sh

# 2. Push to registry
./scripts/deployment/push.sh

# 3. Backup production
./scripts/ops/backup.sh production

# 4. Deploy
./scripts/deployment/deploy-prod.sh --migrate --logs

# 5. Monitor
./scripts/ops/monitor.sh production
```

### Maintenance Tasks

```bash
# Backup database
./scripts/ops/backup.sh production

# Fix data issues
mix run scripts/data/fix_offender_names.exs
mix run scripts/data/cleanup_legislation_duplicates.exs

# Sync with Airtable
./scripts/data/airtable_sync.sh production --incremental

# Monitor health
./scripts/ops/monitor.sh production
```

---

## 📝 Script Usage Tips

### Making Scripts Executable

```bash
# Make all scripts executable
find scripts -name "*.sh" -exec chmod +x {} \;
```

### Getting Help

Most scripts support `--help`:

```bash
./scripts/deployment/deploy-prod.sh --help
./scripts/data/airtable_import.sh --help
./scripts/ops/backup.sh --help
```

### Environment Variables

Scripts may require environment variables:

```bash
# Create .env file
AT_UK_E_API_KEY=your_key
DATABASE_URL=postgresql://...

# Load variables
source .env

# Run script
./scripts/data/airtable_import.sh dev --cases
```

### Running Elixir Scripts

```bash
# Standard way
mix run scripts/data/script_name.exs

# In IEx for debugging
iex -S mix
iex> Code.eval_file("scripts/data/script_name.exs")
```

---

## 🔄 Migration Notes

**Path Changes**: Scripts have been reorganized into category directories.

**See**: [MIGRATION.md](MIGRATION.md) for complete migration guide

### Quick Migration Guide

**Old paths** → **New paths**:

```bash
# Development
scripts/ehs-dev.sh           → scripts/development/ehs-dev.sh
scripts/start-dev.sh         → scripts/development/start-dev.sh

# Data
scripts/airtable_import.sh   → scripts/data/airtable_import.sh
scripts/clean_dev_db.exs     → scripts/data/clean_dev_db.exs

# Operations
scripts/backup.sh            → scripts/ops/backup.sh
scripts/monitor.sh           → scripts/ops/monitor.sh

# Setup
scripts/install-git-hooks.sh → scripts/setup/install-git-hooks.sh

# Deprecated
scripts/deploy.sh            → scripts/legacy/deploy.sh (deprecated)
```

**Action Required**: Update any automation or documentation that references old paths.

---

## 📚 Related Documentation

### Developer Guides

- **[docs-dev/GETTING_STARTED.md](../docs-dev/GETTING_STARTED.md)** - Initial setup
- **[docs-dev/DEVELOPMENT_WORKFLOW.md](../docs-dev/DEVELOPMENT_WORKFLOW.md)** - Development workflow
- **[docs-dev/TESTING_GUIDE.md](../docs-dev/TESTING_GUIDE.md)** - Testing practices
- **[docs-dev/TROUBLESHOOTING.md](../docs-dev/TROUBLESHOOTING.md)** - Common issues

### Script-Specific Docs

Each script directory has detailed documentation:

- [development/README.md](development/README.md) - Development scripts
- [data/README.md](data/README.md) - Data management scripts
- [deployment/README.md](deployment/README.md) - Deployment scripts
- [ops/README.md](ops/README.md) - Operations scripts
- [setup/README.md](setup/README.md) - Setup scripts
- [legacy/DEPRECATED.md](legacy/DEPRECATED.md) - Deprecated scripts

---

## 🆘 Troubleshooting

### Script Won't Run

```bash
# Check permissions
ls -la scripts/development/ehs-dev.sh

# Make executable
chmod +x scripts/development/ehs-dev.sh
```

### Path Errors

```bash
# If you get "No such file or directory"
# Scripts may have moved - check MIGRATION.md

# Update your paths
./scripts/development/ehs-dev.sh  # NEW
# instead of
./scripts/ehs-dev.sh              # OLD
```

### Environment Issues

```bash
# Check environment variables
echo $AT_UK_E_API_KEY

# Source .env file
source .env

# Verify database connection
./scripts/development/setup_database.sh
```

---

## 🎯 Script Development

### Adding New Scripts

1. **Choose appropriate directory**: development/, data/, ops/, setup/
2. **Add header comment**: Purpose, usage, options
3. **Include error handling**: Input validation, error messages
4. **Make idempotent**: Safe to run multiple times
5. **Test in dev first**: Never test untested scripts in production
6. **Update README**: Add to category README and this file

### Example Script Header

```bash
#!/bin/bash
# Script Name and Purpose
# Usage: ./scripts/category/script_name.sh [options]
#
# Options:
#   --option1    Description
#   --option2    Description
#
# Examples:
#   ./scripts/category/script_name.sh --option1
```

---

**Last Updated**: 2025-10-16
**Reorganization Date**: 2025-10-16

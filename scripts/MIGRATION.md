# Scripts Reorganization - Migration Guide

**Date**: 2025-10-16

Scripts have been reorganized into category-specific directories for better organization and discoverability.

## Summary of Changes

### What Changed

- **27 scripts** moved from `scripts/` root to organized subdirectories
- New directory structure: `development/`, `data/`, `ops/`, `setup/`, `legacy/`
- `deploy.sh` deprecated in favor of `deployment/` workflow
- Each directory now has its own README with detailed documentation

### Why This Change

1. **Better Organization**: Scripts grouped by purpose
2. **Easier Discovery**: Find scripts by category
3. **Scalability**: Clear place for new scripts
4. **Consistency**: Matches existing `deployment/` and `config/` structure
5. **Clarity**: Reduced root directory clutter

---

## Path Migration Table

### Development Scripts

| Old Path | New Path | Status |
|----------|----------|--------|
| `scripts/ehs-dev.sh` | `scripts/development/ehs-dev.sh` | ✅ Moved |
| `scripts/ehs-dev-no-docker.sh` | `scripts/development/ehs-dev-no-docker.sh` | ✅ Moved |
| `scripts/start-dev.sh` | `scripts/development/start-dev.sh` | ✅ Moved |
| `scripts/docker-manual.sh` | `scripts/development/docker-manual.sh` | ✅ Moved |
| `scripts/setup_database.sh` | `scripts/development/setup_database.sh` | ✅ Moved |

### Data Management Scripts

| Old Path | New Path | Status |
|----------|----------|--------|
| `scripts/airtable_import.sh` | `scripts/data/airtable_import.sh` | ✅ Moved |
| `scripts/airtable_sync.sh` | `scripts/data/airtable_sync.sh` | ✅ Moved |
| `scripts/import.exs` | `scripts/data/import.exs` | ✅ Moved |
| `scripts/import_1000_cases.exs` | `scripts/data/import_1000_cases.exs` | ✅ Moved |
| `scripts/import_1000_notices.exs` | `scripts/data/import_1000_notices.exs` | ✅ Moved |
| `scripts/import_1000_records.exs` | `scripts/data/import_1000_records.exs` | ✅ Moved |
| `scripts/clean_and_import_notices.exs` | `scripts/data/clean_and_import_notices.exs` | ✅ Moved |
| `scripts/clean_and_reimport.exs` | `scripts/data/clean_and_reimport.exs` | ✅ Moved |
| `scripts/clean_dev_db.exs` | `scripts/data/clean_dev_db.exs` | ✅ Moved |
| `scripts/test_notice_import.exs` | `scripts/data/test_notice_import.exs` | ✅ Moved |
| `scripts/verify_import.exs` | `scripts/data/verify_import.exs` | ✅ Moved |
| `scripts/fix_offender_names.exs` | `scripts/data/fix_offender_names.exs` | ✅ Moved |
| `scripts/fix_offender_names_simple.exs` | `scripts/data/fix_offender_names_simple.exs` | ✅ Moved |
| `scripts/update_offender_fields.exs` | `scripts/data/update_offender_fields.exs` | ✅ Moved |
| `scripts/cleanup_legislation_duplicates.exs` | `scripts/data/cleanup_legislation_duplicates.exs` | ✅ Moved |
| `scripts/setup_agencies.exs` | `scripts/data/setup_agencies.exs` | ✅ Moved |
| `scripts/offender.exs` | `scripts/data/offender.exs` | ✅ Moved |

### Operations Scripts

| Old Path | New Path | Status |
|----------|----------|--------|
| `scripts/backup.sh` | `scripts/ops/backup.sh` | ✅ Moved |
| `scripts/monitor.sh` | `scripts/ops/monitor.sh` | ✅ Moved |
| `scripts/update.sh` | `scripts/ops/update.sh` | ✅ Moved |

### Setup Scripts

| Old Path | New Path | Status |
|----------|----------|--------|
| `scripts/install-git-hooks.sh` | `scripts/setup/install-git-hooks.sh` | ✅ Moved |

### Deprecated Scripts

| Old Path | New Path | Status |
|----------|----------|--------|
| `scripts/deploy.sh` | `scripts/legacy/deploy.sh` | ⚠️ DEPRECATED |

**Note**: `deploy.sh` is deprecated. Use `scripts/deployment/deploy-prod.sh` instead.

---

## Action Items for Developers

### 1. Update Your Workflows

If you have **aliases** or **shortcuts**:

```bash
# OLD
alias dev-start="./scripts/ehs-dev.sh"

# NEW
alias dev-start="./scripts/development/ehs-dev.sh"
```

### 2. Update Documentation

If you maintain **personal notes** or **team docs** that reference scripts:

- Search for `scripts/` paths
- Update to new directory structure
- Check any README files you've written

### 3. Update Automation

If you have **CI/CD** or **automation** that runs scripts:

```yaml
# OLD
- run: ./scripts/backup.sh production

# NEW
- run: ./scripts/ops/backup.sh production
```

### 4. Update Git Hooks

If you reference scripts in **custom Git hooks**:

```bash
# OLD
./scripts/airtable_import.sh dev --cases

# NEW
./scripts/data/airtable_import.sh dev --cases
```

### 5. Check Cron Jobs

If you have **cron jobs** running scripts:

```bash
# OLD
0 2 * * * /path/to/scripts/backup.sh production

# NEW
0 2 * * * /path/to/scripts/ops/backup.sh production
```

---

## Quick Find and Replace

Use these commands to update references in your local files:

```bash
# Find references to old paths
grep -r "scripts/ehs-dev.sh" .
grep -r "scripts/airtable_import.sh" .
grep -r "scripts/backup.sh" .

# Find all script references
grep -r "scripts/[^/]*.sh" . --include="*.md" --include="*.sh" --include="*.yml"
```

---

## Backward Compatibility

### Git Tracking

All moves were done with `git mv` to preserve history. You can track a file's history through the move:

```bash
# View history of moved file
git log --follow scripts/development/ehs-dev.sh

# See the move commit
git log --all --oneline -- scripts/ehs-dev.sh
```

### Symlinks (Optional)

If you need temporary backward compatibility, you could create symlinks:

```bash
# Create symlink (not recommended long-term)
ln -s development/ehs-dev.sh scripts/ehs-dev.sh

# Better: Update your workflows
```

**Note**: We do NOT recommend creating symlinks. Update to new paths instead.

---

## Testing Your Updates

After updating your workflows:

### 1. Test Development Scripts

```bash
# Try starting dev environment
./scripts/development/ehs-dev.sh

# Should work without errors
```

### 2. Test Data Scripts

```bash
# Try importing data
./scripts/data/airtable_import.sh dev --cases --limit 10

# Should work without errors
```

### 3. Test Your Automation

```bash
# Run your CI/CD locally if possible
# Check cron jobs are updated
# Verify aliases work
```

---

## Help and Support

### Common Issues

**Problem**: Script not found
```bash
# Error
./scripts/ehs-dev.sh: No such file or directory

# Solution
./scripts/development/ehs-dev.sh
```

**Problem**: Permission denied
```bash
# Error
Permission denied: ./scripts/development/ehs-dev.sh

# Solution
chmod +x scripts/development/ehs-dev.sh
```

**Problem**: Old path in documentation
```bash
# Search for old references
grep -r "scripts/ehs-dev.sh" docs/

# Update to new path
# scripts/development/ehs-dev.sh
```

### Getting More Information

- **Overview**: [scripts/README.md](README.md)
- **Development Scripts**: [development/README.md](development/README.md)
- **Data Scripts**: [data/README.md](data/README.md)
- **Deployment Scripts**: [deployment/README.md](deployment/README.md)
- **Operations Scripts**: [ops/README.md](ops/README.md)
- **Setup Scripts**: [setup/README.md](setup/README.md)

### Questions?

If you have questions about the reorganization:

1. Check the README in each directory
2. Review this migration guide
3. Search for the script name in `scripts/README.md`
4. Ask the team

---

## Rollback Plan

If critical issues arise, we can temporarily revert:

```bash
# Check reorganization commit
git log --all --oneline --grep="reorganize scripts"

# Revert if absolutely necessary (NOT RECOMMENDED)
# git revert <commit-hash>

# Better: Fix the specific issue
```

**Note**: Rollback is not recommended. Instead, fix specific issues as they arise.

---

## Timeline

- **2025-10-16**: Scripts reorganized
- **2025-10-17**: Update period (developers update workflows)
- **2025-10-24**: Review period ends
- **Ongoing**: New structure is standard

---

## Benefits of New Structure

✅ **Better Organization**: Scripts grouped by purpose
✅ **Easier Discovery**: Find scripts in logical categories
✅ **Improved Documentation**: Each category has detailed README
✅ **Scalability**: Clear place for new scripts
✅ **Consistency**: Matches existing directory patterns
✅ **Reduced Clutter**: Root directory clean
✅ **Clear Deprecation**: Legacy scripts clearly marked

---

## New Directory Structure

```
scripts/
├── README.md                  # Main scripts documentation
├── MIGRATION.md              # This file
├── development/              # Development environment (5 scripts)
│   ├── README.md
│   ├── ehs-dev.sh
│   ├── ehs-dev-no-docker.sh
│   ├── start-dev.sh
│   ├── docker-manual.sh
│   └── setup_database.sh
├── data/                     # Data management (16 scripts)
│   ├── README.md
│   ├── airtable_import.sh
│   ├── airtable_sync.sh
│   ├── import*.exs
│   ├── clean*.exs
│   ├── fix*.exs
│   └── [other data scripts]
├── ops/                      # Operations (3 scripts)
│   ├── README.md
│   ├── backup.sh
│   ├── monitor.sh
│   └── update.sh
├── setup/                    # Setup (1 script)
│   ├── README.md
│   └── install-git-hooks.sh
├── deployment/               # Deployment (4 scripts) [unchanged]
│   ├── README.md
│   ├── build.sh
│   ├── push.sh
│   ├── deploy-prod.sh
│   └── test-container.sh
├── config/                   # Config tests [unchanged]
│   └── [test scripts]
└── legacy/                   # Deprecated scripts
    ├── DEPRECATED.md
    └── deploy.sh             # DON'T USE
```

---

**Questions or Issues?** Check [scripts/README.md](README.md) or ask the team.

**Last Updated**: 2025-10-16

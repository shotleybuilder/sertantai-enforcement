# Data Management Scripts

Scripts for importing, cleaning, and maintaining data from Airtable and other sources.

## Quick Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `airtable_import.sh` | Import from Airtable | `./airtable_import.sh dev --cases --limit 100` |
| `airtable_sync.sh` | Sync with Airtable | `./airtable_sync.sh dev --incremental` |
| `clean_dev_db.exs` | Clean database | `mix run clean_dev_db.exs` |
| `verify_import.exs` | Verify data integrity | `mix run verify_import.exs` |

## Script Categories

### Import Scripts

#### airtable_import.sh

**Import data from Airtable to PostgreSQL**

```bash
./scripts/data/airtable_import.sh [environment] [--full|--cases|--notices] [--limit N]

# Examples:
./scripts/data/airtable_import.sh dev --cases --limit 100
./scripts/data/airtable_import.sh dev --notices --limit 50
./scripts/data/airtable_import.sh dev --full
```

**Options:**
- `environment`: dev, test, or production
- `--full`: Import both cases and notices
- `--cases`: Import cases only
- `--notices`: Import notices only
- `--limit N`: Limit to N records

---

#### airtable_sync.sh

**Bidirectional sync with Airtable**

```bash
./scripts/data/airtable_sync.sh [environment] [--incremental|--full] [--schedule]

# Examples:
./scripts/data/airtable_sync.sh dev --incremental
./scripts/data/airtable_sync.sh production --full
```

**Options:**
- `--incremental`: Sync only recent changes
- `--full`: Full resync
- `--schedule`: Set up automatic syncing

---

#### import_1000_cases.exs

**Import 1000 cases for testing**

```bash
mix run scripts/data/import_1000_cases.exs
```

**Use case**: Load substantial test data for development/testing

---

#### import_1000_notices.exs

**Import 1000 notices for testing**

```bash
mix run scripts/data/import_1000_notices.exs
```

---

#### import_1000_records.exs

**Import mixed records for testing**

```bash
mix run scripts/data/import_1000_records.exs
```

---

#### import.exs

**General purpose import script**

```bash
mix run scripts/data/import.exs
```

---

### Cleaning Scripts

#### clean_dev_db.exs

**Clean development database**

```bash
mix run scripts/data/clean_dev_db.exs
```

**⚠️ Warning**: Deletes all records! Development only.

**What it does:**
- Removes all records from database
- Preserves schema
- Resets sequences

---

#### clean_and_import_notices.exs

**Clean and reimport notices**

```bash
mix run scripts/data/clean_and_import_notices.exs
```

**⚠️ Warning**: Deletes existing notice data!

---

#### clean_and_reimport.exs

**Clean and reimport all data**

```bash
mix run scripts/data/clean_and_reimport.exs
```

**⚠️ Warning**: Deletes ALL data!

**Use case**: Complete fresh start, major schema changes

---

### Data Maintenance Scripts

#### fix_offender_names.exs

**Fix offender name formatting**

```bash
mix run scripts/data/fix_offender_names.exs
```

**What it does:**
- Standardizes offender names
- Fixes encoding issues
- Cleans up formatting

---

#### fix_offender_names_simple.exs

**Simple offender name fixes**

```bash
mix run scripts/data/fix_offender_names_simple.exs
```

**What it does:**
- Basic name cleaning
- Faster than full fix
- Common issues only

---

#### update_offender_fields.exs

**Bulk update offender fields**

```bash
mix run scripts/data/update_offender_fields.exs
```

**Use case**: Bulk field updates, data migration

---

#### cleanup_legislation_duplicates.exs

**Remove duplicate legislation**

```bash
mix run scripts/data/cleanup_legislation_duplicates.exs
```

**What it does:**
- Identifies duplicate legislation entries
- Merges or removes duplicates
- Preserves references

**Documentation**: See `docs-dev/dev/legislation_deduplication_guide.md`

---

#### setup_agencies.exs

**Initialize agency data**

```bash
mix run scripts/data/setup_agencies.exs
```

**What it does:**
- Creates initial agencies (HSE, EA, etc.)
- Sets up agency metadata
- One-time setup

---

#### offender.exs

**Offender data utilities**

```bash
mix run scripts/data/offender.exs
```

---

### Verification Scripts

#### verify_import.exs

**Verify imported data integrity**

```bash
mix run scripts/data/verify_import.exs
```

**What it does:**
- Checks data consistency
- Validates relationships
- Reports issues

---

#### test_notice_import.exs

**Test notice import functionality**

```bash
mix run scripts/data/test_notice_import.exs
```

---

## Common Workflows

### Initial Data Setup

```bash
# 1. Import sample data
./scripts/data/airtable_import.sh dev --cases --limit 100

# 2. Verify import
mix run scripts/data/verify_import.exs

# 3. Setup agencies
mix run scripts/data/setup_agencies.exs
```

### Testing with Production-like Data

```bash
# 1. Clean database
mix run scripts/data/clean_dev_db.exs

# 2. Import substantial data
./scripts/data/airtable_import.sh dev --full --limit 1000

# 3. Verify
mix run scripts/data/verify_import.exs
```

### Data Maintenance

```bash
# Fix offender names
mix run scripts/data/fix_offender_names.exs

# Clean up duplicates
mix run scripts/data/cleanup_legislation_duplicates.exs

# Sync with Airtable
./scripts/data/airtable_sync.sh dev --incremental
```

### Fresh Start

```bash
# Nuclear option - complete fresh start
mix run scripts/data/clean_and_reimport.exs

# Or step by step
mix run scripts/data/clean_dev_db.exs
./scripts/data/airtable_import.sh dev --full --limit 500
mix run scripts/data/verify_import.exs
```

---

## Environment Variables

Required for Airtable scripts:

```bash
# Set in .env file
AT_UK_E_API_KEY=your_airtable_api_key

# Load variables
source .env
```

---

## Safety Notes

**⚠️ Production Safety:**
- Always backup before running maintenance scripts in production
- Test scripts in development first
- Verify imports before syncing to production
- Use `--limit` flag when testing imports

**⚠️ Destructive Operations:**
Scripts that delete data:
- `clean_dev_db.exs`
- `clean_and_reimport.exs`
- `clean_and_import_notices.exs`

**Always run these in development only!**

---

## Troubleshooting

### Import Failures

```bash
# Verify Airtable key
echo $AT_UK_E_API_KEY

# Test with small limit
./scripts/data/airtable_import.sh dev --cases --limit 10

# Check logs
tail -f log/dev.log
```

### Database Errors

```bash
# Reset database
mix ecto.reset

# Verify connection
./scripts/development/setup_database.sh
```

---

## Related Documentation

- **[docs-dev/DEVELOPMENT_WORKFLOW.md](../../docs-dev/DEVELOPMENT_WORKFLOW.md)** - Development workflow
- **[docs-dev/TROUBLESHOOTING.md](../../docs-dev/TROUBLESHOOTING.md)** - Common issues
- **[docs-dev/dev/airtable_import_human_workflow.md](../../docs-dev/dev/airtable_import_human_workflow.md)** - Import workflow details

---

**Parent README**: [scripts/README.md](../README.md)

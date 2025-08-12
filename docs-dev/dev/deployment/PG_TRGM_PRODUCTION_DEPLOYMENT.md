# PostgreSQL pg_trgm Extension - Production Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the pg_trgm extension and associated fuzzy text search functionality to production environments.

**⚠️ CRITICAL**: These steps must be followed in order to avoid database downtime and ensure proper functionality.

## Prerequisites

- PostgreSQL 12+ (pg_trgm included by default)
- Database administrator access in production
- Application deployment pipeline access

## Production Deployment Steps

### 1. Database Extension Installation

**⚠️ IMPORTANT**: Install the extension BEFORE deploying application code changes.

#### Option A: Via Database Administrator (Recommended)
```bash
docker compose exec postgres psql -U postgres -d ehs_enforcement_prod
```

The \c command is for switching databases once you'realready in the PostgreSQL prompt

```sql
-- Install pg_trgm extension
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Verify installation
SELECT name, default_version, installed_version
FROM pg_available_extensions
WHERE name = 'pg_trgm';

-- Test trigram functionality
SELECT similarity('construction', 'construktion');

-- Quit PostgreSQL prompt
\q
```

#### Option B: Via Application Migration (Alternative)
If your production database user has CREATE EXTENSION privileges:
```bash
# Deploy the application with pg_trgm migration
mix ash.migrate
```

### 2. Verify Extension Installation

Before proceeding, confirm pg_trgm is installed:
```sql
-- Check extension is installed
SELECT extname FROM pg_extension WHERE extname = 'pg_trgm';

-- Test trigram functionality
SELECT similarity('construction', 'construktion');
-- Should return a value between 0 and 1
```

### 3. Deploy GIN Indexes

The application migrations will create the necessary GIN indexes:

```bash
# Deploy application with index creation
mix ash.migrate
```

**Expected indexes to be created:**
- `cases_regulator_id_gin_trgm`
- `cases_offence_breaches_gin_trgm`
- `notices_regulator_id_gin_trgm`
- `notices_offence_breaches_gin_trgm`
- `notices_notice_body_gin_trgm`
- `offenders_name_gin_trgm`
- `offenders_normalized_name_gin_trgm`
- `offenders_local_authority_gin_trgm`
- `offenders_main_activity_gin_trgm`
- `offenders_postcode_gin_trgm`

### 4. Verify Index Creation

```sql
-- Check all pg_trgm GIN indexes were created
SELECT indexname, indexdef
FROM pg_indexes
WHERE indexname LIKE '%gin_trgm'
ORDER BY indexname;
```

### 5. Performance Optimization (Recommended)

For production databases with large datasets, consider these optimizations:

#### A. Index Creation with CONCURRENTLY (If needed)
If the initial migration takes too long, you can recreate indexes concurrently:

```sql
-- Drop existing indexes (if needed)
DROP INDEX IF EXISTS cases_regulator_id_gin_trgm;

-- Recreate with CONCURRENTLY (no table locks)
CREATE INDEX CONCURRENTLY cases_regulator_id_gin_trgm
ON cases USING GIN (regulator_id gin_trgm_ops);
```

#### B. Adjust pg_trgm Configuration
For better performance with your data patterns:

```sql
-- Check current similarity threshold (default: 0.3)
SHOW pg_trgm.similarity_threshold;

-- Optionally adjust threshold (session-level)
SET pg_trgm.similarity_threshold = 0.2;  -- More permissive
```

### 6. Deploy Application Code

Deploy the application code with fuzzy search functionality:

```bash
# Deploy latest application version with pg_trgm features
# Follow your standard deployment procedure
```

### 7. Test Fuzzy Search Functionality

After deployment, test the new functionality:

```bash
# Test via IEx console
iex -S mix

# Test fuzzy search functions
{:ok, results} = EhsEnforcement.Enforcement.fuzzy_search_cases("construction", limit: 5)
{:ok, results} = EhsEnforcement.Enforcement.fuzzy_search_offenders("acme", limit: 5)
{:ok, results} = EhsEnforcement.Enforcement.fuzzy_search_notices("safety", limit: 5)
```

Test via web interface:
1. Navigate to `/cases` page
2. Enter search term in search field
3. Toggle "Fuzzy search" checkbox
4. Verify results include similar matches (e.g., "construction" finds "constrution")

## Performance Monitoring

### Index Usage Monitoring
```sql
-- Monitor index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE indexname LIKE '%gin_trgm%'
ORDER BY idx_scan DESC;
```

### Query Performance Monitoring
```sql
-- Enable query logging for pg_trgm queries (temporarily)
SET log_min_duration_statement = 100;  -- Log queries > 100ms

-- Monitor slow queries involving trigram similarity
SELECT query, mean_exec_time, calls, rows, 100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements
WHERE query ILIKE '%trigram_similarity%'
ORDER BY mean_exec_time DESC;
```

## Troubleshooting

### Extension Not Available
```bash
# If pg_trgm not found, install contrib package
sudo apt-get install postgresql-contrib  # Ubuntu/Debian
sudo yum install postgresql-contrib       # CentOS/RHEL
```

### Permission Issues
```sql
-- If CREATE EXTENSION fails due to permissions
GRANT CREATE ON SCHEMA public TO your_app_user;
-- Or have DBA install extension as superuser
```

### Index Creation Failures
```sql
-- If index creation fails, check for:
-- 1. Insufficient disk space
SELECT pg_size_pretty(pg_database_size(current_database()));

-- 2. Lock conflicts (retry during low traffic)
-- 3. Memory issues (adjust work_mem temporarily)
SET work_mem = '256MB';  -- Increase for index creation
```

### Performance Issues
- If queries are slow, verify indexes are being used with `EXPLAIN ANALYZE`
- Consider adjusting `similarity_threshold` in application code
- Monitor `shared_buffers` and consider increasing for better cache hit ratio

## Rollback Procedure

If issues arise, you can rollback:

```sql
-- 1. Drop GIN indexes
DROP INDEX IF EXISTS cases_regulator_id_gin_trgm;
DROP INDEX IF EXISTS cases_offence_breaches_gin_trgm;
-- ... (drop all gin_trgm indexes)

-- 2. Remove extension (if safe to do so)
DROP EXTENSION IF EXISTS pg_trgm;
```

**⚠️ WARNING**: Only remove the extension if no other applications use it.

## Post-Deployment Verification

1. **Functionality Test**: Confirm fuzzy search works as expected
2. **Performance Test**: Compare search performance before/after
3. **Error Monitoring**: Watch for any pg_trgm related errors
4. **Index Usage**: Verify indexes are being utilized
5. **Resource Usage**: Monitor CPU and I/O impact

## Monitoring and Maintenance

- **Weekly**: Review index usage statistics
- **Monthly**: Check query performance trends
- **Quarterly**: Consider similarity threshold adjustments based on usage patterns

---

**Implementation Date**: 2025-08-12
**Document Version**: 1.0
**Contact**: Development Team for questions or issues

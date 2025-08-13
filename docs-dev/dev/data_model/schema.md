# Database Schema Documentation

This document provides comprehensive schema documentation for the EHS Enforcement application database, based on current Ash resources and PostgreSQL migrations.

## Overview

The EHS Enforcement application uses PostgreSQL as its primary database with Ash Framework resources that manage schema and data operations. The schema is organized into several domains:

- **Accounts** - User authentication and session management
- **Enforcement** - Core enforcement data (cases, notices, agencies, offenders)
- **Configuration** - Application configuration and scraping settings
- **Sync** - Data synchronization tracking
- **Events** - Event sourcing and audit trails

## Schema Summary

| Table | Primary Key | Records Type | Domain |
|-------|-------------|--------------|--------|
| `users` | `id` (uuid) | User accounts | Accounts |
| `user_identities` | `id` (uuid) | OAuth identities | Accounts |
| `tokens` | `jti` (text) | Auth tokens | Accounts |
| `agencies` | `id` (uuid) | Enforcement agencies | Enforcement |
| `offenders` | `id` (uuid) | Companies/individuals | Enforcement |
| `cases` | `id` (uuid) | Court cases | Enforcement |
| `notices` | `id` (uuid) | Enforcement notices | Enforcement |
| `breaches` | `id` (uuid) | Legislation breaches | Enforcement |
| `scraping_configs` | `id` (uuid) | Scraping configuration | Configuration |
| `sync_logs` | `id` (uuid) | Sync operation logs | Sync |
| `events` | `id` (bigserial) | Event sourcing | Events |

---

## Accounts Domain

### `users` Table

**Purpose**: Core user accounts with GitHub OAuth authentication and admin privileges.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | PRIMARY KEY, NOT NULL | Unique user identifier |
| `email` | `citext` | NOT NULL, UNIQUE | User email address (case-insensitive) |
| `github_id` | `text` | NULLABLE | GitHub user ID from OAuth |
| `github_login` | `text` | NULLABLE | GitHub username |
| `name` | `text` | NULLABLE | User's display name |
| `avatar_url` | `text` | NULLABLE | GitHub avatar URL |
| `github_url` | `text` | NULLABLE | GitHub profile URL |
| `is_admin` | `boolean` | NOT NULL, DEFAULT false | Admin privilege flag |
| `admin_checked_at` | `timestamp` | NULLABLE | Last admin status check |
| `last_login_at` | `timestamp` | NULLABLE | Last login timestamp |
| `primary_provider` | `text` | NOT NULL, DEFAULT 'github' | OAuth provider |
| `inserted_at` | `timestamp` | NOT NULL | Record creation time |
| `updated_at` | `timestamp` | NOT NULL | Record update time |

**Indexes**:
- `users_unique_email_index` (UNIQUE on `email`)
- Index on `github_id`
- Index on `github_login`
- Index on `is_admin`

**Ash Identity**: `unique_email` on `[:email]`

---

### `user_identities` Table

**Purpose**: OAuth provider identities linked to users (supports multiple providers per user).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | PRIMARY KEY, NOT NULL | Identity record ID |
| `user_id` | `uuid` | NOT NULL, FK → users.id | Associated user |
| `uid` | `text` | NOT NULL | Provider-specific user ID |
| `strategy` | `text` | NOT NULL | OAuth strategy (e.g., 'github') |
| `access_token` | `text` | NULLABLE | OAuth access token |
| `refresh_token` | `text` | NULLABLE | OAuth refresh token |
| `access_token_expires_at` | `timestamp` | NULLABLE | Token expiration |

**Indexes**:
- `user_identities_unique_on_strategy_and_uid_and_user_id_index` (UNIQUE on `[:strategy, :uid, :user_id]`)

**Foreign Keys**:
- `user_identities_user_id_fkey`: `user_id` → `users.id` (CASCADE DELETE)

---

### `tokens` Table

**Purpose**: Authentication tokens and session management.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `jti` | `text` | PRIMARY KEY, NOT NULL | JWT ID (unique identifier) |
| `subject` | `text` | NOT NULL | Token subject (usually user ID) |
| `purpose` | `text` | NOT NULL | Token purpose/type |
| `expires_at` | `timestamp` | NOT NULL | Token expiration time |
| `extra_data` | `jsonb` | NULLABLE | Additional token metadata |
| `created_at` | `timestamp` | NOT NULL | Token creation time |
| `updated_at` | `timestamp` | NOT NULL | Token update time |

**Indexes**:
- UNIQUE index on `jti`
- Index on `purpose`
- Index on `expires_at`

---

## Enforcement Domain

### `agencies` Table

**Purpose**: Enforcement agencies (HSE, ONR, ORR, EA, etc.) that issue cases and notices.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | PRIMARY KEY, NOT NULL | Agency unique identifier |
| `code` | `text` | NOT NULL, UNIQUE | Agency code (:hse, :onr, :orr, :ea) |
| `name` | `text` | NOT NULL | Agency full name |
| `base_url` | `text` | NULLABLE | Agency website base URL |
| `enabled` | `boolean` | NOT NULL, DEFAULT true | Whether agency is active |
| `inserted_at` | `timestamp` | NOT NULL | Record creation time |
| `updated_at` | `timestamp` | NOT NULL | Record update time |

**Indexes**:
- `agencies_unique_code_index` (UNIQUE on `code`)

**Ash Identity**: `unique_code` on `[:code]`

**Ash Constraints**: `code` must be one of `[:hse, :onr, :orr, :ea]`

**Relationships**:
- `has_many :cases` → `cases.agency_id`
- `has_many :notices` → `notices.agency_id`

---

### `offenders` Table

**Purpose**: Companies or individuals subject to enforcement actions (normalized to prevent duplication).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | PRIMARY KEY, NOT NULL | Offender unique identifier |
| `name` | `text` | NOT NULL | Original company/individual name |
| `normalized_name` | `text` | NULLABLE | Normalized name for matching |
| `address` | `text` | NULLABLE | Offender business address |
| `local_authority` | `text` | NULLABLE | Local authority area |
| `country` | `text` | NULLABLE | Country (England, Scotland, Wales, Northern Ireland) |
| `postcode` | `text` | NULLABLE | Postal code |
| `main_activity` | `text` | NULLABLE | Primary business activity |
| `sic_code` | `text` | NULLABLE | Standard Industrial Classification code |
| `business_type` | `text` | NULLABLE | Business structure type (atom: :limited_company, :individual, :partnership, :plc, :other) |
| `industry` | `text` | NULLABLE | Industry classification |
| `first_seen_date` | `date` | NULLABLE | First enforcement action date |
| `last_seen_date` | `date` | NULLABLE | Most recent enforcement date |
| `total_cases` | `integer` | NOT NULL, DEFAULT 0 | Total court cases count |
| `total_notices` | `integer` | NOT NULL, DEFAULT 0 | Total notices count |
| `total_fines` | `decimal` | NOT NULL, DEFAULT 0 | Total fine amounts |
| `inserted_at` | `timestamp` | NOT NULL | Record creation time |
| `updated_at` | `timestamp` | NOT NULL | Record update time |

**Indexes**:
- `offenders_unique_name_postcode_index` (UNIQUE on `[:normalized_name, :postcode]`)

**Ash Identity**: `unique_name_postcode` on `[:normalized_name, :postcode]`

**Ash Constraints**: `business_type` must be one of `[:limited_company, :individual, :partnership, :plc, :other]`

**Relationships**:
- `has_many :cases` → `cases.offender_id`
- `has_many :notices` → `notices.offender_id`

**Business Logic**: 
- `normalized_name` is automatically generated from `name` using company name normalization rules
- Statistics (`total_cases`, `total_notices`, `total_fines`) are maintained via updates

---

### `cases` Table

**Purpose**: Court enforcement cases against offenders.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | PRIMARY KEY, NOT NULL | Case unique identifier |
| `airtable_id` | `text` | NULLABLE, UNIQUE (if not null) | Airtable record ID |
| `regulator_id` | `text` | NULLABLE | HSE/agency internal case ID |
| `agency_id` | `uuid` | NOT NULL, FK → agencies.id | Issuing agency |
| `offender_id` | `uuid` | NOT NULL, FK → offenders.id | Subject offender |
| `offence_result` | `text` | NULLABLE | Court outcome description |
| `offence_fine` | `decimal` | NULLABLE | Fine amount imposed |
| `offence_costs` | `decimal` | NULLABLE | Legal costs imposed |
| `offence_action_date` | `date` | NULLABLE | Date of enforcement action |
| `offence_hearing_date` | `date` | NULLABLE | Court hearing date |
| `offence_breaches` | `text` | NULLABLE | Raw breaches text |
| `offence_breaches_clean` | `text` | NULLABLE | Cleaned breaches text |
| `regulator_function` | `text` | NULLABLE | Regulatory function involved |
| `regulator_url` | `text` | NULLABLE | Source URL at regulator |
| `related_cases` | `text` | NULLABLE | Related case references |
| `offence_action_type` | `text` | NULLABLE | Type of enforcement action |
| `url` | `text` | NULLABLE | Public case URL |
| `last_synced_at` | `timestamp` | NULLABLE | Last synchronization time |
| `inserted_at` | `timestamp` | NOT NULL | Record creation time |
| `updated_at` | `timestamp` | NOT NULL | Record update time |

**Indexes**:
- `cases_unique_airtable_id_index` (UNIQUE on `airtable_id` WHERE `airtable_id IS NOT NULL`)

**Ash Identity**: `unique_airtable_id` on `[:airtable_id]` WHERE `not is_nil(airtable_id)`

**Foreign Keys**:
- `cases_agency_id_fkey`: `agency_id` → `agencies.id`
- `cases_offender_id_fkey`: `offender_id` → `offenders.id`

**Relationships**:
- `belongs_to :agency` → `agencies`
- `belongs_to :offender` → `offenders`
- `has_many :breaches` → `breaches.case_id`

**Event Sourcing**: Enabled with actions `[:create, :sync, :bulk_create]`

---

### `notices` Table

**Purpose**: Enforcement notices issued to offenders (improvement notices, prohibition notices, etc.). Supports fuzzy text search across notice content using PostgreSQL pg_trgm extension.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | PRIMARY KEY, NOT NULL | Notice unique identifier |
| `airtable_id` | `text` | NULLABLE, UNIQUE (if not null) | Airtable record ID |
| `regulator_id` | `text` | NULLABLE | HSE/agency internal notice ID |
| `regulator_ref_number` | `text` | NULLABLE | Official reference number |
| `agency_id` | `uuid` | NOT NULL, FK → agencies.id | Issuing agency |
| `offender_id` | `uuid` | NOT NULL, FK → offenders.id | Subject offender |
| `notice_date` | `date` | NULLABLE | Date notice was issued |
| `operative_date` | `date` | NULLABLE | Date notice becomes operative |
| `compliance_date` | `date` | NULLABLE | Required compliance date |
| `notice_body` | `text` | NULLABLE | Full notice text content |
| `offence_action_type` | `text` | NULLABLE | Type of enforcement action |
| `offence_action_date` | `date` | NULLABLE | Date of original offence |
| `offence_breaches` | `text` | NULLABLE | Legislation breaches |
| `url` | `text` | NULLABLE | Public notice URL |
| `last_synced_at` | `timestamp` | NULLABLE | Last synchronization time |
| `inserted_at` | `timestamp` | NOT NULL | Record creation time |
| `updated_at` | `timestamp` | NOT NULL | Record update time |

**Indexes**:
- `notices_unique_airtable_id_index` (UNIQUE on `airtable_id` WHERE `airtable_id IS NOT NULL`)
- `notices_offence_action_date_index` on `offence_action_date` (dashboard metrics)
- `notices_agency_id_index` on `agency_id` (filtering performance)
- `notices_agency_date_index` (COMPOSITE on `[:agency_id, :offence_action_date]`)
- `notices_regulator_id_index` on `regulator_id` (standard B-tree)
- `notices_offence_breaches_index` on `offence_breaches` (standard B-tree)
- `notices_offence_action_type_index` on `offence_action_type` (filtering)

**Fuzzy Search Indexes (pg_trgm GIN)**:
- `notices_regulator_id_gin_trgm` on `regulator_id` (trigram similarity search)
- `notices_offence_breaches_gin_trgm` on `offence_breaches` (trigram similarity search)
- `notices_notice_body_gin_trgm` on `notice_body` (trigram similarity search)

**Ash Identity**: `unique_airtable_id` on `[:airtable_id]` WHERE `not is_nil(airtable_id)`

**Foreign Keys**:
- `notices_agency_id_fkey`: `agency_id` → `agencies.id`
- `notices_offender_id_fkey`: `offender_id` → `offenders.id`

**Relationships**:
- `belongs_to :agency` → `agencies`
- `belongs_to :offender` → `offenders`

**Fuzzy Search Features**:
- **Function**: `Enforcement.fuzzy_search_notices/2` supports trigram similarity search
- **Search Fields**: `regulator_id`, `notice_body`, `offence_breaches`
- **UI Integration**: Toggle-enabled fuzzy search in LiveView interface
- **Performance**: GIN indexes with `gin_trgm_ops` operator class for fast similarity queries
- **Similarity Threshold**: Configurable threshold (default 0.3) for match sensitivity

---

### `breaches` Table

**Purpose**: Specific legislation breaches associated with cases (normalized from breach text).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | PRIMARY KEY, NOT NULL | Breach unique identifier |
| `case_id` | `uuid` | NOT NULL, FK → cases.id | Associated case |
| `breach_description` | `text` | NULLABLE | Description of the breach |
| `legislation_reference` | `text` | NULLABLE | Specific legislation reference |
| `legislation_type` | `text` | NULLABLE | Type of legislation |
| `inserted_at` | `timestamp` | NOT NULL | Record creation time |

**Ash Constraints**: `legislation_type` must be one of `[:act, :regulation, :acop]`

**Foreign Keys**:
- `breaches_case_id_fkey`: `case_id` → `cases.id`

**Relationships**:
- `belongs_to :case` → `cases`

---

## Configuration Domain

### `scraping_configs` Table

**Purpose**: Configuration profiles for HSE case scraping operations.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | PRIMARY KEY, NOT NULL | Configuration unique identifier |
| `name` | `text` | NOT NULL, UNIQUE | Profile name |
| `is_active` | `boolean` | NOT NULL, DEFAULT true | Whether profile is active |
| `description` | `text` | NULLABLE | Profile description |
| `hse_base_url` | `text` | NOT NULL, DEFAULT 'https://www.hse.gov.uk' | HSE website base URL |
| `hse_database` | `text` | NOT NULL, DEFAULT 'convictions' | HSE database to scrape |
| `requests_per_minute` | `integer` | NOT NULL, DEFAULT 10 | Rate limiting: requests/minute |
| `network_timeout_ms` | `integer` | NOT NULL, DEFAULT 30000 | HTTP timeout (milliseconds) |
| `pause_between_pages_ms` | `integer` | NOT NULL, DEFAULT 3000 | Delay between requests |
| `consecutive_existing_threshold` | `integer` | NOT NULL, DEFAULT 10 | Stop after N existing records |
| `max_pages_per_session` | `integer` | NOT NULL, DEFAULT 100 | Max pages per scraping session |
| `max_consecutive_errors` | `integer` | NOT NULL, DEFAULT 3 | Stop after N consecutive errors |
| `batch_size` | `integer` | NOT NULL, DEFAULT 50 | Records per processing batch |
| `scheduled_scraping_enabled` | `boolean` | NOT NULL, DEFAULT true | Enable scheduled scraping |
| `manual_scraping_enabled` | `boolean` | NOT NULL, DEFAULT true | Enable manual scraping |
| `real_time_progress_enabled` | `boolean` | NOT NULL, DEFAULT true | Enable progress updates |
| `admin_notifications_enabled` | `boolean` | NOT NULL, DEFAULT true | Enable admin notifications |
| `daily_scrape_cron` | `text` | NULLABLE, DEFAULT '0 2 * * *' | Daily scraping schedule |
| `weekly_scrape_cron` | `text` | NULLABLE, DEFAULT '0 1 * * 0' | Weekly scraping schedule |
| `inserted_at` | `timestamp` | NOT NULL | Record creation time |
| `updated_at` | `timestamp` | NOT NULL | Record update time |

**Indexes**:
- `scraping_configs_unique_name_index` (UNIQUE on `name`)

**Ash Identity**: `unique_name` on `[:name]`

**Ash Constraints**:
- `requests_per_minute` > 0
- `network_timeout_ms` >= 5000
- `consecutive_existing_threshold` >= 3
- `max_pages_per_session` >= 5
- `batch_size` >= 10
- `hse_base_url` matches HTTP/HTTPS URL pattern
- `hse_database` must be one of `["convictions", "enforcement", "notices"]`

---

## Sync Domain

### `sync_logs` Table

**Purpose**: Tracks data synchronization operations and their results.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | PRIMARY KEY, NOT NULL | Sync log unique identifier |
| `agency_id` | `uuid` | NOT NULL, FK → agencies.id | Agency being synchronized |
| `sync_type` | `text` | NULLABLE | Type of sync operation |
| `status` | `text` | NULLABLE | Sync operation status |
| `records_synced` | `integer` | NOT NULL, DEFAULT 0 | Number of records processed |
| `error_message` | `text` | NULLABLE | Error details if failed |
| `started_at` | `timestamp` | NULLABLE | Sync start time |
| `completed_at` | `timestamp` | NULLABLE | Sync completion time |
| `inserted_at` | `timestamp` | NOT NULL | Record creation time |

**Ash Constraints**:
- `sync_type` must be one of `[:cases, :notices]`
- `status` must be one of `[:started, :completed, :failed]`

**Foreign Keys**:
- `sync_logs_agency_id_fkey`: `agency_id` → `agencies.id`

**Relationships**:
- `belongs_to :agency` → `agencies`

---

## Events Domain

### `events` Table

**Purpose**: Event sourcing and audit trail for core domain operations.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigserial` | PRIMARY KEY, NOT NULL | Event sequence identifier |
| `record_id` | `uuid` | NOT NULL | ID of the affected record |
| `resource` | `text` | NOT NULL | Ash resource name |
| `action` | `text` | NOT NULL | Action name that was performed |
| `action_type` | `text` | NOT NULL | Type of action (create, update, etc.) |
| `version` | `integer` | NOT NULL, DEFAULT 1 | Action version for schema evolution |
| `data` | `jsonb` | NOT NULL, DEFAULT {} | Event data payload |
| `metadata` | `jsonb` | NOT NULL, DEFAULT {} | Additional event metadata |
| `occurred_at` | `timestamp` | NOT NULL | Event timestamp |

**Purpose**: Centralized event log supporting event sourcing patterns and audit requirements.

---

## Relationship Summary

### Primary Entity Relationships

```
agencies (1) → (N) cases
agencies (1) → (N) notices
agencies (1) → (N) sync_logs

offenders (1) → (N) cases
offenders (1) → (N) notices

cases (1) → (N) breaches

users (1) → (N) user_identities
```

### Critical Foreign Key Constraints

All foreign key relationships use CASCADE or RESTRICT policies:
- `user_identities.user_id` → `users.id` (CASCADE DELETE)
- `cases.agency_id` → `agencies.id` (RESTRICT)
- `cases.offender_id` → `offenders.id` (RESTRICT)
- `notices.agency_id` → `agencies.id` (RESTRICT)
- `notices.offender_id` → `offenders.id` (RESTRICT)
- `breaches.case_id` → `cases.id` (RESTRICT)
- `sync_logs.agency_id` → `agencies.id` (RESTRICT)

---

## Common Schema Issues and Solutions

### 1. Offender Deduplication
**Issue**: Multiple variations of the same company name
**Solution**: Use `normalized_name` field with automatic normalization in Ash resource

### 2. Airtable Integration
**Issue**: Maintaining sync with external Airtable data
**Solution**: `airtable_id` fields with conditional unique constraints (`WHERE airtable_id IS NOT NULL`)

### 3. Agency Code Validation
**Issue**: Ensuring valid agency codes
**Solution**: Ash constraint `one_of: [:hse, :onr, :orr, :ea]` with unique index

### 4. Event Sourcing
**Issue**: Audit trail and data evolution
**Solution**: Centralized `events` table with versioned actions for schema evolution

### 5. Configuration Management
**Issue**: Managing multiple scraping configurations
**Solution**: Single active configuration with validation constraints

---

## Database Constraints Summary

### Unique Constraints
- `users.email` (case-insensitive)
- `agencies.code`
- `offenders.normalized_name + postcode`
- `cases.airtable_id` (conditional)
- `notices.airtable_id` (conditional)
- `scraping_configs.name`
- `user_identities.strategy + uid + user_id`
- `tokens.jti`

### Check Constraints (via Ash validations)
- Rate limiting values > minimum thresholds
- URL format validation
- Enum value constraints on status/type fields
- Business logic validations

This schema supports the full EHS enforcement data collection and management workflow with proper normalization, constraints, and audit capabilities.

---

## Airtable to PostgreSQL Field Mapping

The original production database is a single Airtable table containing all enforcement records. This section maps the Airtable field names to their corresponding PostgreSQL table and column combinations in the normalized schema.

### Core Record Fields

| Airtable Field | PostgreSQL Table | Column | Notes |
|---------------|------------------|--------|-------|
| `agency_code` | `cases` / `notices` | `agency_id` | Mapped via `agencies.code` lookup |
| `regulator_id` | `cases` / `notices` | `regulator_id` | Direct mapping (primary identifier) |
| `notice_id` | `notices` | `regulator_id` | Alternative identifier for notices |
| `offence_action_type` | `cases` / `notices` | `offence_action_type` | Used to partition records |
| `offence_action_date` | `cases` / `notices` | `offence_action_date` | Direct mapping |

### Offender Fields (Normalized to `offenders` table)

| Airtable Field | PostgreSQL Table | Column | Notes |
|---------------|------------------|--------|-------|
| `offender_name` | `offenders` | `name` | Original company/individual name |
| `offender_name` | `offenders` | `normalized_name` | Auto-generated normalized version |
| `offender_address` | `offenders` | `address` | Business address |
| `offender_local_authority` | `offenders` | `local_authority` | Direct mapping |
| `offender_country` | `offenders` | `country` | England, Scotland, Wales, Northern Ireland |
| `offender_postcode` | `offenders` | `postcode` | Normalized to uppercase |
| `offender_main_activity` | `offenders` | `main_activity` | Direct mapping |
| `offender_sic` | `offenders` | `sic_code` | Standard Industrial Classification code |
| `offender_business_type` | `offenders` | `business_type` | Mapped to atoms: LTD→:limited_company, PLC→:plc, etc. |
| `offender_industry` | `offenders` | `industry` | Industry classification |

### Case-Specific Fields

| Airtable Field | PostgreSQL Table | Column | Notes |
|---------------|------------------|--------|-------|
| `offence_hearing_date` | `cases` | `offence_hearing_date` | Court hearing date |
| `offence_result` | `cases` | `offence_result` | Court case outcome |
| `offence_fine` | `cases` | `offence_fine` | Financial penalty amount |
| `offence_costs` | `cases` | `offence_costs` | Legal costs |
| `offence_breaches` | `cases` | `offence_breaches` | Raw breach text |
| `offence_breaches_clean` | `cases` | `offence_breaches_clean` | Processed breach text |
| `regulator_function` | `cases` | `regulator_function` | HSE division/function |
| `regulator_url` | `cases` | `regulator_url` | Direct link to case |
| `related_cases` | `cases` | `related_cases` | Connected case references |

### Notice-Specific Fields

| Airtable Field | PostgreSQL Table | Column | Notes |
|---------------|------------------|--------|-------|
| `notice_date` | `notices` | `notice_date` | Date notice was issued |
| `date_issued` | `notices` | `notice_date` | Alternative field name |
| `operative_date` | `notices` | `operative_date` | When notice becomes effective |
| `compliance_date` | `notices` | `compliance_date` | Compliance deadline |
| `notice_body` | `notices` | `notice_body` | Full notice text |
| `breach_details` | `notices` | `offence_breaches` | Notice-specific breach info |

### Record Partitioning Logic

The single Airtable table is partitioned into PostgreSQL tables based on `offence_action_type`:

| Airtable `offence_action_type` | PostgreSQL Table | Record Type |
|-------------------------------|------------------|-------------|
| `"Court Case"` | `cases` | Legal proceedings |
| `"Caution"` | `cases` | Formal warnings |
| `"Improvement Notice"` | `notices` | Compliance orders |
| `"Prohibition Notice"` | `notices` | Stop work orders |
| `"Crown Notice"` | `notices` | Crown-specific notices |
| Other enforcement types | `notices` | Various notice types |

### Derived/Computed Fields

Some PostgreSQL fields are computed from Airtable data during import:

| PostgreSQL Field | Source Logic | Notes |
|------------------|--------------|-------|
| `offenders.normalized_name` | Auto-generated from `offender_name` | Lowercase, standardized suffixes |
| `offenders.business_type` | Inferred from `offender_name` patterns | `:limited_company`, `:plc`, `:individual`, etc. |
| `agencies.id` | Lookup from `agency_code` | UUID foreign key |
| `offenders.id` | Find-or-create from name/postcode | UUID foreign key |

### Migration Strategy

1. **Single source of truth**: Airtable remains primary until migration complete
2. **Bidirectional sync**: Changes flow both ways during transition
3. **Deduplication**: PostgreSQL `normalized_name` handles company name variations
4. **Data integrity**: Foreign key constraints ensure referential integrity
5. **Audit trail**: `events` table tracks all data changes

### Schema Updates (2025-08-11)

**Latest Changes**: Added missing offender fields to support complete Airtable mapping:
- ✅ **Added fields**: `address`, `country`, `sic_code` 
- ✅ **Business type mapping**: Airtable strings → PostgreSQL atoms (LTD → :limited_company, etc.)
- ✅ **Country capture**: Now captures country from HSE search criteria (England, Scotland, Wales, Northern Ireland)

**Production Update**: Use `scripts/update_offender_fields.exs` to backfill existing production records with missing field data from Airtable.

### Common Field Naming Patterns

- **Dates**: Always use full descriptive names (`offence_action_date` not `action_date`)
- **Money**: Use `offence_fine` and `offence_costs` (separate fields)
- **IDs**: `regulator_id` for external identifiers, `id` for internal UUIDs
- **References**: `_id` suffix for foreign keys, `_url` for external links
- **Text processing**: Raw (`offence_breaches`) and clean (`offence_breaches_clean`) versions

---

## HSE Case Scraping Data Mapping

This section maps the data flow from the legacy HSE case scraping through the refactored scraper to the PostgreSQL database.

### Legacy HSECase Struct → Refactored ScrapedCase → PostgreSQL Cases Table

| Legacy HSECase Field | Refactored ScrapedCase Field | PostgreSQL Column | Notes |
|---------------------|------------------------------|-------------------|-------|
| `:regulator` | _Not captured_ | _Via agency lookup_ | Always "HSE" for HSE cases |
| `:regulator_id` | `:regulator_id` | `regulator_id` | HSE internal case reference |
| `:regulator_function` | `:regulator_function` | `regulator_function` | HSE division/function |
| `:regulator_regulator_function` | _Not needed_ | _Computed_ | "HSE_" + function |
| `:regulator_url` | _Not captured_ | `regulator_url` | Link to HSE case page |
| `:offender_name` | `:offender_name` | `offenders.name` | Via offender normalization |
| `:offender_local_authority` | `:offender_local_authority` | `offenders.local_authority` | Via offender record |
| `:offender_main_activity` | `:offender_main_activity` | `offenders.main_activity` | Via offender record |
| `:offender_business_type` | _Not captured_ | `offenders.business_type` | Inferred during processing |
| `:offender_index` | _Not used_ | _Not stored_ | Legacy field |
| `:offender_industry` | `:offender_industry` | `offenders.industry` | Via offender record |
| `:offence_result` | `:offence_result` | `offence_result` | Court case outcome |
| `:offence_fine` | `:offence_fine` | `offence_fine` | Financial penalty (Decimal) |
| `:offence_costs` | `:offence_costs` | `offence_costs` | Legal costs (Decimal) |
| `:offence_action_type` | _Not captured_ | `offence_action_type` | Inferred as "Court Case" |
| `:offence_action_date` | `:offence_action_date` | `offence_action_date` | Enforcement action date |
| `:offence_hearing_date` | `:offence_hearing_date` | `offence_hearing_date` | **Now captured** via breach scraping |
| `:offence_number` | `:offence_number` | _Not stored directly_ | **Now captured** breach count |
| `:offence_breaches` | `:offence_breaches` | `offence_breaches` | **Now captured** via breach scraping |
| `:offence_breaches_clean` | _Processing stage_ | `offence_breaches_clean` | Processed during case creation |
| `:offence_lrt` | _Not applicable_ | _Not used_ | Legacy field for legislation lookup |
| `:offender_related_cases` | `:related_cases` | `related_cases` | **Now captured** via related case scraping |

### New Data Captured by Enhanced Scraper

The refactored scraper now captures **all the data** that the legacy version extracted, plus additional metadata:

#### **Previously Missing (Now Captured):**
- ✅ **Breach Details**: Full breach descriptions from separate breach pages
- ✅ **Hearing Dates**: Court hearing dates from breach data
- ✅ **Related Cases**: Connected case references from related case pages
- ✅ **Breach Count**: Number of breaches (`offence_number`)

#### **Additional Metadata (New):**
- ✅ **Scrape Metadata**: `page_number`, `scrape_timestamp` for tracking
- ✅ **Error Handling**: Robust retry logic and rate limiting
- ✅ **Structured Processing**: Clean separation of scraping and database operations

### Data Flow Process

```
HSE Website Pages → ScrapedCase Struct → CaseProcessor → PostgreSQL
     ↓                    ↓                    ↓              ↓
1. Case list page     Raw scraped data    Processed data   Normalized tables
2. Case detail page   + breach details    + offender       cases + offenders  
3. Breach pages       + related cases     matching         + relationships
4. Related case pages + enriched data     + validation     + audit events
```

### Key Enhancements in Refactored Version

1. **Complete Data Extraction**: Now extracts all data fields from legacy version
2. **Robust Architecture**: Proper error handling, rate limiting, retries
3. **Ash Integration**: Uses Ash resources for database operations and business logic
4. **Data Normalization**: Separates offenders into dedicated table with deduplication
5. **Event Sourcing**: All database changes tracked in events table
6. **Type Safety**: Uses Decimal for monetary amounts, proper date parsing
7. **Testing**: Comprehensive test coverage with proper mocking

The enhanced scraper maintains **100% data compatibility** with the legacy version while providing significant architectural improvements for reliability and maintainability.
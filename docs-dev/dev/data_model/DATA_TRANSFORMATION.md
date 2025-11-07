# Data Transformation Pipeline

**Complete guide to data flow from HTML scraping to PostgreSQL database storage**

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Layers](#architecture-layers)
3. [HSE Case Data Flow](#hse-case-data-flow)
4. [HSE Notice Data Flow](#hse-notice-data-flow)
5. [Data Parsers & Transformers](#data-parsers--transformers)
6. [Database Schema Mapping](#database-schema-mapping)
7. [Offender Matching Logic](#offender-matching-logic)
8. [Data Quality Rules](#data-quality-rules)
9. [Module Reference](#module-reference)

---

## Overview

The EHS Enforcement application scrapes UK regulatory enforcement data from websites (HSE, Environment Agency, etc.), transforms the HTML data through multiple processing stages, and stores it in a PostgreSQL database using the Ash Framework.

### Pipeline Stages

```
HTML Scraping → Parsing → Transformation → Matching → Database Storage
    ↓              ↓            ↓             ↓              ↓
 CaseScraper   ScrapedCase  ProcessedCase  Offender    PostgreSQL
 NoticeScraper             ProcessedNotice  Matching    (via Ash)
```

---

## Architecture Layers

### Layer 1: HTTP Scraping
**Purpose**: Fetch HTML from regulatory websites
**Modules**: `CaseScraper`, `NoticeScraper`
**Output**: Raw HTML documents

### Layer 2: HTML Parsing
**Purpose**: Extract data from HTML tables and elements
**Tools**: Floki (HTML parser)
**Output**: `ScrapedCase`, `ScrapedNotice` structs with raw string data

### Layer 3: Data Transformation
**Purpose**: Clean, normalize, and enrich data
**Modules**: `CaseProcessor`, `NoticeProcessor`, `OffenderBuilder`
**Output**: `ProcessedCase`, `ProcessedNotice` structs with typed data

### Layer 4: Persistence
**Purpose**: Store data in PostgreSQL with duplicate detection
**Framework**: Ash
**Output**: Database records in `cases`, `notices`, `offenders` tables

---

## HSE Case Data Flow

### 1. HTML Source Structure

HSE provides three pages per case:

#### Case List Page
**URL**: `https://resources.hse.gov.uk/convictions/case/case_list.asp?PN={page}&...`

```html
<table>
  <tr>
    <td><a href="case_details.asp?...">HSE_123456</a></td>
    <td>ACME CONSTRUCTION LIMITED</td>
    <td>15/03/2024</td>
    <td>Westminster</td>
    <td>Construction of buildings</td>
  </tr>
</table>
```

#### Case Details Page
**URL**: `https://resources.hse.gov.uk/convictions/case/case_details.asp?SF=CN&SV={case_id}`

```html
<table>
  <tr>
    <td colspan="2"></td>
    <td><b>HSE Directorate</b></td>
    <td>CONSTRUCTION DIVISION</td>
  </tr>
  <tr>
    <td><b>Total Fine</b></td>
    <td>£25,000.00</td>
    <td><b>Total Costs Awarded to HSE</b></td>
    <td>£3,500.00</td>
  </tr>
</table>
```

#### Breach List Page
**URL**: `https://resources.hse.gov.uk/convictions/breach/breach_list.asp?...`

```html
<table>
  <tr>
    <td></td>
    <td></td>
    <td>10/01/2024</td>
    <td>Guilty</td>
    <td></td>
    <td>Health and Safety at Work etc Act 1974, Section 2(1)</td>
  </tr>
</table>
```

### 2. HTML to ScrapedCase Struct

**Module**: `EhsEnforcement.Scraping.Hse.CaseScraper`
**File**: `lib/ehs_enforcement/scraping/hse/case_scraper.ex`

#### Extraction Mapping

| HTML Element | Extraction Method | ScrapedCase Field |
|-------------|------------------|------------------|
| `<a href="...">HSE_123456</a>` | Floki text extraction | `regulator_id` |
| `<td>ACME CONSTRUCTION LIMITED</td>` | Direct text | `offender_name` |
| `<td>15/03/2024</td>` | `Utility.iso_date/1` | `offence_action_date` |
| `<td>Westminster</td>` | Direct text | `offender_local_authority` |
| `<td>Construction of buildings</td>` | Direct text | `offender_main_activity` |
| `<td>£25,000.00</td>` | `MonetaryParser.parse/1` | `offence_fine` |
| `<td>£3,500.00</td>` | `MonetaryParser.parse/1` | `offence_costs` |
| `<td>10/01/2024</td>` | `Utility.iso_date/1` | `offence_hearing_date` |
| `<td>Guilty</td>` | Direct text | `offence_result` |
| `<td>CONSTRUCTION DIVISION</td>` | Direct text | `regulator_function` |
| `<td>Health and Safety...</td>` | Joined with "; " | `offence_breaches` |

#### Code Example (Lines 275-297)

```elixir
def parse_case_rows(table_data, page_number) do
  table_data
  |> Enum.chunk_every(5)  # Group into rows of 5 cells
  |> Enum.map(fn
    [
      {"td", _, [{"a", [_, _], [regulator_id]}]},
      {"td", _, [offender_name]},
      {"td", _, [offence_action_date]},
      {"td", _, [offender_local_authority]},
      {"td", _, [offender_main_activity]}
    ] ->
      %ScrapedCase{
        regulator_id: String.trim(regulator_id),
        offender_name: String.trim(offender_name),
        offence_action_date: Utility.iso_date(offence_action_date),
        offender_local_authority: String.trim(offender_local_authority),
        offender_main_activity: String.trim(offender_main_activity),
        page_number: page_number,
        scrape_timestamp: DateTime.utc_now()
      }
  end)
end
```

### 3. ScrapedCase to ProcessedCase

**Module**: `EhsEnforcement.Scraping.Hse.CaseProcessor`
**File**: `lib/ehs_enforcement/scraping/hse/case_processor.ex`

#### Transformation Rules

| ScrapedCase Field | Transformation | ProcessedCase Field | Notes |
|------------------|----------------|---------------------|-------|
| `regulator_id` | Direct copy | `regulator_id` | No change |
| (hardcoded) | `:hse` | `agency_code` | HSE agency identifier |
| `offender_name` | → `OffenderBuilder` | `offender_attrs.name` | Passed to offender builder |
| `offender_name` | → `BusinessTypeDetector` | `offender_attrs.business_type` | `:limited_company`, `:plc`, etc. |
| `offender_local_authority` | Direct copy | `offender_attrs.local_authority` | No change |
| `offender_main_activity` | Direct copy | `offender_attrs.main_activity` | No change |
| `offender_industry` | Direct copy | `offender_attrs.industry` | Optional field |
| `offence_result` | Direct copy | `offence_result` | "Guilty", "Not Guilty", etc. |
| `offence_fine` | Already `Decimal` | `offence_fine` | No change (parsed during scraping) |
| `offence_costs` | Already `Decimal` | `offence_costs` | No change |
| `offence_action_date` | Already `Date` | `offence_action_date` | No change |
| `offence_hearing_date` | Already `Date` | `offence_hearing_date` | No change |
| `offence_breaches` | → `process_breaches/2` | `offence_breaches` | Semicolon-separated string |
| `offence_breaches` | Clean & trim | `offence_breaches_clean` | Cleaned version |
| `regulator_function` | `upcase_first/1` | `regulator_function` | "Construction Division" |
| `regulator_id` | → `build_url/1` | `regulator_url` | Full HSE details URL |
| (hardcoded) | "Court Case" | `offence_action_type` | Default for cases |

#### Code Example (Lines 50-91)

```elixir
def process_case(%ScrapedCase{} = scraped_case) do
  processed = %ProcessedCase{
    regulator_id: scraped_case.regulator_id,
    agency_code: :hse,
    offender_attrs: build_offender_attrs(scraped_case),
    offence_result: scraped_case.offence_result,
    offence_fine: scraped_case.offence_fine,
    offence_costs: scraped_case.offence_costs,
    offence_action_date: scraped_case.offence_action_date,
    offence_hearing_date: scraped_case.offence_hearing_date,
    regulator_function: scraped_case.regulator_function,
    regulator_url: build_regulator_url(scraped_case.regulator_id),
    related_cases: scraped_case.related_cases,
    offence_action_type: "Court Case"
  }

  # Process breaches if present
  case scraped_case.offence_breaches do
    breaches when is_list(breaches) and length(breaches) > 0 ->
      process_breaches(processed, breaches)

    breach when is_binary(breach) and breach != "" ->
      process_breaches(processed, [breach])

    _ ->
      processed
  end
end
```

### 4. ProcessedCase to Database

**Module**: `EhsEnforcement.Enforcement` (Ash Domain)
**Resource**: `EhsEnforcement.Enforcement.Resources.Case`

#### Database Column Mapping

| ProcessedCase Field | Database Table | Column Name | Data Type | Constraints |
|---------------------|---------------|-------------|-----------|-------------|
| `regulator_id` | `cases` | `regulator_id` | `TEXT` | NOT NULL |
| `agency_code` | → `agencies.id` | `agency_id` | `UUID` | FOREIGN KEY |
| `offender_attrs` | → `offenders.id` | `offender_id` | `UUID` | FOREIGN KEY |
| `offence_result` | `cases` | `offence_result` | `TEXT` | - |
| `offence_fine` | `cases` | `offence_fine` | `DECIMAL` | >= 0 |
| `offence_costs` | `cases` | `offence_costs` | `DECIMAL` | >= 0 |
| `offence_action_date` | `cases` | `offence_action_date` | `DATE` | Indexed |
| `offence_hearing_date` | `cases` | `offence_hearing_date` | `DATE` | >= action_date |
| `offence_breaches` | `cases` | `offence_breaches` | `TEXT` | - |
| `offence_breaches_clean` | `cases` | `offence_breaches_clean` | `TEXT` | - |
| `regulator_function` | `cases` | `regulator_function` | `TEXT` | - |
| `regulator_url` | `cases` | `regulator_url` | `TEXT` | - |
| `offence_action_type` | `cases` | `offence_action_type` | `TEXT` | - |

#### Persistence Code (Lines 177-213)

```elixir
def create_case(%ProcessedCase{} = processed, opts \\ []) do
  actor = Keyword.get(opts, :actor)

  # Get agency
  {:ok, agency} = get_agency_by_code(processed.agency_code)

  # Find or create offender
  {:ok, offender} = Offender.find_or_create_offender(processed.offender_attrs)

  # Build case attributes
  case_attrs = %{
    regulator_id: processed.regulator_id,
    agency_id: agency.id,
    offender_id: offender.id,
    offence_result: processed.offence_result,
    offence_fine: processed.offence_fine,
    offence_costs: processed.offence_costs,
    offence_action_date: processed.offence_action_date,
    offence_hearing_date: processed.offence_hearing_date,
    offence_breaches: processed.offence_breaches,
    offence_breaches_clean: processed.offence_breaches_clean,
    regulator_function: processed.regulator_function,
    regulator_url: processed.regulator_url,
    offence_action_type: processed.offence_action_type
  }

  # Create or update case
  case get_case_by_agency_and_regulator_id(agency.id, processed.regulator_id) do
    {:ok, existing_case} ->
      update_case(existing_case, case_attrs, actor: actor)

    {:error, _} ->
      create_case_record(case_attrs, actor: actor)
  end
end
```

---

## HSE Notice Data Flow

### 1. HTML Source Structure

#### Notice List Page
**URL**: `https://resources.hse.gov.uk/notices/notices/notice_list.asp?...`

```html
<table>
  <tr>
    <td><a href="notice_details.asp?...">N/2024/12345</a></td>
    <td>Smith & Jones LLP</td>
    <td>Improvement Notice</td>
    <td>20/05/2024</td>
    <td>Birmingham</td>
    <td>46.72</td>
  </tr>
</table>
```

#### Notice Details Page

```html
<table>
  <tr>
    <td><b>Compliance Date</b></td>
    <td>20/07/2024</td>
    <td><b>Revised Compliance Date</b></td>
    <td>20/09/2024</td>
  </tr>
  <tr>
    <td><b>Description</b></td>
    <td>Failure to provide adequate guarding on machinery</td>
  </tr>
</table>
```

### 2. HTML to Database Mapping

| HTML Element | Parser | Intermediate Field | DB Table | DB Column |
|-------------|--------|-------------------|----------|-----------|
| `N/2024/12345` | Direct text | `regulator_id` | `notices` | `regulator_id` |
| `Smith & Jones LLP` | Direct text | `offender_name` | `offenders` | `name` |
| `Improvement Notice` | Direct text | `offence_action_type` | `notices` | `notice_type` |
| `20/05/2024` | `Utility.iso_date/1` | `offence_action_date` | `notices` | `notice_date` |
| `Birmingham` | Direct text | `offender_local_authority` | `offenders` | `local_authority` |
| `46.72` | Direct text | `offender_sic` | `offenders` | `sic_code` |
| `20/07/2024` | `Utility.iso_date/1` | `compliance_date` | `notices` | `compliance_date` |
| `Failure to...` | Direct text | `notice_body` | `notices` | `notice_body` |
| `Regulation 11` | Joined | `offence_breaches` | `notices` | `offence_breaches` |

---

## Data Parsers & Transformers

### Monetary Parser

**Module**: `EhsEnforcement.Scraping.Shared.MonetaryParser`
**File**: `lib/ehs_enforcement/scraping/shared/monetary_parser.ex`

#### Transformation Logic

```elixir
Input:  "£12,345.67"
Step 1: Extract digits/decimals → "12,345.67"  (Regex: ~r/[\d,]+\.?\d*/)
Step 2: Remove commas → "12345.67"             (String.replace(",", ""))
Step 3: Parse to Decimal → #Decimal<12345.67>  (Decimal.new/1)
Output: #Decimal<12345.67>
```

#### Supported Formats

| Input | Output |
|-------|--------|
| `"£12,345.67"` | `#Decimal<12345.67>` |
| `"$1,000"` | `#Decimal<1000>` |
| `"12345.67"` | `#Decimal<12345.67>` |
| `"invalid"` | `#Decimal<0>` |
| `nil` | `#Decimal<0>` |

### Date Parser

**Module**: `EhsEnforcement.Scraping.Shared.DateParser`
**File**: `lib/ehs_enforcement/scraping/shared/date_parser.ex`

#### Parsing Priority

1. **ISO 8601** (`2025-10-23`) → Fastest path
2. **UK Slash** (`23/10/2025`) → Convert to ISO
3. **UK Dash** (`23-10-2025`) → Convert to ISO
4. **Regex Fallback** → Manual parsing

#### Transformation Examples

| Input | Format | Output |
|-------|--------|--------|
| `"2025-10-23"` | ISO 8601 | `~D[2025-10-23]` |
| `"23/10/2025"` | UK slash | `~D[2025-10-23]` |
| `"23-10-2025"` | UK dash | `~D[2025-10-23]` |
| `"invalid"` | - | `nil` |

### Business Type Detector

**Module**: `EhsEnforcement.Scraping.Shared.BusinessTypeDetector`
**File**: `lib/ehs_enforcement/scraping/shared/business_type_detector.ex`

#### Pattern Matching Rules

```elixir
Input: Company name string
Process: Regex pattern matching on suffixes
Output: Ash enum atom

# Patterns (in priority order)
~r/LLC|llc/                  → "LLC"    → :limited_company
~r/[Ii]nc$/                  → "INC"    → :limited_company
~r/[ ][Cc]orp[. ]/           → "CORP"   → :limited_company
~r/PLC|[Pp]lc/               → "PLC"    → :plc
~r/[Ll]imited|LIMITED|Ltd/   → "LTD"    → :limited_company
~r/LLP|[Ll]lp/               → "LLP"    → :partnership
<default>                    → "SOLE"   → :individual
```

#### Examples

| Company Name | Detected Type | Ash Enum |
|-------------|--------------|----------|
| `"ACME CONSTRUCTION LIMITED"` | `"LTD"` | `:limited_company` |
| `"Smith & Jones LLP"` | `"LLP"` | `:partnership` |
| `"British Gas PLC"` | `"PLC"` | `:plc` |
| `"John Smith"` | `"SOLE"` | `:individual` |

### Offender Builder

**Module**: `EhsEnforcement.Agencies.Hse.OffenderBuilder`
**File**: `lib/ehs_enforcement/agencies/hse/offender_builder.ex`

#### Attribute Assembly (Lines 82-112)

```elixir
def build_offender_attrs(%ScrapedCase{} = scraped, :case) do
  %{
    name: scraped.offender_name,
    local_authority: scraped.offender_local_authority,
    main_activity: scraped.offender_main_activity,
    industry: scraped.offender_industry,
    business_type: determine_and_normalize_business_type(scraped.offender_name)
  }
  |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
  |> Map.new()
end
```

---

## Database Schema Mapping

### Cases Table

**Migration**: `priv/repo/migrations/20250725083907_create_enforcement_resources.exs`
**Ash Resource**: `lib/ehs_enforcement/enforcement/resources/case.ex`

#### Schema Definition

```sql
CREATE TABLE cases (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identifiers
  airtable_id TEXT,              -- Legacy Airtable sync ID
  regulator_id TEXT,             -- HSE/EA case number (e.g., "HSE_123456")

  -- Case details
  offence_result TEXT,           -- Verdict: "Guilty", "Not Guilty", etc.
  offence_fine DECIMAL,          -- Fine amount in GBP (CHECK >= 0)
  offence_costs DECIMAL,         -- Court costs in GBP (CHECK >= 0)
  offence_action_date DATE,      -- Date of offence/case (INDEXED)
  offence_hearing_date DATE,     -- Hearing date (CHECK >= action_date)
  offence_breaches TEXT,         -- Semicolon-separated breach descriptions
  offence_breaches_clean TEXT,   -- Cleaned breach text
  offence_action_type TEXT,      -- "Court Case", "Formal Caution"

  -- Regulator information
  regulator_function TEXT,       -- HSE department (e.g., "Construction Division")
  regulator_url TEXT,            -- Source URL on HSE website
  related_cases TEXT,            -- Comma-separated related case IDs

  -- EA-specific fields
  ea_event_reference TEXT,       -- EA event ID
  ea_total_violation_count INT,  -- Number of violations
  environmental_impact TEXT,     -- Impact description
  environmental_receptor TEXT,   -- Affected receptor (water, air, etc.)
  is_ea_multi_violation BOOLEAN DEFAULT false,

  -- Metadata
  url TEXT,                      -- General URL field
  last_synced_at TIMESTAMP,      -- Last sync with external systems
  inserted_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),

  -- Foreign keys
  agency_id UUID NOT NULL REFERENCES agencies(id),
  offender_id UUID NOT NULL REFERENCES offenders(id)
);

-- Indexes
CREATE UNIQUE INDEX cases_unique_airtable_id_index
  ON cases(airtable_id) WHERE airtable_id IS NOT NULL;

CREATE INDEX cases_offence_action_date_index
  ON cases(offence_action_date);

CREATE INDEX cases_agency_id_index
  ON cases(agency_id);

CREATE INDEX cases_agency_date_index
  ON cases(agency_id, offence_action_date);
```

#### Data Constraints

```sql
-- Check constraints
ALTER TABLE cases ADD CONSTRAINT offence_fine_non_negative
  CHECK (offence_fine IS NULL OR offence_fine >= 0);

ALTER TABLE cases ADD CONSTRAINT offence_costs_non_negative
  CHECK (offence_costs IS NULL OR offence_costs >= 0);

ALTER TABLE cases ADD CONSTRAINT dates_logical_order
  CHECK (
    offence_hearing_date IS NULL OR
    offence_action_date IS NULL OR
    offence_hearing_date >= offence_action_date
  );
```

### Offenders Table

**Migration**: Same as above (Lines 27-52)
**Ash Resource**: `lib/ehs_enforcement/enforcement/resources/offender.ex`

#### Schema Definition

```sql
CREATE TABLE offenders (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Core information
  name TEXT NOT NULL,                -- Company/individual name
  normalized_name TEXT,              -- Lowercase, cleaned for matching
  address TEXT,                      -- Full address
  local_authority TEXT,              -- Local authority
  country TEXT,                      -- Country (England, Wales, Scotland, NI)
  postcode TEXT,                     -- UK postcode
  town TEXT,                         -- Town/city
  county TEXT,                       -- County

  -- Business information
  main_activity TEXT,                -- Business activity description
  business_type TEXT,                -- Enum: limited_company, plc, partnership, individual, other
  industry TEXT,                     -- Industry sector
  sic_code TEXT,                     -- Standard Industrial Classification code
  company_registration_number TEXT,  -- Companies House number
  industry_sectors TEXT[],           -- Array of industry sectors
  agencies TEXT[] DEFAULT '{}',      -- Array of agencies: {hse, ea, sepa, etc.}

  -- Statistics (denormalized for performance)
  first_seen_date DATE,              -- First enforcement action date
  last_seen_date DATE,               -- Most recent enforcement action date
  total_cases BIGINT DEFAULT 0,      -- Total number of court cases
  total_notices BIGINT DEFAULT 0,    -- Total number of notices issued
  total_fines DECIMAL DEFAULT 0,     -- Sum of all fines

  -- Metadata
  inserted_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Indexes
CREATE UNIQUE INDEX offenders_unique_name_postcode_index
  ON offenders(name, postcode);

CREATE INDEX offenders_normalized_name_index
  ON offenders(normalized_name);

-- Full-text search index using pg_trgm
CREATE INDEX offenders_name_trgm_index
  ON offenders USING GIN (name gin_trgm_ops);

CREATE INDEX offenders_normalized_name_trgm_index
  ON offenders USING GIN (normalized_name gin_trgm_ops);
```

### Notices Table

**Migration**: `priv/repo/migrations/20250725083907_create_enforcement_resources.exs`
**Ash Resource**: `lib/ehs_enforcement/enforcement/resources/notice.ex`

#### Schema Definition

```sql
CREATE TABLE notices (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identifiers
  airtable_id TEXT,              -- Legacy Airtable sync ID
  regulator_id TEXT,             -- HSE notice number (e.g., "N/2024/12345")

  -- Notice details
  notice_type TEXT,              -- "Improvement Notice", "Prohibition Notice"
  notice_date DATE,              -- Date issued
  operative_date DATE,           -- Date becomes operative
  compliance_date DATE,          -- Original compliance date
  revised_compliance_date DATE,  -- Revised compliance date (if extended)
  notice_body TEXT,              -- Full text of notice
  result TEXT,                   -- Outcome: "Complied", "Withdrawn", etc.

  -- Breach information
  offence_breaches TEXT,         -- Semicolon-separated breach descriptions

  -- Metadata
  url TEXT,                      -- Source URL
  last_synced_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),

  -- Foreign keys
  agency_id UUID NOT NULL REFERENCES agencies(id),
  offender_id UUID NOT NULL REFERENCES offenders(id)
);

-- Indexes
CREATE UNIQUE INDEX notices_unique_airtable_id_index
  ON notices(airtable_id) WHERE airtable_id IS NOT NULL;

CREATE INDEX notices_notice_date_index
  ON notices(notice_date);

CREATE INDEX notices_agency_id_index
  ON notices(agency_id);
```

---

## Offender Matching Logic

**Purpose**: Prevent duplicate offender records by intelligently matching similar companies

**Module**: `EhsEnforcement.Enforcement.Resources.Offender`
**File**: `lib/ehs_enforcement/enforcement/resources/offender.ex`

### Matching Algorithm

```
┌─────────────────────────────────────────────┐
│ 1. Exact Match (name + postcode)            │
│    Query: WHERE name = ? AND postcode = ?   │
│    ✓ Fast path, bypasses fuzzy search       │
└─────────────────────────────────────────────┘
                    ↓ (if no match)
┌─────────────────────────────────────────────┐
│ 2. Fuzzy Search (normalized_name)           │
│    Query: pg_trgm similarity search          │
│    Threshold: > 0.3 similarity               │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3. Similarity Scoring                       │
│    - Jaccard index (word overlap)           │
│    - Jaro-Winkler distance (string sim)     │
│    - Postcode boost (+15% if matching)      │
│    - Postcode conflict (0% if different)    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 4. Best Match Selection                     │
│    - Filter: similarity > 0.7 (70%)         │
│    - Sort: by similarity DESC, postcode ASC │
│    - Return: highest scoring candidate      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 5. Create New (if no match)                 │
│    - Generate normalized_name               │
│    - Insert with retry on conflict          │
└─────────────────────────────────────────────┘
```

### Similarity Calculation (Lines 406-475)

```elixir
def find_best_match(candidates, attrs) do
  search_postcode = normalize_postcode(attrs[:postcode])

  scored_candidates = candidates
    |> Enum.map(fn candidate ->
      # Calculate base similarity (0.0 - 1.0)
      similarity = calculate_similarity(candidate.name, attrs[:name])

      # Check postcode match
      candidate_postcode = normalize_postcode(candidate.postcode)
      postcode_match = candidate_postcode == search_postcode

      # Postcode conflict detection
      postcode_conflict =
        search_postcode != nil &&
        candidate_postcode != nil &&
        candidate_postcode != search_postcode

      if postcode_conflict do
        # Force no match for same name, different postcodes
        Map.put(candidate, :similarity, 0.0)
      else
        # Boost similarity for postcode matches
        adjusted_similarity = if postcode_match && similarity > 0.6 do
          min(similarity + 0.15, 1.0)  # +15% boost, cap at 100%
        else
          similarity
        end

        candidate
        |> Map.put(:similarity, adjusted_similarity)
        |> Map.put(:postcode_match, postcode_match)
      end
    end)
    |> Enum.filter(fn c -> Map.get(c, :similarity, 0) > 0.7 end)  # 70% threshold
    |> Enum.sort_by(fn c ->
      {c.similarity, if(c.postcode_match, do: 1, else: 0)}
    end, :desc)

  case scored_candidates do
    [] -> nil          # No match, create new
    [best | _] -> best # Return best match
  end
end
```

### Matching Examples

#### Example 1: Exact Match
```elixir
Input: %{name: "ACME LTD", postcode: "SW1A 1AA"}
Existing: %{name: "ACME LTD", postcode: "SW1A 1AA"}
Result: Exact match found ✓
```

#### Example 2: Fuzzy Match (Same Company, Typo)
```elixir
Input: %{name: "ACME CONSTRUTION LTD", postcode: "SW1A 1AA"}
Existing: %{name: "ACME CONSTRUCTION LTD", postcode: "SW1A 1AA"}
Similarity: 0.85 (85%)
Postcode match: Yes → Boost to 1.0 (100%)
Result: Match found ✓
```

#### Example 3: Different Locations (No Match)
```elixir
Input: %{name: "ACME LTD", postcode: "SW1A 1AA"}
Existing: %{name: "ACME LTD", postcode: "M1 1AA"}
Similarity: 1.0 (perfect name match)
Postcode conflict: Yes → Force to 0.0
Result: Create new offender ✗
```

#### Example 4: Similar Name, No Postcode
```elixir
Input: %{name: "Smith Construction Ltd", postcode: nil}
Existing: %{name: "Smith Construction Limited", postcode: nil}
Similarity: 0.89 (89%)
Postcode match: No boost (both nil)
Result: Match found ✓ (above 70% threshold)
```

---

## Data Quality Rules

### 1. Required Fields

**Cases**:
- `regulator_id` (NOT NULL)
- `agency_id` (NOT NULL, FK)
- `offender_id` (NOT NULL, FK)

**Offenders**:
- `name` (NOT NULL)

**Notices**:
- `agency_id` (NOT NULL, FK)
- `offender_id` (NOT NULL, FK)

### 2. Financial Constraints

```sql
CHECK (offence_fine IS NULL OR offence_fine >= 0)
CHECK (offence_costs IS NULL OR offence_costs >= 0)
CHECK (total_fines >= 0)
```

### 3. Date Logic

```sql
CHECK (
  offence_hearing_date IS NULL OR
  offence_action_date IS NULL OR
  offence_hearing_date >= offence_action_date
)
```

### 4. String Cleaning Rules

#### Company Names
```elixir
1. Trim whitespace: String.trim/1
2. Collapse spaces: String.replace(~r/\s+/, " ")
3. Generate normalized: String.downcase/1
4. Keep original for display
```

#### Addresses
```elixir
1. Trim whitespace
2. Remove duplicate commas: String.replace(~r/,\s*,/, ",")
3. Extract UK postcode: ~r/([A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2})$/i
```

#### Monetary Amounts
```elixir
1. Extract digits: Regex.run(~r/[\d,]+\.?\d*/, amount)
2. Remove commas: String.replace(",", "")
3. Parse to Decimal: Decimal.new/1
4. Default to 0 for invalid input
```

### 5. Empty String Handling

**Rule**: Convert empty strings to `nil` for consistency

```elixir
# Before saving
attrs
|> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
|> Map.new()
```

---

## Module Reference

### Scraping Layer

| Module | File | Purpose |
|--------|------|---------|
| `CaseScraper` | `lib/ehs_enforcement/scraping/hse/case_scraper.ex` | Scrape HSE court cases |
| `NoticeScraper` | `lib/ehs_enforcement/scraping/hse/notice_scraper.ex` | Scrape HSE notices |
| `RateLimiter` | `lib/ehs_enforcement/scraping/shared/rate_limiter.ex` | Rate limiting for HTTP requests |

### Processing Layer

| Module | File | Purpose |
|--------|------|---------|
| `CaseProcessor` | `lib/ehs_enforcement/scraping/hse/case_processor.ex` | Transform scraped cases |
| `NoticeProcessor` | `lib/ehs_enforcement/scraping/hse/notice_processor.ex` | Transform scraped notices |
| `OffenderBuilder` | `lib/ehs_enforcement/agencies/hse/offender_builder.ex` | Build offender attributes |

### Parser Utilities

| Module | File | Purpose |
|--------|------|---------|
| `MonetaryParser` | `lib/ehs_enforcement/scraping/shared/monetary_parser.ex` | Parse currency amounts |
| `DateParser` | `lib/ehs_enforcement/scraping/shared/date_parser.ex` | Parse dates (ISO, UK formats) |
| `BusinessTypeDetector` | `lib/ehs_enforcement/scraping/shared/business_type_detector.ex` | Detect company types |

### Persistence Layer

| Module | File | Purpose |
|--------|------|---------|
| `Enforcement` | `lib/ehs_enforcement/enforcement.ex` | Ash domain for enforcement data |
| `Case` | `lib/ehs_enforcement/enforcement/resources/case.ex` | Ash resource for court cases |
| `Notice` | `lib/ehs_enforcement/enforcement/resources/notice.ex` | Ash resource for notices |
| `Offender` | `lib/ehs_enforcement/enforcement/resources/offender.ex` | Ash resource for offenders |
| `Agency` | `lib/ehs_enforcement/enforcement/resources/agency.ex` | Ash resource for agencies |

### Legacy Modules (Being Phased Out)

| Module | File | Notes |
|--------|------|-------|
| `Legl.Countries.Uk.LeglEnforcement.*` | Various | Old namespace, being refactored |
| `Legl.Services.Hse.*` | Various | Old HSE clients, use new scrapers |

---

## Complete Data Flow Example

### HSE Court Case: From HTML to PostgreSQL

```
┌──────────────────────────────────────────────────────────────────┐
│ STEP 1: HTML SOURCE (HSE Website)                                │
├──────────────────────────────────────────────────────────────────┤
│ <tr>                                                              │
│   <td><a>HSE_123456</a></td>                                      │
│   <td>ACME CONSTRUCTION LIMITED</td>                              │
│   <td>15/03/2024</td>                                             │
│   <td>Westminster</td>                                            │
│   <td>Construction of buildings</td>                              │
│ </tr>                                                             │
│                                                                   │
│ (Detail page)                                                     │
│ <tr>                                                              │
│   <td><b>Total Fine</b></td>                                      │
│   <td>£25,000.00</td>                                             │
│   <td><b>Total Costs Awarded to HSE</b></td>                      │
│   <td>£3,500.00</td>                                              │
│ </tr>                                                             │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ STEP 2: SCRAPING (CaseScraper)                                   │
├──────────────────────────────────────────────────────────────────┤
│ %ScrapedCase{                                                     │
│   regulator_id: "HSE_123456",                                     │
│   offender_name: "ACME CONSTRUCTION LIMITED",                     │
│   offence_action_date: ~D[2024-03-15],  ← Utility.iso_date/1     │
│   offender_local_authority: "Westminster",                        │
│   offender_main_activity: "Construction of buildings",            │
│   offence_fine: #Decimal<25000.00>,     ← MonetaryParser         │
│   offence_costs: #Decimal<3500.00>,                               │
│   offence_result: "Guilty",                                       │
│   regulator_function: "CONSTRUCTION DIVISION"                     │
│ }                                                                 │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ STEP 3: PROCESSING (CaseProcessor)                               │
├──────────────────────────────────────────────────────────────────┤
│ %ProcessedCase{                                                   │
│   regulator_id: "HSE_123456",                                     │
│   agency_code: :hse,                    ← Hardcoded              │
│   offender_attrs: %{                                              │
│     name: "ACME CONSTRUCTION LIMITED",                            │
│     local_authority: "Westminster",                               │
│     main_activity: "Construction of buildings",                   │
│     business_type: :limited_company    ← BusinessTypeDetector    │
│   },                                                              │
│   offence_result: "Guilty",                                       │
│   offence_fine: #Decimal<25000.00>,                               │
│   offence_costs: #Decimal<3500.00>,                               │
│   offence_action_date: ~D[2024-03-15],                            │
│   regulator_function: "Construction Division", ← upcase_first    │
│   regulator_url: "https://resources.hse.gov.uk/...",             │
│   offence_action_type: "Court Case"                               │
│ }                                                                 │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ STEP 4: OFFENDER MATCHING (Offender.find_or_create_offender/1)  │
├──────────────────────────────────────────────────────────────────┤
│ 1. Exact match check: WHERE name = ? AND postcode = ?            │
│    → No match found                                               │
│                                                                   │
│ 2. Fuzzy search: similarity("acme construction limited") > 0.3   │
│    → No similar offenders                                         │
│                                                                   │
│ 3. Create new:                                                    │
│    INSERT INTO offenders (                                        │
│      id, name, normalized_name, local_authority,                 │
│      main_activity, business_type                                │
│    ) VALUES (                                                     │
│      'uuid-1', 'ACME CONSTRUCTION LIMITED',                       │
│      'acme construction limited', 'Westminster',                  │
│      'Construction of buildings', 'limited_company'               │
│    )                                                              │
│                                                                   │
│ → Returns: offender_id = 'uuid-1'                                │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ STEP 5: CASE CREATION (Ash.create/2)                             │
├──────────────────────────────────────────────────────────────────┤
│ INSERT INTO cases (                                               │
│   id, regulator_id, agency_id, offender_id,                      │
│   offence_result, offence_fine, offence_costs,                   │
│   offence_action_date, regulator_function, regulator_url,        │
│   offence_action_type                                             │
│ ) VALUES (                                                        │
│   'uuid-case', 'HSE_123456', 'uuid-agency-hse', 'uuid-1',        │
│   'Guilty', 25000.00, 3500.00,                                   │
│   '2024-03-15', 'Construction Division',                          │
│   'https://resources.hse.gov.uk/...',                             │
│   'Court Case'                                                    │
│ )                                                                 │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ FINAL DATABASE STATE                                             │
├──────────────────────────────────────────────────────────────────┤
│ offenders:                                                        │
│   - ACME CONSTRUCTION LIMITED (Westminster, limited_company)     │
│                                                                   │
│ cases:                                                            │
│   - HSE_123456: Guilty, £25,000 fine + £3,500 costs (2024-03-15) │
│                                                                   │
│ agencies:                                                         │
│   - HSE (Health and Safety Executive)                            │
└──────────────────────────────────────────────────────────────────┘
```

---

## See Also

- **[DEVELOPMENT_WORKFLOW.md](DEVELOPMENT_WORKFLOW.md)** - Day-to-day development process
- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Testing patterns for data pipelines
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common scraping and parsing issues
- **[../CLAUDE.md](../CLAUDE.md)** - Ash Framework critical rules and patterns

---

**Last Updated**: 2025-11-07
**Maintainer**: Development Team

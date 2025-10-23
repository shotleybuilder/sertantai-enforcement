# Scraping Architecture Analysis: EA vs HSE Case and Notice Implementations

## Executive Summary

The EHS Enforcement application implements scraping pipelines for two UK regulatory agencies (HSE and EA) with fundamentally different data collection patterns. While the architectures diverge significantly in HTTP approach (pagination vs. date-ranges), there is substantial duplication within each agency between case and notice scraping implementations.

**Key Finding**: Consolidation opportunities exist primarily within each agency (EA-to-EA, HSE-to-HSE) rather than across agencies, due to fundamental differences in their data collection mechanisms.

---

## Part 1: Agency-Level Architectural Differences

### HSE Pattern: Page-Based Pagination
- **HTTP Mechanism**: Incremental page requests (1, 2, 3, ..., N)
- **Databases**: Multiple databases ("convictions", "notices", "appeals")
- **Rate Limiting**: 3-second pause between pages
- **Early Stop Logic**: If all cases on current page exist, stop pagination
- **Two-Phase Processing**: 
  1. Stage 1: Fetch basic case info from summary page
  2. Stage 2: Enrich with detail page (breach info, related cases, costs)

### EA Pattern: Date-Range Based, Single Request
- **HTTP Mechanism**: Single request returns ALL matching records
- **Action Type Filtering**: `:court_case`, `:caution`, `:enforcement_notice`
- **Date Range Filtering**: `date_from` and `date_to` parameters
- **Two-Stage Processing**:
  1. Stage 1: Collect summary records (single request per action type)
  2. Stage 2: Fetch detail page for each record with per-record delay

**Key Difference**: HSE loops through pages; EA fetches all at once then processes individually.

---

## Part 2: EA Implementation Analysis

### EA Case vs Notice Scraping

**File Comparison**:
- Case: `lib/ehs_enforcement/scraping/ea/case_scraper.ex` (603 lines)
- Notice: `lib/ehs_enforcement/scraping/ea/notice_scraper.ex` (231 lines)

#### What's Similar
1. **Action Type Filtering**: Both use the same two-stage scraping pattern
2. **Detail Page Fetching**: Both fetch individual detail records with delays
3. **HTML Parsing**: Both parse the same EA detail page structure
4. **Date Range Support**: Both accept date_from/date_to parameters

#### What's Different
1. **Scraper Responsibility**:
   - CaseScraper: Implements full two-stage scraping (summary + detail collection)
   - NoticeScraper: **Thin wrapper** around CaseScraper for enforcement_notice action type only

2. **Code Duplication**:
   - NoticeScraper delegates entirely to CaseScraper
   - Only 3 public functions in NoticeScraper:
     - `collect_summary_records/3` → wraps `CaseScraper.collect_summary_records_for_action_type/4`
     - `fetch_detail_record/2` → wraps `CaseScraper.fetch_detail_record_individual/2`
     - `collect_and_enrich_notices/3` → orchestrates both functions

#### Duplication Score: **LOW** for Scrapers (Good Pattern!)
The NoticeScraper is already a well-designed wrapper. No significant consolidation needed here.

### EA Case vs Notice Processing

**File Comparison**:
- Case Processor: `lib/ehs_enforcement/scraping/ea/case_processor.ex` (695 lines)
- Notice Processor: `lib/ehs_enforcement/scraping/ea/notice_processor.ex` (708 lines)

#### What's Similar
1. **Offender Attributes Building**: Nearly identical business logic
2. **Metadata Creation**: Same pattern for source metadata
3. **Environmental Data Handling**: Both extract water/land/air impact
4. **Legal Framework Processing**: Both handle act/section extraction
5. **Error Handling**: Duplicate detection patterns are identical
6. **Ash Resource Creation**: Both use Ash patterns for resource creation

#### What's Different
1. **Output Structure**:
   - CaseProcessor: Produces `ProcessedEaCase` with:
     - `offence_fine`, `offence_costs`, `offence_breaches`
     - `ea_event_reference`, `is_ea_multi_violation`
   - NoticeProcessor: Produces `ProcessedEaNotice` with:
     - `notice_date`, `operative_date`, `compliance_date`
     - `notice_body`, `notice_date`

2. **Multi-Violation Handling** (Cases only):
   - CaseProcessor detects multi-violation scenarios
   - Creates both Case and Violation resources
   - NoticeProcessor handles single notice per record

3. **Legislation Linking** (Notices only):
   - `process_ea_legislation/1` - EA-specific feature
   - Legislation deduplication and offence linking

#### Common Code Blocks Identified

**Offender Attributes Building** (Lines duplicated):
```elixir
# CaseProcessor.build_ea_offender_attrs/1 - 24 lines
# NoticeProcessor.build_offender_attrs/1 - 34 lines (similar structure)
```

**Environmental Data Extraction**:
```elixir
# CaseProcessor.assess_environmental_impact/1 - 8 lines
# NoticeProcessor.build_environmental_impact/1 - 14 lines (same logic)

# CaseProcessor.detect_primary_receptor/1 - 10 lines  
# NoticeProcessor.detect_environmental_receptor/1 - 9 lines (nearly identical)
```

**Industry Mapping**:
```elixir
# CaseProcessor.map_ea_industry_to_hse_category/1 - 13 lines
# NoticeProcessor (not implemented - could extract)
```

**Legal Reference Building**:
```elixir
# CaseProcessor.build_legal_reference/1 - 7 lines
# NoticeProcessor.extract_legal_act/1 - 13 lines (similar intent)
```

**Source Metadata**:
```elixir
# CaseProcessor.build_ea_source_metadata/1 - 6 lines
# NoticeProcessor.build_source_metadata/1 - 7 lines (nearly identical)
```

#### Duplication Score: **MEDIUM-HIGH**
Approximately 15-20% of code is duplicated between processors. Environmental data extraction and offender attributes would benefit from consolidation.

---

## Part 3: HSE Implementation Analysis

### HSE Case vs Notice Scraping

**File Comparison**:
- Case Scraper: `lib/ehs_enforcement/scraping/hse/case_scraper.ex` (556 lines)
- Notice Scraper: `lib/ehs_enforcement/scraping/hse/notice_scraper.ex` (221 lines)

#### What's Similar
1. **Basic Scraping Pattern**: Both fetch paginated lists
2. **HTML Parsing**: Both parse table rows from HSE website
3. **URL Construction**: Both build HSE URLs with query parameters
4. **Rate Limiting**: Both use RateLimiter module

#### What's Different
1. **Database Routing**:
   - CaseScraper: Single "convictions" database
   - NoticeScraper: Hardcoded "notices" database URL
   - No database parameter in NoticeScraper

2. **Detail Enrichment**:
   - CaseScraper: Fetches full case details (4 HTTP calls: basic + details + breaches + related)
   - NoticeScraper: Fetches notice details (2 HTTP calls: basic + details + breaches)

3. **Table Structure**:
   - CaseScraper parses: [Case#, Name, Date, LA, Activity]
   - NoticeScraper parses: [Notice#, Name, Type, Date, LA, SIC]

4. **Breach Handling**:
   - CaseScraper: Complex - single or multiple breaches, plus related cases
   - NoticeScraper: Simple - just list of breaches

#### Code Overlap Analysis

**URL Building** (Similar patterns):
- Both use `~s|https://resources.hse.gov.uk|` base URL
- Both construct query strings with filters
- Could extract to shared module

**HTML Parsing**:
```elixir
# CaseScraper.parse_cases_from_html/2 - extracts and parses rows
# NoticeScraper (inline in get_hse_notices/2) - similar table extraction
```

**Monetary Parsing**:
```elixir
# CaseScraper.parse_monetary_amount/1 - 9 lines
# (not needed in NoticeScraper - no monetary data)
```

**Business Type Detection**:
```elixir
# Both CaseProcessor and NoticeProcessor implement:
determine_business_type/1 - 7 lines (IDENTICAL code)
normalize_business_type/1 - 8 lines (IDENTICAL code)
```

#### Duplication Score: **LOW-MEDIUM** for Scrapers
NoticeScraper is simpler and doesn't duplicate much. However, there's significant opportunity for HTML parsing abstraction.

### HSE Case vs Notice Processing

**File Comparison**:
- Case Processor: `lib/ehs_enforcement/scraping/hse/case_processor.ex` (466 lines)
- Notice Processor: `lib/ehs_enforcement/scraping/hse/notice_processor.ex` (322 lines)

#### What's Similar
1. **Business Type Detection**: Completely identical logic (7 lines)
2. **Business Type Normalization**: Completely identical logic (8 lines)
3. **Date Parsing**: Nearly identical multi-format parsing
4. **Offender Attributes**: Similar structure (name, LA, industry, activity)
5. **Regulator URL Building**: Same HSE domain patterns
6. **Source Metadata**: Same pattern
7. **Breach Formatting**: Both handle breach lists

#### Code Duplication Identified

**Business Type Detection** (EXACT DUPLICATE):
```elixir
# CaseProcessor.determine_business_type/1 (lines 423-433)
# NoticeProcessor.determine_business_type/1 (lines 310-320)
# IDENTICAL implementation - 7 lines

# CaseProcessor.normalize_business_type/1 (lines 378-389)
# NoticeProcessor.normalize_business_type/1 (lines 297-308)
# IDENTICAL implementation - 8 lines
```

**Date Parsing** (MOSTLY DUPLICATE):
```elixir
# CaseProcessor doesn't need date parsing (uses from scraper)
# NoticeProcessor.parse_date/1 - 12 lines
# NoticeProcessor.try_parse_date_formats/1 - 13 lines
# NoticeProcessor.try_parse_dash_format/1 - 13 lines
# NoticeProcessor.try_parse_iso_format/1 - 13 lines
# Total: 51 lines of multi-format date parsing
```

**Offender Attributes Building** (SIMILAR):
```elixir
# CaseProcessor.build_offender_attrs/1 - 16 lines
# NoticeProcessor.build_offender_attrs/1 - 19 lines
# Structure is similar but handles different fields (SIC vs. industry)
```

**Regulator URL Building**:
```elixir
# CaseProcessor.build_regulator_url/1 - 1 line (uses "convictions")
# NoticeProcessor.build_regulator_url/1 - 2 lines (uses "notices")
# Nearly identical, just swaps database name
```

**Breach Formatting** (SIMILAR):
```elixir
# CaseProcessor.process_breaches_locally/1 - 20 lines
# NoticeProcessor.format_breaches/1 - 15 lines
# Similar intent, slightly different implementation
```

#### Duplication Score: **HIGH**
Approximately 25-30% duplicated code between case and notice processors.

---

## Part 4: LiveView Handler Duplication

### Case vs Notice Scraping UI

**File Comparison**:
- Case Scrape LiveView: `lib/ehs_enforcement_web/live/admin/case_live/scrape.ex` (1,279 lines)
- Notice Scrape LiveView: `lib/ehs_enforcement_web/live/admin/notice_live/scrape.ex` (1,124 lines)

#### What's Identical

**Lifecycle Management**:
```elixir
mount/3
  - Progress tracking structure: identical
  - Session state: identical
  - keep_live subscriptions: nearly identical
  - PubSub subscriptions: nearly identical

handle_event("stop_scraping", ...) - identical logic
handle_event("clear_results", ...) - identical pattern
handle_event("clear_progress", ...) - identical structure
```

**Progress Update Handlers**:
```elixir
handle_info({:started, data}, socket) - same structure
handle_info({:page_started, data}, socket) - same pattern
handle_info({:page_completed, data}, socket) - nearly identical
handle_info({:completed, data}, socket) - same
handle_info({:scraping_failed, reason}, socket) - identical
handle_info({:DOWN, ...}, socket) - identical
```

**Helper Functions**:
```elixir
update_progress/2 - IDENTICAL (7 lines)
broadcast_scraping_event/2 - IDENTICAL (2 lines)
should_enable_real_time_progress?/1 - IDENTICAL (3 lines)
duplicate_error?/1 - IDENTICAL (13 lines)
extract_progress_from_session/1 - NEAR-IDENTICAL (structure differs for notice/case terminology)
handle_scrape_session_update/2 - SIMILAR (notice version maps "cases_*" to "notices_*")
```

#### What's Different

**Form Defaults**:
```elixir
# CaseProcessor: "convictions" database, start_page/end_page
# NoticeProcessor: "notices" database, same pages OR date_from/date_to for EA

# Case: selected_agency not needed (HSE only in CaseLive)
# Notice: selected_agency tracking for HSE vs EA switching
```

**Event Handlers**:
```elixir
# CaseProcessor.handle_event("validate", ...) - forces "convictions" database
# NoticeProcessor.handle_event("validate", ...) - sets agency-specific defaults dynamically

# CaseProcessor.handle_event("submit", ...) - routes HSE vs EA
# NoticeProcessor.handle_event("submit", ...) - routes HSE vs EA with different params
```

**Scraping Implementation**:
```elixir
# Cases:
  scrape_cases_with_session/2 - HSE-specific
  process_single_case_simple/4 - HSE case processing

# Notices:
  scrape_notices_with_session/2 - HSE notices
  scrape_ea_notices_with_session/2 - EA notices (different logic!)
  process_single_notice_simple/4 - HSE notice processing
  process_ea_notice_and_update_session/4 - EA notice processing
```

#### Duplication Score: **VERY HIGH**
Approximately 60-70% of code is duplicated between case and notice LiveViews. This is the highest duplication area in the codebase.

---

## Part 5: Detailed Duplication Tables

### EA Implementation Duplication

| Component | Files | Duplication Type | Lines | Impact |
|-----------|-------|------------------|-------|--------|
| HTML Parsing | CaseScraper, NoticeScraper | Thin wrapper | 50 (notice) | LOW - Good design |
| Environmental Data | CaseProcessor, NoticeProcessor | Code blocks | 30-40 | MEDIUM |
| Offender Attributes | CaseProcessor, NoticeProcessor | Similar logic | 30-40 | MEDIUM |
| Legal Reference | CaseProcessor, NoticeProcessor | Code blocks | 15-20 | MEDIUM |
| Business Type | CaseProcessor, NoticeProcessor | IDENTICAL | 15 | HIGH |
| Source Metadata | CaseProcessor, NoticeProcessor | Nearly identical | 10-15 | MEDIUM |
| **Total** | | | **150-200** | **MEDIUM** |

**Consolidation Cost**: Medium effort; High payoff

---

### HSE Implementation Duplication

| Component | Files | Duplication Type | Lines | Impact |
|-----------|-------|------------------|-------|--------|
| HTML Parsing | CaseScraper, NoticeScraper | Different tables | 100-150 | LOW |
| Business Type Detection | CaseProcessor, NoticeProcessor | IDENTICAL | 15 | HIGH |
| Business Type Normalization | CaseProcessor, NoticeProcessor | IDENTICAL | 8 | HIGH |
| Date Parsing | NoticeProcessor (internal) | Not duplicated | 50 | N/A |
| Offender Attributes | CaseProcessor, NoticeProcessor | Similar logic | 30-40 | MEDIUM |
| Regulator URL | CaseProcessor, NoticeProcessor | Nearly identical | 5-10 | MEDIUM |
| Source Metadata | CaseProcessor, NoticeProcessor | Nearly identical | 10-15 | MEDIUM |
| Breach Handling | CaseProcessor, NoticeProcessor | Similar logic | 25-30 | MEDIUM |
| **Processor Total** | | | **140-180** | **MEDIUM-HIGH** |
| **LiveView Total** | Case, Notice | Nearly entire modules | 900-1000 | **VERY HIGH** |
| **Grand Total** | | | **1000-1200** | **VERY HIGH** |

**Consolidation Cost**: High effort; Very high payoff (especially LiveView)

---

## Part 6: Consolidation Recommendations

### Within EA Agency

#### Quick Win 1: Extract EA Environmental Data Helper (30 mins)
```
Location: lib/ehs_enforcement/agencies/ea/data_helpers.ex (NEW)

Functions to extract:
- extract_environmental_impact/1 (from both processors)
- detect_primary_receptor/1 (from both processors)
- assess_environmental_impact/1 (rename from case processor)

Impact: Eliminates 30-40 lines of duplication
Usage: EA.CaseProcessor, EA.NoticeProcessor
```

#### Quick Win 2: Extract EA Offender Attributes Builder (20 mins)
```
Location: lib/ehs_enforcement/agencies/ea/offender_builder.ex (or reuse existing OffenderMatcher)

Functions to extract:
- build_offender_attrs/1 (normalized version)
- build_full_address/1 (from case processor)
- determine_business_type/1 (if not already shared)

Impact: Eliminates 30-40 lines of duplication
Usage: EA.CaseProcessor, EA.NoticeProcessor
```

#### Quick Win 3: Extract EA Legal Reference Processing (20 mins)
```
Location: lib/ehs_enforcement/agencies/ea/legal_reference.ex (NEW)

Functions to extract:
- build_legal_reference/1
- extract_legal_act/1
- extract_legal_section/1
- extract_year_from_ea_act/1

Impact: Eliminates 30-50 lines of duplication
Usage: EhsEnforcement.Agencies.Ea module
```

---

### Within HSE Agency

#### Quick Win 1: Extract Shared Business Type Logic (15 mins)
```
Location: lib/ehs_enforcement/utilities/business_type_detector.ex (NEW)

Functions to extract:
- determine_business_type/1 (IDENTICAL in both)
- normalize_business_type/1 (IDENTICAL in both)

Impact: Eliminates 23 lines of EXACT duplication
Usage: HSE.CaseProcessor, HSE.NoticeProcessor, EA.CaseProcessor, EA.NoticeProcessor
```

#### Medium Task 1: Extract HSE Date Parser (1 hour)
```
Location: lib/ehs_enforcement/utilities/date_parser.ex (EXTEND if exists)

Functions to extract:
- parse_date/1
- try_parse_date_formats/1
- try_parse_dash_format/1
- try_parse_iso_format/1

Impact: Makes date parsing reusable across all processors
Usage: HSE.NoticeProcessor, EA.NoticeProcessor
```

#### Medium Task 2: Extract HSE Offender Attributes Builder (1 hour)
```
Location: lib/ehs_enforcement/agencies/hse/offender_builder.ex (NEW)

Functions to extract:
- build_offender_attrs/1 (case processor version)
- normalize for notice processor to use

Impact: Eliminates 30-40 lines of similar code
Usage: HSE.CaseProcessor, HSE.NoticeProcessor
```

#### Large Task 1: Consolidate LiveView Handlers (4-6 hours)
```
Strategy: Create base LiveView module for scraping UI

lib/ehs_enforcement_web/live/admin/scrape_base_live.ex
  - Shared mount/3
  - Shared event handlers (validate, submit, stop_scraping, clear_*)
  - Shared info handlers
  - Shared helper functions

Then:
lib/ehs_enforcement_web/live/admin/case_live/scrape.ex
  → Delegates to base module, overrides agency-specific parts

lib/ehs_enforcement_web/live/admin/notice_live/scrape.ex
  → Delegates to base module, overrides agency-specific parts

Impact: Eliminates 900-1000 lines of 60-70% duplicated code
Complexity: High - needs careful module design
```

---

## Part 7: Architectural Comparison Matrix

| Aspect | EA | HSE |
|--------|----|----|
| **Pagination Strategy** | Single request per action type | Incremental page-based |
| **API Calls per Record** | 2 (summary → detail) | 2-4 (basic → details → breach → related) |
| **Rate Limiting** | Per-record delay (3s default) | Per-page delay (3s) |
| **Early Stop Logic** | None | Check if all current page exist |
| **Scraper Duplication** | LOW (good wrapper pattern) | LOW-MEDIUM |
| **Processor Duplication** | MEDIUM (15-20%) | MEDIUM-HIGH (25-30%) |
| **LiveView Duplication** | VERY HIGH (60-70% shared) | VERY HIGH (60-70% shared) |
| **Consolidation Priority** | Medium (data extraction) | High (LiveView + processors) |

---

## Part 8: Code Examples of Key Duplications

### Example 1: Identical Business Type Logic (HSE)

**CaseProcessor** (lines 423-433):
```elixir
defp determine_business_type(offender_name) do
  cond do
    Regex.match?(~r/LLC|llc/, offender_name) -> "LLC"
    Regex.match?(~r/[Ii]nc$/, offender_name) -> "INC"
    Regex.match?(~r/[ ][Cc]orp[. ]/, offender_name) -> "CORP"
    Regex.match?(~r/PLC|[Pp]lc/, offender_name) -> "PLC"
    Regex.match?(~r/[Ll]imited|LIMITED|Ltd|LTD|Lld/, offender_name) -> "LTD"
    Regex.match?(~r/LLP|[Ll]lp/, offender_name) -> "LLP"
    true -> "SOLE"
  end
end
```

**NoticeProcessor** (lines 310-320):
```elixir
defp determine_business_type(offender_name) when is_binary(offender_name) do
  cond do
    Regex.match?(~r/LLC|llc/, offender_name) -> "LLC"
    Regex.match?(~r/[Ii]nc$/, offender_name) -> "INC"
    Regex.match?(~r/[ ][Cc]orp[. ]/, offender_name) -> "CORP"
    Regex.match?(~r/PLC|[Pp]lc/, offender_name) -> "PLC"
    Regex.match?(~r/[Ll]imited|LIMITED|Ltd|LTD|Lld/, offender_name) -> "LTD"
    Regex.match?(~r/LLP|[Ll]lp/, offender_name) -> "LLP"
    true -> "SOLE"
  end
end
```

**Status**: 100% Duplicated - Easy refactor

---

### Example 2: Similar Environmental Data (EA)

**CaseProcessor.assess_environmental_impact/1** (8 lines):
```elixir
defp assess_environmental_impact(%EaDetailRecord{} = ea_record) do
  impacts = [ea_record.water_impact, ea_record.land_impact, ea_record.air_impact]
  cond do
    Enum.any?(impacts, &(&1 == "major")) -> "major"
    Enum.any?(impacts, &(&1 == "minor")) -> "minor"
    true -> "none"
  end
end
```

**NoticeProcessor.build_environmental_impact/1** (14 lines):
```elixir
defp build_environmental_impact(ea_detail_record) do
  impacts = [
    Map.get(ea_detail_record, :water_impact),
    Map.get(ea_detail_record, :land_impact),
    Map.get(ea_detail_record, :air_impact)
  ]
  |> Enum.filter(&(&1 != nil && &1 != ""))
  |> Enum.join("; ")
  case impacts do
    "" -> nil
    impact_str -> impact_str
  end
end
```

**Status**: Different implementations of same concept - needs standardization

---

## Part 9: Cross-Agency Consolidation Opportunities

### Shared Utilities (Not Agency-Specific)

1. **Business Type Detection** (15 lines)
   - Identical in HSE.CaseProcessor, HSE.NoticeProcessor
   - Nearly identical in EA.CaseProcessor, EA.NoticeProcessor
   - **File**: `lib/ehs_enforcement/utilities/business_type_detector.ex`

2. **Date Parsing** (50 lines)
   - Used in HSE.NoticeProcessor
   - Could be used in EA.NoticeProcessor
   - **File**: `lib/ehs_enforcement/utilities/date_parser.ex`

3. **Monetary Amount Parsing** (10 lines)
   - Used in HSE.CaseScraper and EA.CaseScraper
   - **File**: `lib/ehs_enforcement/utilities/monetary_parser.ex`

4. **Session/Progress Management** (100+ lines)
   - Identical logic in CaseLive.Scrape and NoticeLive.Scrape
   - Could be extracted to base module

---

## Part 10: Summary Table of Opportunities

| Opportunity | Effort | Impact | Agency | Files Affected |
|-------------|--------|--------|--------|-----------------|
| Extract business type logic | 30 mins | HIGH | Both | CaseProc, NoticeProc (4 files) |
| Extract date parser | 1 hour | MEDIUM | HSE/EA | NoticeProc (2 files) |
| Extract EA environmental helpers | 30 mins | MEDIUM | EA | CaseProc, NoticeProc (2 files) |
| Extract offender builders | 2 hours | MEDIUM | Both | CaseProc, NoticeProc (4 files) |
| Consolidate LiveView handlers | 4-6 hours | VERY HIGH | Both | CaseLive, NoticeLive (2 files) |
| Extract monetary parsing | 30 mins | MEDIUM | Both | Scrapers (2 files) |
| **TOTAL** | **8-10 hours** | **VERY HIGH** | **Both** | **16+ files** |

---

## Part 11: Implementation Priority

### Phase 1: Quick Wins (2-3 hours)
1. Extract business type logic → `utilities/business_type_detector.ex`
2. Extract monetary parser → `utilities/monetary_parser.ex`
3. Extract EA environmental helpers → `agencies/ea/data_helpers.ex`

### Phase 2: Medium Effort (2-3 hours)
4. Extract date parser → `utilities/date_parser.ex`
5. Extract offender builders → `agencies/{ea,hse}/offender_builder.ex`

### Phase 3: High Impact (4-6 hours)
6. Consolidate LiveView handlers → Create base module architecture

---

## Conclusion

### Within-Agency Consolidation (Recommended)
- **EA**: Extract environmental data and legal reference processing (30-50 lines saved)
- **HSE**: Extract business type logic, consolidate processor patterns (150+ lines saved)

### Cross-Agency Consolidation
- Business type detection (shared utility - 15 lines)
- Date parsing (shared utility - 50 lines)
- Monetary parsing (shared utility - 10 lines)
- **Total Shared Code**: ~75 lines across both agencies

### LiveView Consolidation (Highest Impact)
- Create base scraping UI module to eliminate 60-70% duplication
- 900-1000 lines of duplicated code across 2 LiveView files
- Highest payoff despite higher complexity

### Final Recommendation
**Start with quick wins (Phase 1)**, then move to **LiveView consolidation (Phase 3)** which provides the highest return on investment. The processor and scraper consolidations are good for maintainability but provide less dramatic improvements.


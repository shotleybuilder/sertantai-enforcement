# HSE Case Scraping Implementation Plan

## Overview
Build a complete HSE case scraping system that creates new refactored namespaces and saves data directly to PostgreSQL via Ash resources. This system replaces the legacy Airtable-based workflow and supports both manual admin-triggered scraping and automated scheduled scraping.

## ⚠️ CRITICAL: PostgreSQL-First Architecture

**WE ARE MIGRATING AWAY FROM AIRTABLE STORAGE**
- Production Airtable data will be migrated to PostgreSQL when app goes live
- **NEW SCRAPING SYSTEM SAVES DIRECTLY TO POSTGRESQL** via Ash resources
- **DO NOT USE LEGACY AIRTABLE INTEGRATION CODE** from existing HSE modules
- Legacy `Post.post(@base, @table, cases)` and `Patch.patch(@base, @table, kase)` calls are **FORBIDDEN**
- Use only `EhsEnforcement.Enforcement.create_case/1` and Ash resource patterns

## Phase 1: Core Infrastructure

  ### 1.1 Scraping Service Layer
  - **Create**: `lib/ehs_enforcement/scraping/hse/case_scraper.ex`
    - Refactored version of existing `CaseScraper`
    - Clean interface for fetching HSE cases by page or ID
    - Proper error handling and retry logic
    - Built-in duplicate detection

  ### 1.2 Processing Pipeline
  - **Create**: `lib/ehs_enforcement/scraping/hse/case_processor.ex`
    - Handles data transformation from HSE format to Ash resource format
    - Integrates with existing `Breaches` module for legislation linking
    - Offender matching/creation logic using existing `OffenderMatcher`

  ### 1.3 Scraping Coordination
  - **Create**: `lib/ehs_enforcement/scraping/scrape_coordinator.ex`
    - Orchestrates the scraping process
    - Implements "stop when 10 consecutive existing records found" logic
    - Tracks scraping progress and metrics
    - Handles error recovery

## Phase 2: User Interface

  ### 2.1 Admin Case Management Routes
  - **Update**: Router to add `/admin/cases` routes
  - **Create**: `lib/ehs_enforcement_web/live/admin/case_live/scrape.ex`
    - Manual scraping trigger interface
    - Real-time progress display using Phoenix PubSub
    - Scraping configuration (page ranges, etc.)
    - Results summary and error reporting

  ### 2.2 Scraping Management UI
  - **Create**: `lib/ehs_enforcement_web/live/admin/scraping_live/index.ex`
    - View scraping history and status
    - Schedule management interface
    - Manual trigger controls
    - Performance metrics dashboard

## Phase 3: Automated Scheduling (SIMPLIFIED WITH ASHOBAN)

  ### 3.1 AshOban Integration
  - **Add**: `ash_oban` dependency to `mix.exs`
  - **Configure**: Oban triggers on Case resource for scheduled scraping
  - **Define**: Cron-based scheduling with error handling actions
  - **Implement**: Background job processing for scraping operations

  ### 3.2 Application Integration
  - **Update**: `application.ex` to start Oban worker
  - **Configure**: Oban queues and job processing settings

## Phase 4: Database Integration

  ### 4.1 Case Creation Enhancement
  - **Enhance**: Existing `Case` resource with scraping-specific actions
  - **Create**: `duplicate_detection` action for efficient checking
  - **Create**: `bulk_create` action for batch processing

  ### 4.2 Scraping Audit Trail (SIMPLIFIED WITH ASHEVENTS)
  - **Add**: `ash_events` dependency for automatic audit trail
  - **Configure**: Event tracking on Case resource actions
  - **Implement**: Metadata capture for scraping context
  - **Optional**: Custom event resource for additional scraping metrics

## Phase 5: Data Flow & Logic

  ### 5.1 Scraping Flow (PostgreSQL-Only)
  1. **Trigger**: Admin clicks scrape button or scheduled time arrives
  2. **Initialize**: Create scrape tracking event via AshEvents, broadcast start event
  3. **Page Processing**: Start from page 1, process each page from HSE website
  4. **Duplicate Detection**: Check if `regulator_id` exists in PostgreSQL via Ash.read()
  5. **Stop Condition**: When 10 consecutive existing cases found on a page, stop
  6. **Data Creation**: Create cases via `EhsEnforcement.Enforcement.create_case/1` **ONLY**
  7. **Progress Updates**: Broadcast real-time updates via PubSub
  8. **Completion**: Final metrics captured via AshEvents, broadcast completion

  **⚠️ CRITICAL**: All data persistence goes through Ash resources to PostgreSQL.
  **NO AIRTABLE CALLS** in this flow.

  ### 5.2 Error Handling
  - Network timeouts with exponential backoff
  - HTML parsing errors with logging and continuation
  - Database conflicts handled gracefully
  - Admin notifications for critical failures

## Phase 6: Configuration & Settings

  ### 6.1 Scraping Configuration
  - **Create**: Config for HSE endpoints, rate limiting, schedules
  - **Create**: Feature flags for enabling/disabling scheduled scraping
  - Admin interface for modifying scraping settings

## Recommended Ash Extensions

After reviewing available extensions at ash-hq.org, the following would significantly enhance the HSE case scraping system:

### 1. AshOban (HIGHLY RECOMMENDED)
**Why**: Perfect replacement for our planned GenServer-based scheduling
**Benefits**:
- **Declarative scheduling**: Define scraping triggers directly on Case resource with cron expressions
- **Built-in error handling**: Automatic retry logic and error action routing
- **Reliability**: Oban's proven job processing with persistence and recovery
- **Actor persistence**: Maintain admin user context across scheduled jobs

**Implementation**:
```elixir
# In Case resource
oban do
  triggers do
    trigger :scheduled_scrape do
      action :scrape_hse_cases
      scheduler_cron "0 2 * * *"  # Daily at 2 AM
      on_error :handle_scrape_error
    end
  end
end
```

**Impact**: Eliminates need for custom `ScheduledScraper` GenServer, provides enterprise-grade job processing

### 2. AshEvents (RECOMMENDED)
**Why**: Perfect for audit trail and scraping operation tracking
**Benefits**:
- **Automatic audit trail**: Every case creation/update logged with metadata
- **Scraping context**: Track which scraping session created each record
- **Event replay**: Reconstruct data state and debug scraping issues
- **Compliance**: Built-in data lineage for regulatory requirements

**Implementation**:
```elixir
# Capture scraping metadata automatically
context: %{ash_events_metadata: %{
  scrape_run_id: scrape_run.id,
  source_page: page_number,
  scraping_user: admin_user.id
}}
```

**Impact**: Replaces need for custom `ScrapeRun` resource, provides richer audit capabilities

### 3. AshRateLimiter (RECOMMENDED)
**Why**: Essential for responsible web scraping
**Benefits**:
- **HSE website protection**: Prevent overwhelming external servers
- **Declarative rate limiting**: Configure directly on scraping actions
- **Flexible controls**: Different limits for manual vs scheduled scraping
- **Automatic enforcement**: No custom throttling logic needed

**Implementation**:
```elixir
# In scraping actions
rate_limit do
  action :scrape_page,
    limit: 10,  # 10 pages
    per: :timer.minutes(1),  # per minute
    key: fn _changeset, _context -> "hse_scraping" end
end
```

**Impact**: Eliminates need for custom rate limiting logic, ensures ethical scraping

### 4. AshJsonApi (OPTIONAL)
**Why**: Could enable programmatic access to scraping controls
**Benefits**:
- **API endpoints**: Allow external tools to trigger scraping
- **Integration**: Enable other systems to monitor scraping status
- **Standardization**: JSON:API compliant endpoints

**Impact**: Provides additional integration options beyond web UI

## Updated Architecture with Extensions

### Simplified GenServer Approach
With AshOban, we can eliminate the custom `ScheduledScraper` GenServer and use:
- **AshOban triggers** for scheduled scraping
- **Oban jobs** for background processing
- **Built-in error handling** instead of custom retry logic

### Enhanced Audit Trail
With AshEvents, we get automatic tracking of:
- Every case creation with scraping context
- Data lineage and change history
- Debugging capabilities through event replay
- Compliance-ready audit logs

### Responsible Scraping
With AshRateLimiter, we ensure:
- Ethical scraping practices
- Website protection
- Configurable rate controls
- Automatic enforcement

## Key Implementation Details

### File Structure (Updated with Extensions)
```
lib/ehs_enforcement/
├── scraping/
│   ├── hse/
│   │   ├── case_scraper.ex      # HTTP scraping logic
│   │   └── case_processor.ex    # Data transformation
│   └── scrape_coordinator.ex    # Orchestration
├── enforcement/
│   └── resources/
│       └── case.ex              # Enhanced with AshOban triggers & rate limiting
```

### Extensions Added
- `ash_oban` - Replaces custom GenServer scheduling
- `ash_events` - Replaces custom audit trail resource
- `ash_rate_limiter` - Adds ethical scraping controls

### Namespace Strategy
- All new code under `EhsEnforcement.Scraping.*`
- Reuse existing `EhsEnforcement.Agencies.Hse.Breaches` and `CaseScraper` logic
- Clean separation from legacy `Legl.*` modules

### ASH Integration
- Use existing `Case` resource with enhanced actions
- Leverage existing `Offender` matching logic
- Proper actor-based permissions for admin-only operations

### Real-time Updates
- Phoenix PubSub for scraping progress
- LiveView updates for admin interface
- WebSocket-based progress bars and status

## Existing Code Analysis

### Current HSE Implementation (LEGACY - AIRTABLE-BASED)
The existing `lib/ehs_enforcement/agencies/hse/cases.ex` module provides:
- `HSECase` struct with all necessary fields
- `api_get_hse_cases/1` function for page-based scraping
- Integration with `CaseScraper.get_hse_cases/2` for HTTP requests
- `Breaches.enum_breaches/1` for legislation linking
- **⚠️ LEGACY**: Airtable integration for data storage - **DO NOT USE**

### Reusable Components (PostgreSQL-Safe)
- `EhsEnforcement.Agencies.Hse.CaseScraper` - HTTP scraping logic ✅
- `EhsEnforcement.Agencies.Hse.Breaches` - Legislation mapping ✅
- `EhsEnforcement.Agencies.Hse.Common` - Utility functions ✅
- `EhsEnforcement.Sync.OffenderMatcher` - Offender matching logic ✅

### Components to AVOID (Airtable-Dependent)
- `EhsEnforcement.Integrations.Airtable.Post` - **FORBIDDEN**
- `EhsEnforcement.Integrations.Airtable.Patch` - **FORBIDDEN**
- `EhsEnforcement.Integrations.Airtable.Get` - **FORBIDDEN**
- Any `@base` and `@table` constants - **LEGACY ONLY**

### Migration Strategy
1. **DO NOT MODIFY** existing code in `lib/ehs_enforcement/agencies/hse/`
2. **CREATE NEW** modules under `lib/ehs_enforcement/scraping/`
3. **REUSE ONLY** HTTP scraping and data processing logic (NO AIRTABLE CODE)
4. **INTEGRATE** exclusively with Ash resources and PostgreSQL persistence
5. **REPLACE** all `Post.post()` and `Patch.patch()` calls with `EhsEnforcement.Enforcement.create_case/1`

## Routes Structure

### Current Routes
- `/cases` - Public case listing (existing)
- `/cases/:id` - Public case details (existing)
- `/cases/new` - Admin case creation form (existing)

### New Admin Routes
- `/admin/cases` - Admin case management dashboard
- `/admin/cases/scrape` - Manual scraping interface
- `/admin/scraping` - Scraping management and history
- `/admin/scraping/schedule` - Schedule configuration

## Database Schema Considerations

### Existing Case Resource
The `EhsEnforcement.Enforcement.Case` resource already has:
- All necessary fields for HSE case data
- Relationships to `Agency` and `Offender`
- Actions for creation and updates
- Proper Ash integration

### New Scrape Run Resource
Will need:
- `id`, `started_at`, `completed_at`, `status`
- `pages_processed`, `cases_found`, `cases_created`, `cases_updated`
- `errors_count`, `error_details`
- `triggered_by` (admin user or scheduled)

## Data Persistence Strategy

### PostgreSQL-Only Architecture
- **Primary Storage**: PostgreSQL database via Ash resources
- **Case Creation**: `EhsEnforcement.Enforcement.create_case/1` exclusively
- **Offender Management**: `EhsEnforcement.Sync.OffenderMatcher.find_or_create_offender/1`
- **Audit Trail**: AshEvents automatic tracking
- **No Airtable**: Legacy `Post.post()`, `Patch.patch()`, `Get.get_id()` calls **FORBIDDEN**

### Migration Timeline
- **Phase 1**: Build PostgreSQL-only scraping system
- **Phase 2**: Production deployment with data migration from Airtable to PostgreSQL
- **Phase 3**: Legacy Airtable code removal (future cleanup)

This plan creates a robust, maintainable HSE case scraping system that integrates seamlessly with the existing architecture while following the project's ASH-first patterns and PostgreSQL-first data persistence strategy.

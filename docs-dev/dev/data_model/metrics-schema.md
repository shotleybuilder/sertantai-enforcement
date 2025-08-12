# Metrics Schema Documentation

## Overview

The `metrics` table stores pre-computed dashboard statistics to optimize page load performance. Instead of calculating metrics in real-time on every dashboard visit, metrics are cached and refreshed manually or via scheduled automation.

## Table: `metrics`

### Purpose
- Store cached dashboard statistics for different time periods
- Eliminate real-time calculations that were causing 3-5 second page loads
- Support manual refresh via admin interface and scheduled updates after scraping

### Schema Structure

```sql
CREATE TABLE metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  
  -- Time Period Configuration
  period TEXT NOT NULL,                    -- 'week', 'month', or 'year' 
  period_label TEXT NOT NULL,              -- Human readable: 'Last 7 Days', 'Last 30 Days', etc.
  days_ago BIGINT NOT NULL,                -- Number of days back: 7, 30, 365
  cutoff_date DATE NOT NULL,               -- Calculated cutoff date for filtering
  
  -- Core Statistics
  recent_cases_count BIGINT NOT NULL DEFAULT 0,      -- Cases within time period
  recent_notices_count BIGINT NOT NULL DEFAULT 0,    -- Notices within time period
  total_cases_count BIGINT NOT NULL DEFAULT 0,       -- All cases (lifetime)
  total_notices_count BIGINT NOT NULL DEFAULT 0,     -- All notices (lifetime)
  
  -- Financial Data
  total_fines_amount DECIMAL NOT NULL DEFAULT 0,     -- Sum of fines from recent cases
  
  -- Agency Data
  active_agencies_count BIGINT NOT NULL DEFAULT 0,   -- Number of enabled agencies
  agency_stats JSONB NOT NULL DEFAULT '{}',          -- Enhanced per-agency statistics
  
  -- Metadata
  calculated_at TIMESTAMP WITH TIME ZONE NOT NULL,   -- When metrics were computed
  calculated_by TEXT NOT NULL                        -- 'admin' or 'automation'
);
```

### Field Descriptions

#### Time Period Fields
- **`period`**: Enum value (`week`, `month`, `year`) identifying the time window
- **`period_label`**: Human-friendly label displayed in UI ("Last 7 Days", "Last 30 Days", "Last 365 Days")
- **`days_ago`**: Integer representing lookback period (7, 30, 365)
- **`cutoff_date`**: Computed date boundary for filtering recent records

#### Statistics Fields
- **`recent_cases_count`**: Count of court cases within the time period
- **`recent_notices_count`**: Count of enforcement notices within the time period  
- **`total_cases_count`**: Total count of all cases (lifetime, not filtered by date)
- **`total_notices_count`**: Total count of all notices (lifetime, not filtered by date)

#### Financial Fields
- **`total_fines_amount`**: Sum of `offence_fine` amounts from recent cases only (DECIMAL for precision)

#### Agency Fields
- **`active_agencies_count`**: Count of agencies where `enabled = true`
- **`agency_stats`**: JSONB containing enhanced per-agency breakdown for dashboard dropdown filtering:
  ```json
  {
    "agency_id_1": {
      "agency_id": "uuid",
      "agency_code": "HSE", 
      "agency_name": "Health and Safety Executive",
      "enabled": true,
      "case_count": 45,
      "notice_count": 23,
      "total_actions": 68,
      "total_fines": "125000.50",
      "case_percentage": 23.7,
      "action_percentage": 19.8
    },
    "agency_id_2": { ... }
  }
  ```

#### Metadata Fields
- **`calculated_at`**: Timestamp when metrics were computed (for cache freshness)
- **`calculated_by`**: Enum value (`admin`, `automation`) tracking who/what triggered the refresh

### Data Storage Pattern

The table stores **3 records at any time** (one per time period):

```
| period | period_label  | days_ago | recent_cases_count | calculated_by | calculated_at           |
|--------|---------------|----------|-------------------|---------------|-------------------------|
| week   | Last 7 Days   | 7        | 12                | admin         | 2024-01-11 10:30:00 UTC |
| month  | Last 30 Days  | 30       | 87                | admin         | 2024-01-11 10:30:00 UTC |
| year   | Last 365 Days | 365      | 1,245             | automation    | 2024-01-11 08:00:00 UTC |
```

### Refresh Strategy

#### Manual Refresh
- Triggered via "Refresh Metrics" button in Admin Quick Actions
- Calls `EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:admin)`
- Sets `calculated_by: :admin` in all created records
- Deletes existing records and recalculates all three periods

#### Scheduled Refresh  
- Runs after weekly scraping automation completes
- Calls `EhsEnforcement.Enforcement.Metrics.refresh_all_metrics(:automation)`
- Sets `calculated_by: :automation` in all created records
- Ensures dashboard reflects latest scraped data

#### Refresh Process
1. **Clear**: Delete all existing metrics records
2. **Calculate**: For each period (week, month, year):
   - Load all cases and notices
   - Filter by `offence_action_date >= cutoff_date`
   - Calculate aggregations (counts, sums, percentages)
   - Generate agency breakdown statistics
3. **Store**: Create new metrics records with calculated values
4. **Notify**: Broadcast PubSub message for LiveView updates

## Performance Impact

### Before (Real-time Calculation)
- **Dashboard load time**: 3-5 seconds
- **Database queries**: ~10+ queries loading all cases/notices on every page load
- **Memory usage**: High (processing thousands of records in Elixir)

### After (Cached Metrics)
- **Dashboard load time**: 300-500ms
- **Database queries**: 1-3 simple SELECT queries from metrics table
- **Memory usage**: Minimal (pre-computed results)

**Performance improvement: 5-10x faster**

## Ash Resource Integration

### Resource Definition
```elixir
defmodule EhsEnforcement.Enforcement.Metrics do
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer
end
```

### Key Actions
- **`:get_current`**: Read action to fetch current metrics for dashboard
- **`:refresh`**: Create action used during metric refresh process
- **`:destroy`**: Destroy action for clearing old metrics during refresh

### Code Interface
- `EhsEnforcement.Enforcement.get_current_metrics/1` - Get cached metrics
- `EhsEnforcement.Enforcement.Metrics.refresh_all_metrics/1` - Refresh all metrics
  - `refresh_all_metrics(:admin)` - Manual refresh via admin interface
  - `refresh_all_metrics(:automation)` - Scheduled refresh after scraping

## Usage in Dashboard

### Current Implementation (dashboard_live.ex)
```elixir
# Replace this expensive real-time calculation:
stats = calculate_stats(agencies, recent_cases, time_period)

# With this fast cached lookup:
cached_metrics = EhsEnforcement.Enforcement.get_current_metrics()
stats = format_cached_metrics_for_dashboard(cached_metrics, time_period)
```

## Migration Notes

- Uses `gen_random_uuid()` for UUID primary keys
- JSONB for `agency_stats` provides efficient JSON storage and querying
- All timestamp fields use UTC timezone
- Default values prevent null constraint violations
- Table is designed for small dataset (3 records max) with frequent overwrites

## Future Optimizations

1. **Database Aggregations**: Replace in-memory filtering with SQL aggregations
2. **Incremental Updates**: Update only changed metrics instead of full refresh
3. **Background Jobs**: Move refresh to async background processing
4. **Indexing**: Add indexes if query patterns change (currently unnecessary for 3-row table)
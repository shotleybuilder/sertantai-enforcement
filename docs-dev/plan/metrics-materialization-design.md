# Metrics Materialization Design

## Data Model Analysis

### Current Database State
- **1,048 cases** across **2 agencies** (HSE, EA)
- **1,031 notices** across **2 agencies**
- **949 unique offenders**
- **608 offences** referencing **48 different pieces of legislation**

### Relationships
```
Agency (HSE, EA, ...)
  ├── Cases (1,048)
  │   ├── has_many Offences
  │   └── belongs_to Offender
  └── Notices (1,031)
      ├── has_many Offences
      └── belongs_to Offender

Offence
  └── belongs_to Legislation (48 unique)
```

---

## Filter Dimensions Analysis

### Dimension 1: Time Period
**Values:** `week` (7 days), `month` (30 days), `year` (365 days)
**Cardinality:** 3
**Usage:** Primary dashboard filter, affects all stats
**Expensive to calculate:** YES - requires date filtering across all records

### Dimension 2: Agency
**Values:** `hse`, `ea`, `null` (all agencies), eventually `sepa`, `nrw`
**Cardinality:** 2 currently, 5+ future
**Usage:** Dashboard dropdown, agency-specific views, reports
**Expensive to calculate:** YES - requires GROUP BY and filtering

### Dimension 3: Record Type
**Values:** `case`, `notice`, `combined`
**Cardinality:** 3
**Usage:** Recent Activity filters, separate case/notice pages
**Expensive to calculate:** MEDIUM - simple WHERE clause, but affects Recent Activity UNION

### Dimension 4: Offender (Future)
**Values:** 949 unique offender IDs
**Cardinality:** HIGH
**Usage:** Offender detail pages, "worst offenders" reports
**Expensive to calculate:** YES - but typically filtered AFTER other dimensions

### Dimension 5: Legislation (Future)
**Values:** 48 unique legislation IDs
**Cardinality:** MEDIUM
**Usage:** Legislation detail pages, breach analysis
**Expensive to calculate:** YES - requires JOIN through offences table

---

## Materialization Strategies

### Strategy A: Full Cartesian Product (NOT RECOMMENDED)
```
Time Period (3) × Agency (2) × Record Type (3) = 18 rows
Future: 3 × 5 × 3 = 45 rows
```
**Pros:** Complete coverage, fastest lookups
**Cons:** Exponential growth, redundant data, hard to extend

### Strategy B: Flexible Parameter Schema (RECOMMENDED)
```
Single metrics table with filter parameters stored as columns
Each row represents one unique combination
```

**Schema Design:**
```sql
CREATE TABLE metrics (
  id UUID PRIMARY KEY,

  -- Filter Parameters (NULL = "all")
  time_period TEXT NOT NULL,           -- 'week', 'month', 'year'
  agency_id UUID,                      -- NULL = all agencies
  record_type TEXT,                    -- 'case', 'notice', NULL = combined
  offender_id UUID,                    -- NULL = all offenders (future)
  legislation_id UUID,                 -- NULL = all legislation (future)

  -- Computed Metadata
  period_label TEXT NOT NULL,          -- 'Last 7 Days'
  days_ago INTEGER NOT NULL,           -- 7, 30, 365
  cutoff_date DATE NOT NULL,           -- Calculated date boundary

  -- Aggregate Statistics
  recent_cases_count INTEGER DEFAULT 0,
  recent_notices_count INTEGER DEFAULT 0,
  total_cases_count INTEGER DEFAULT 0,
  total_notices_count INTEGER DEFAULT 0,
  total_offences_count INTEGER DEFAULT 0,
  total_fines_amount DECIMAL DEFAULT 0,
  total_costs_amount DECIMAL DEFAULT 0,

  -- Breakdown Statistics (JSONB for flexibility)
  agency_breakdown JSONB,              -- Per-agency stats when agency_id IS NULL
  offender_breakdown JSONB,            -- Top N offenders
  legislation_breakdown JSONB,         -- Top N breached legislation

  -- Recent Activity Data
  recent_activity JSONB,               -- Top 50-100 items matching filters

  -- Metadata
  calculated_at TIMESTAMP NOT NULL,
  calculated_by TEXT NOT NULL,         -- 'admin', 'automation'

  -- Unique constraint on filter combination
  UNIQUE(time_period, agency_id, record_type, offender_id, legislation_id)
);
```

---

## Recommended Materialized Combinations

### Tier 1: Critical (Always Materialized)
**Dashboard primary views - must be instant**

| time_period | agency_id | record_type | Use Case |
|-------------|-----------|-------------|----------|
| week | NULL | NULL | Dashboard: "Last Week, All Agencies" |
| month | NULL | NULL | Dashboard: "Last Month, All Agencies" (DEFAULT) |
| year | NULL | NULL | Dashboard: "Last Year, All Agencies" |

**Total: 3 rows**

---

### Tier 2: Important (Materialized After Tier 1)
**Per-agency dashboard views**

| time_period | agency_id | record_type | Use Case |
|-------------|-----------|-------------|----------|
| week | HSE | NULL | Dashboard: "Last Week, HSE Only" |
| month | HSE | NULL | Dashboard: "Last Month, HSE Only" |
| year | HSE | NULL | Dashboard: "Last Year, HSE Only" |
| week | EA | NULL | Dashboard: "Last Week, EA Only" |
| month | EA | NULL | Dashboard: "Last Month, EA Only" |
| year | EA | NULL | Dashboard: "Last Year, EA Only" |

**Total: 6 rows** (+ 3 from Tier 1 = 9 rows)

---

### Tier 3: Optional (Calculate on Demand or Materialize if Slow)
**Record type splits - can be filtered client-side from Tier 1/2 recent_activity**

| time_period | agency_id | record_type | Use Case |
|-------------|-----------|-------------|----------|
| month | NULL | case | "Cases only" filter |
| month | NULL | notice | "Notices only" filter |
| month | HSE | case | "HSE cases only" |
| month | HSE | notice | "HSE notices only" |

**Total: 4 rows** (+ 9 = 13 rows)

**Recommendation:** Don't materialize - filter from Tier 1/2 `recent_activity` JSONB

---

### Tier 4: Future Extensions
**Offender and legislation specific metrics**

```sql
-- Top 10 offenders (one row per offender)
time_period: 'year', agency_id: NULL, offender_id: <specific>

-- Specific legislation breach analysis
time_period: 'year', agency_id: NULL, legislation_id: <specific>
```

**Approach:** Generate on-demand for detail pages, cache if accessed frequently

---

## Implementation Plan

### Phase 1: Core Metrics Schema
```elixir
defmodule EhsEnforcement.Enforcement.Metrics do
  attributes do
    # Filter dimensions
    attribute :time_period, :atom, allow_nil?: false,
      constraints: [one_of: [:week, :month, :year]]

    attribute :agency_id, :uuid, allow_nil?: true
    # NULL = all agencies

    attribute :record_type, :atom, allow_nil?: true,
      constraints: [one_of: [:case, :notice]]
    # NULL = combined

    # Future extensions
    attribute :offender_id, :uuid, allow_nil?: true
    attribute :legislation_id, :uuid, allow_nil?: true

    # Aggregate stats (existing + new)
    attribute :recent_cases_count, :integer, default: 0
    attribute :recent_notices_count, :integer, default: 0
    attribute :total_offences_count, :integer, default: 0
    attribute :total_costs_amount, :decimal, default: Decimal.new(0)

    # Breakdown data
    attribute :agency_breakdown, :map, default: %{}
    # Only populated when agency_id IS NULL
    # Format: %{agency_id => %{cases: N, notices: M, fines: X}}

    attribute :offender_breakdown, :map, default: %{}
    # Top 20 offenders
    # Format: %{offender_id => %{name, cases, fines, ...}}

    attribute :legislation_breakdown, :map, default: %{}
    # Top 20 breached legislation
    # Format: %{legislation_id => %{title, breach_count, ...}}

    # Recent Activity
    attribute :recent_activity, {:array, :map}, default: []
    # Array of top 100 recent items
    # Filtered client-side for display
  end

  identities do
    # Ensure unique combination
    identity :unique_filter_combination,
      [:time_period, :agency_id, :record_type, :offender_id, :legislation_id]
  end
end
```

### Phase 2: Refresh Strategy

```elixir
def refresh_all_metrics(calculated_by \\ :admin) do
  # Clear existing metrics
  destroy_all_metrics()

  # Tier 1: All agencies, all record types (3 rows)
  for period <- [:week, :month, :year] do
    refresh_metric_combination(
      period: period,
      agency_id: nil,
      record_type: nil,
      calculated_by: calculated_by
    )
  end

  # Tier 2: Per-agency (6 rows)
  agencies = Enforcement.list_agencies!()
  for period <- [:week, :month, :year],
      agency <- agencies do
    refresh_metric_combination(
      period: period,
      agency_id: agency.id,
      record_type: nil,
      calculated_by: calculated_by
    )
  end

  # Total: 9 rows
  # ~100ms per row = ~1 second total refresh
end

def refresh_metric_combination(opts) do
  period = opts[:period]
  agency_id = opts[:agency_id]
  record_type = opts[:record_type]

  cutoff_date = calculate_cutoff_date(period)

  # Single SQL query for stats
  stats = Repo.one!("""
    SELECT
      COUNT(CASE WHEN type = 'case' THEN 1 END) as recent_cases_count,
      COUNT(CASE WHEN type = 'notice' THEN 1 END) as recent_notices_count,
      COALESCE(SUM(offence_fine), 0) as total_fines,
      COALESCE(SUM(offence_costs), 0) as total_costs
    FROM (
      SELECT 'case' as type, offence_fine, offence_costs, agency_id
      FROM cases WHERE offence_action_date >= $1
      UNION ALL
      SELECT 'notice' as type, NULL, NULL, agency_id
      FROM notices WHERE offence_action_date >= $1
    ) combined
    WHERE $2::uuid IS NULL OR agency_id = $2
    AND ($3::text IS NULL OR type = $3)
  """, [cutoff_date, agency_id, record_type])

  # Agency breakdown (only when agency_id IS NULL)
  agency_breakdown = if is_nil(agency_id) do
    calculate_agency_breakdown(cutoff_date, record_type)
  else
    %{}
  end

  # Recent activity
  recent_activity = fetch_recent_activity(
    cutoff_date, agency_id, record_type, limit: 100
  )

  # Create metrics record
  Metrics
  |> Changeset.for_create(:refresh, %{
    time_period: period,
    agency_id: agency_id,
    record_type: record_type,
    recent_cases_count: stats.recent_cases_count,
    recent_notices_count: stats.recent_notices_count,
    total_fines_amount: stats.total_fines,
    total_costs_amount: stats.total_costs,
    agency_breakdown: agency_breakdown,
    recent_activity: recent_activity,
    # ...
  })
  |> Ash.create!()
end
```

### Phase 3: Dashboard Integration

```elixir
# dashboard_live.ex
def handle_params(params, _url, socket) do
  time_period = socket.assigns.time_period
  agency_filter = socket.assigns.filter_agency

  # Single query to metrics table
  metrics = Enforcement.get_metrics_for_combination(
    time_period: time_period,
    agency_id: agency_filter
  )

  # Client-side filtering of recent_activity if needed
  recent_activity = case socket.assigns.recent_activity_filter do
    :all -> metrics.recent_activity
    :cases -> Enum.filter(metrics.recent_activity, & &1.is_case)
    :notices -> Enum.filter(metrics.recent_activity, & not &1.is_case)
  end

  {:noreply,
   socket
   |> assign(:stats, format_stats(metrics))
   |> assign(:recent_activity, recent_activity)}
end
```

---

## Benefits of This Design

### 1. Flexibility
- ✅ Easy to add new dimensions (offender_id, legislation_id)
- ✅ Each combination is explicit and queryable
- ✅ No redundant storage of same data

### 2. Performance
- ✅ Dashboard reads 1-9 rows (depending on what's materialized)
- ✅ Recent Activity filtering happens client-side (100 items in memory)
- ✅ Metrics refresh parallelizable (each combination independent)

### 3. Scalability
- ✅ Current state: 9 rows (3 periods × 3 agency combos)
- ✅ With 5 agencies: 18 rows (3 × 6 combos)
- ✅ Add record_type split: 36 rows (still very small)

### 4. Extensibility
- ✅ Top offenders: Add on-demand or materialize top 20
- ✅ Legislation breakdown: Computed in agency_breakdown
- ✅ Custom date ranges: Can add period='custom' with start/end dates

---

## Query Patterns

### Dashboard Default View
```sql
SELECT * FROM metrics
WHERE time_period = 'month'
  AND agency_id IS NULL
  AND record_type IS NULL;
```
**Result:** 1 row with all stats + recent_activity

### Dashboard Filtered by Agency
```sql
SELECT * FROM metrics
WHERE time_period = 'month'
  AND agency_id = 'hse-uuid';
```
**Result:** 1 row with HSE-specific stats

### Dashboard Time Period Change
```sql
SELECT * FROM metrics
WHERE time_period = 'year'
  AND agency_id = 'hse-uuid';
```
**Result:** 1 row, instant switch

---

## Migration Strategy

### Step 1: Add New Columns
```sql
ALTER TABLE metrics
  ADD COLUMN agency_id UUID REFERENCES agencies(id),
  ADD COLUMN record_type TEXT,
  ADD COLUMN offender_id UUID,
  ADD COLUMN legislation_id UUID,
  ADD COLUMN total_offences_count INTEGER DEFAULT 0,
  ADD COLUMN total_costs_amount DECIMAL DEFAULT 0,
  ADD COLUMN offender_breakdown JSONB DEFAULT '{}',
  ADD COLUMN legislation_breakdown JSONB DEFAULT '{}';

-- Update existing records to have agency_id = NULL (all agencies)
UPDATE metrics SET agency_id = NULL;

-- Add unique constraint
CREATE UNIQUE INDEX metrics_filter_combination_idx ON metrics(
  time_period,
  COALESCE(agency_id::text, 'null'),
  COALESCE(record_type::text, 'null'),
  COALESCE(offender_id::text, 'null'),
  COALESCE(legislation_id::text, 'null')
);
```

### Step 2: Update Refresh Logic
- Implement new `refresh_metric_combination/1`
- Update `refresh_all_metrics/1` to generate Tier 1 + Tier 2 combinations
- Test metrics match existing calculations

### Step 3: Update Dashboard
- Change `load_cached_stats/1` to query with `agency_id`
- Remove all real-time calculation fallbacks
- Test with different filter combinations

---

## Estimated Metrics Table Size

### Current (2 agencies)
- Tier 1: 3 rows
- Tier 2: 6 rows
- **Total: 9 rows**

### Future (5 agencies)
- Tier 1: 3 rows
- Tier 2: 15 rows (3 periods × 5 agencies)
- **Total: 18 rows**

### With Record Type Split
- Tier 1: 3 rows
- Tier 2: 15 rows
- Tier 3: 30 rows (15 × 2 record types)
- **Total: 48 rows**

**Conclusion:** Even with full materialization, <100 rows. Negligible storage and instant lookups.

---

## Recommendation

**START WITH TIER 1 + TIER 2 (9 rows)**

This covers:
- ✅ All time periods
- ✅ All agencies individually
- ✅ Combined view
- ✅ Recent Activity (top 100 in JSONB, filtered client-side)

**DEFER TIER 3 (record_type splits)**
- Recent Activity already includes type flag
- Client-side filtering of 100 items is instant
- Saves 27 rows and complexity

**DEFER TIER 4 (offender/legislation specific)**
- Generate on-demand for detail pages
- Cache in ETS if accessed frequently
- Avoids 1000s of combinations


# Scraping Architecture Consolidation Roadmap

## Quick Reference: Duplication Summary

### Total Duplication by Area
- **LiveView Handlers**: 900-1000 lines (60-70% duplicated)
- **HSE Processors**: 140-180 lines (25-30% duplicated)
- **EA Processors**: 150-200 lines (15-20% duplicated)
- **Shared Utilities**: 75 lines (business type, date parsing, monetary)

### Where to Focus
1. **Highest Payoff**: LiveView consolidation (4-6 hours → 900 lines saved)
2. **Quick Wins**: Business type extraction (30 mins → 23 lines saved, reused 4x)
3. **Medium Value**: Processor consolidation (2-3 hours → 150 lines saved)

---

## Phase 1: Quick Wins (2-3 hours) - START HERE

### 1.1: Extract Business Type Logic (30 mins)
**File**: `lib/ehs_enforcement/utilities/business_type_detector.ex` (NEW)

**Extract from**: 
- HSE.CaseProcessor (lines 423-433)
- HSE.NoticeProcessor (lines 310-320)
- EA.CaseProcessor (implied)
- EA.NoticeProcessor (implied)

**Functions**:
```elixir
def determine_business_type(offender_name)
def normalize_business_type(business_type_string)
```

**Impact**: 
- Eliminates 23 lines of EXACT duplication
- Used in 4 processors
- Provides consistent business type classification

**Implementation**:
1. Copy `determine_business_type/1` from HSE.CaseProcessor
2. Add `normalize_business_type/1` function
3. Replace in all processors with: `require EhsEnforcement.Utilities.BusinessTypeDetector`
4. Use `BusinessTypeDetector.determine_business_type/1`

---

### 1.2: Extract Monetary Amount Parser (30 mins)
**File**: `lib/ehs_enforcement/utilities/monetary_parser.ex` (NEW)

**Extract from**:
- HSE.CaseScraper (lines 444-455)
- EA.CaseScraper (used but embedded)

**Function**:
```elixir
def parse_monetary_amount(amount_str)
```

**Impact**: 
- Eliminates 10 lines of duplication
- Reusable across all scrapers

---

### 1.3: Extract EA Environmental Data Helpers (30 mins)
**File**: `lib/ehs_enforcement/agencies/ea/data_helpers.ex` (NEW)

**Extract from**:
- EA.CaseProcessor
  - `assess_environmental_impact/1` (8 lines)
  - `detect_primary_receptor/1` (10 lines)
- EA.NoticeProcessor
  - `build_environmental_impact/1` (14 lines)
  - `detect_environmental_receptor/1` (9 lines)

**New Functions**:
```elixir
def assess_environmental_impact(water, land, air)  # unified version
def detect_primary_receptor(water, land, air)       # unified version
```

**Impact**: 
- Eliminates 30-40 lines of duplication
- Makes environmental processing consistent
- Easier to test

---

## Phase 2: Medium Effort (2-3 hours)

### 2.1: Extract Date Parser Utility (1 hour)
**File**: `lib/ehs_enforcement/utilities/date_parser.ex` (NEW or EXTEND)

**Extract from**: HSE.NoticeProcessor (lines 224-277)

**Functions**:
```elixir
def parse_date(date_input)
defp try_parse_date_formats(date_string)
defp try_parse_dash_format(date_string)
defp try_parse_iso_format(date_string)
```

**Impact**:
- Reusable across all notice processors (HSE + EA)
- 50 lines of date handling logic centralized
- Supports multiple format detection

---

### 2.2: Extract Offender Attribute Builders (1 hour)
**File**: `lib/ehs_enforcement/agencies/hse/offender_builder.ex` (NEW)

**Extract from**:
- HSE.CaseProcessor.build_offender_attrs/1 (16 lines)
- HSE.NoticeProcessor.build_offender_attrs/1 (19 lines)

**New Functions**:
```elixir
def build_offender_attrs(raw_data, data_type)  # :case or :notice
def determine_business_type(name)
```

**Impact**:
- Consolidates 35-40 lines
- Consistent offender matching across HSE case/notice
- Easier to extend with new fields

---

### 2.3: Extract EA Offender Builder (30 mins - Optional)
**File**: `lib/ehs_enforcement/agencies/ea/offender_builder.ex` (NEW)

**Extract from**:
- EA.CaseProcessor.build_ea_offender_attrs/1 (24 lines)
- EA.NoticeProcessor.build_offender_attrs/1 (34 lines)

**Impact**:
- 30-40 lines of duplication eliminated
- Consistent EA offender handling

---

## Phase 3: High Impact (4-6 hours) - HIGHEST PAYOFF

### 3.1: Consolidate LiveView Scraping Handlers

**Current State**:
- `lib/ehs_enforcement_web/live/admin/case_live/scrape.ex` (1,279 lines)
- `lib/ehs_enforcement_web/live/admin/notice_live/scrape.ex` (1,124 lines)
- **60-70% duplication** between them

**Strategy**: Create base module + delegation pattern

#### Step 1: Create Base Module (2-3 hours)
**File**: `lib/ehs_enforcement_web/live/admin/scrape_base_live.ex` (NEW)

**Common Functions**:
- `mount/3` - generalized for both case/notice
- `handle_event("validate", ...)` - generic validation
- `handle_event("stop_scraping", ...)`
- `handle_event("clear_*", ...)`
- All `handle_info/*` progress handlers (20+ handlers)
- Helper functions:
  - `update_progress/2`
  - `broadcast_scraping_event/2`
  - `should_enable_real_time_progress?/1`
  - `extract_progress_from_session/1`
  - `duplicate_error?/1`
  - Metrics refresh callback

**Parameterizable Aspects**:
```elixir
# Define callbacks for submodules to implement
@callback scraping_type() :: :case | :notice
@callback default_form_params() :: map()
@callback start_scraping_task(socket, params) :: {:noreply, socket}
@callback process_single_item(item, database, actor, results) :: results
```

#### Step 2: Refactor CaseLive.Scrape (1 hour)
**File**: Simplify existing `case_live/scrape.ex`

**New structure**:
```elixir
defmodule EhsEnforcementWeb.Admin.CaseLive.Scrape do
  use EhsEnforcementWeb, :live_view
  alias EhsEnforcementWeb.Admin.ScrapeLive.Base  # NEW: base module
  
  # Implement callbacks required by ScrapeLive.Base
  def scraping_type, do: :case
  def default_form_params do
    %{
      "agency" => "hse",
      "database" => "convictions",
      "start_page" => "1",
      "max_pages" => "10"
    }
  end
  
  # Delegate all common functions to Base module
  def mount(params, session, socket) do
    ScrapeLive.Base.mount(__MODULE__, params, session, socket)
  end
  
  def handle_event(event, params, socket) do
    ScrapeLive.Base.handle_event(__MODULE__, event, params, socket)
  end
  
  # ... delegate other callbacks
  
  # Only implement case-specific functions here
  defp scrape_cases_with_session(session, opts) do
    # HSE case scraping logic
  end
  
  defp process_single_case_simple(case, database, actor, results) do
    # HSE case processing
  end
end
```

**Result**: 1,279 lines → ~150-200 lines (85% reduction)

#### Step 3: Refactor NoticeLive.Scrape (1 hour)
Same pattern as CaseLive, but with notice-specific callbacks:

```elixir
def scraping_type, do: :notice
def default_form_params do
  %{
    "agency" => "hse",
    "database" => "notices",
    "country" => "All",
    "start_page" => "1",
    "max_pages" => "10"
  }
end

# Notice-specific implementations
defp scrape_notices_with_session(session, opts) do
  # HSE notice scraping
end

defp scrape_ea_notices_with_session(session, opts) do
  # EA notice scraping (different from HSE)
end

defp process_single_notice_simple(notice, database, actor, results) do
  # HSE notice processing
end
```

**Result**: 1,124 lines → ~150-200 lines (85% reduction)

#### Step 4: Benefit from Module Reuse
- New scraping types can now reuse 90% of the code
- Just implement the callbacks for their specific scraping logic
- Huge maintainability gain

---

## Implementation Sequence

### Week 1: Phase 1 (2-3 hours)
```
Day 1:
1. Extract business_type_detector.ex (30 mins)
2. Update HSE and EA processors to use it (30 mins)
3. Test all 4 processors (30 mins)

Day 2:
4. Extract monetary_parser.ex (30 mins)
5. Update HSE and EA scrapers to use it (30 mins)
6. Extract EA environmental helpers (30 mins)
```

### Week 2: Phase 2 (2-3 hours)
```
Day 1:
1. Extract date_parser.ex (1 hour)
2. Update HSE.NoticeProcessor to use it (30 mins)
3. Test date parsing in multiple formats (30 mins)

Day 2:
4. Extract HSE offender_builder.ex (1 hour)
5. Update HSE processors to use it (30 mins)
6. Run full test suite (30 mins)
```

### Week 3: Phase 3 (4-6 hours) - THIS IS THE BIG ONE
```
Day 1:
1. Create ScrapeLive.Base module (2-3 hours)
2. Verify all common functions work correctly
3. Run case scraping tests

Day 2-3:
4. Refactor CaseLive.Scrape to use Base (1 hour)
5. Run case scraping E2E tests
6. Refactor NoticeLive.Scrape to use Base (1 hour)
7. Run notice scraping E2E tests
8. Complete integration testing (2 hours)
```

---

## Testing Strategy

### Phase 1 Tests
```bash
# After each extraction, run:
mix test test/ehs_enforcement/utilities/business_type_detector_test.exs
mix test test/ehs_enforcement/utilities/monetary_parser_test.exs
mix test test/ehs_enforcement/agencies/ea/data_helpers_test.exs

# Full suite to detect any regressions:
mix test test/ehs_enforcement/scraping/
```

### Phase 2 Tests
```bash
mix test test/ehs_enforcement/utilities/date_parser_test.exs
mix test test/ehs_enforcement/agencies/hse/offender_builder_test.exs

# Processor tests to verify integration:
mix test test/ehs_enforcement/scraping/hse/case_processor_test.exs
mix test test/ehs_enforcement/scraping/hse/notice_processor_test.exs
```

### Phase 3 Tests
```bash
# Test the base module in isolation
mix test test/ehs_enforcement_web/live/admin/scrape_base_live_test.exs

# Test the refactored views
mix test test/ehs_enforcement_web/live/admin/case_live/scrape_test.exs
mix test test/ehs_enforcement_web/live/admin/notice_live/scrape_test.exs

# E2E scraping tests
mix test test/ehs_enforcement/scraping/workflows/
```

---

## Risk Mitigation

### High-Risk Consolidations
**Phase 3 (LiveView)** has highest complexity:

1. **Risk**: Breaking existing scraping workflows
   - **Mitigation**: Keep old files for comparison, test both HSE and EA scraping

2. **Risk**: Callback implementation errors
   - **Mitigation**: Create comprehensive test cases for each callback

3. **Risk**: UI state management issues
   - **Mitigation**: Test with both case and notice scraping in parallel

### Testing Checklist
- [ ] Cases scrape successfully from page 1
- [ ] Notices scrape successfully from HSE
- [ ] EA cases scrape successfully (date range)
- [ ] EA notices scrape successfully
- [ ] Progress updates display correctly
- [ ] Stop button works for all agency/type combinations
- [ ] Error handling works for all scenarios
- [ ] No regressions in existing functionality

---

## Expected Outcomes

### Code Reduction
- **Phase 1**: 100 lines saved (total codebase, utilities)
- **Phase 2**: 150 lines saved (processors, helpers)
- **Phase 3**: 900-1000 lines saved (LiveView consolidation)
- **Total**: 1150-1250 lines eliminated

### Maintainability Improvements
- Reduced code duplication from ~60-70% to ~20-30% in LiveView
- Single source of truth for business logic
- Easier to add new agencies/scraping types
- Simpler bug fixes (fix in one place, benefit everywhere)

### Timeline
- **Phase 1**: 2-3 hours (minimal risk)
- **Phase 2**: 2-3 hours (medium risk)
- **Phase 3**: 4-6 hours (high impact, higher complexity)
- **Total**: 8-12 hours of focused development

---

## Success Metrics

1. **All tests pass** after each phase
2. **No behavioral changes** to scraping from user perspective
3. **Code review approval** for consolidation patterns
4. **Documentation updated** for new utilities
5. **Architecture cleaner** and easier to extend


# GitHub Issue: HSE Scraping Session Not Updating Progress During Execution

## Issue Summary

HSE scraping (both cases and notices) creates a ScrapeSession but never updates progress fields during execution. The session remains at initial values (`pages_processed: 0`, `cases_found: 0`, `cases_created: 0`) even though scraping runs and creates records. This prevents the Progress Tracker UI from displaying real-time updates.

## Severity

**High** - Core functionality broken. Users cannot monitor HSE scraping progress.

## Environment

- **Project**: EHS Enforcement (Elixir/Phoenix/Ash)
- **Affected Feature**: HSE scraping (cases and notices)
- **Working Comparison**: Environment Agency scraping works correctly
- **Related Issue**: #18 (Progress Tracker UI - now resolved for UI layer)

## Symptoms

### Observable Behavior

1. Start HSE scraping (cases or notices) from `/admin/scrape`
2. Progress tracker shows "Ready 0%" or stuck at "5%"
3. Displays show:
   - Pages Processed: 0
   - Cases/Notices Found: 0
   - Cases/Notices Created: 0
4. Database confirms session not updated:
   ```sql
   SELECT pages_processed, cases_found, cases_created
   FROM scrape_sessions
   WHERE agency = 'hse'
   ORDER BY inserted_at DESC LIMIT 1;

   -- Result: 0, 0, 0 for all fields
   ```

### Database Evidence

Recent HSE Notice scraping sessions (from production data):

```
session_id        | agency | database | status  | pages_processed | cases_found | cases_created
------------------|--------|----------|---------|-----------------|-------------|---------------
48afaa67bcc32682 | hse    | notices  | stopped | 0               | 0           | 0
30d04221b146d0f1 | hse    | notices  | stopped | 0               | 0           | 0
bdeec292dc0aa698 | hse    | notices  | stopped | 0               | 0           | 0
```

All sessions show:
- `current_page: 1` (never advances)
- `pages_processed: 0` (never increments)
- `status: stopped` (stops prematurely)

## Root Cause Analysis

### Expected Flow (Working in EA)

```
1. Scraping code processes record/page
2. Calls Ash.update(session, %{cases_processed: X, cases_found: Y, ...})
3. Ash broadcasts "scrape_session:updated" via PubSub
4. LiveView receives broadcast
5. UI updates in real-time
```

### Broken Flow (HSE)

```
1. Scraping code starts processing page 1
2. ❌ Encounters error or condition that stops execution
3. ❌ Never calls advance_to_next_page()
4. ❌ Never updates session progress fields
5. ❌ Session remains at initial values
6. Progress tracker displays zeros
```

### Code Analysis

**File**: `lib/ehs_enforcement/scraping/agencies/hse.ex`

**Key Functions**:
- `execute_hse_scraping_session/1` (line 210) - Entry point
- `process_pages_until_complete/1` (line 218) - Recursive page processor
- `process_current_page/1` (line 229) - Processes single page
- `advance_to_next_page/1` (line 406) - Increments `pages_processed` and `current_page`
- `update_session_with_page_results/1` (line 673) - Updates counts

**Problem**:
1. `process_current_page/1` runs for page 1
2. Something causes early exit before `advance_to_next_page/1` is called
3. `pages_processed` never increments
4. Loop condition `should_continue_scraping?/1` returns false
5. Scraping stops with all values at 0

**Critical Missing Update**:
Line 673-709 `update_session_with_page_results/1` updates `cases_processed`, `cases_created`, `cases_exist_total` BUT **does not update `cases_found`**. The function also doesn't handle the initial page population correctly.

## Comparison with Working EA Implementation

### EA Updates Session Per Record

**File**: `lib/ehs_enforcement/scraping/agencies/ea.ex`

```elixir
# Line 574: Updates after EACH record
defp update_session_with_single_record_progress(session, record_result) do
  update_params = %{
    cases_processed: session.cases_processed + 1,
    cases_created: session.cases_created + (if record_result.status == :created, do: 1, else: 0),
    # ... other fields
  }

  case Ash.update(session, update_params) do
    {:ok, updated_session} ->
      Logger.debug("EA: Updated session progress for real-time feedback")
      updated_session
    # ...
  end
end
```

**Key Difference**: EA updates the session **during the accumulation loop**, not just at the end.

### HSE Updates Session Per Page (Theory)

HSE should update after each page via:
1. `process_current_page/1` processes all records on page
2. `update_session_with_page_results/1` updates counts
3. `advance_to_next_page/1` increments `pages_processed`

**But this never happens** - execution stops before the first page completes.

## Investigation Checklist

### Questions to Answer

1. **Does `process_current_page/1` actually run?**
   - Check logs for "HSE: Processing page X" messages
   - Expected: Should see log for page 1

2. **Does page processing encounter errors?**
   - Check for error logs during scraping
   - Look for exceptions or early returns

3. **Are notices/cases actually scraped from the page?**
   - Check if `NoticeScraper.get_hse_notices/1` returns data
   - Verify notices are being created in database

4. **Does `update_session_with_page_results/1` get called?**
   - Add logging to confirm function execution
   - Check if Ash.update call succeeds or fails

5. **Does `should_continue_scraping?/1` return false prematurely?**
   - Line 564-573: Check which condition triggers exit
   - Most likely: `session.status != :running`

6. **Is the recursive loop structure correct?**
   - Line 218-226: Tail recursion pattern looks correct
   - But might not be passing updated session through pipeline

## Proposed Investigation Steps

1. **Add Debug Logging**
   ```elixir
   # At start of process_current_page/1
   Logger.info("🔍 HSE: Starting page #{session.current_page}, pages_processed=#{session.pages_processed}")

   # At end of process_current_page/1
   Logger.info("🔍 HSE: Finished page #{session.current_page}, results: #{inspect(results)}")

   # In update_session_with_page_results/1
   Logger.info("🔍 HSE: Updating session with #{total_cases} cases")
   ```

2. **Run Test Scrape**
   - Start HSE notice scrape (pages 1-3)
   - Monitor logs in real-time
   - Identify exact point of failure

3. **Compare Notice vs Case Processing**
   - Check if cases work differently than notices
   - Line 234: Different code paths for `"notices"` vs `"convictions"`

4. **Check Error Handling**
   - Line 238: `case NoticeScraper.get_hse_notices(...)` error branch
   - Verify errors are logged and session continues

5. **Verify PubSub Configuration**
   ```elixir
   # Check ScrapeSession resource
   # Should have pub_sub with topic: "scrape_session:updated"
   ```

## Expected Fixes

### Fix 1: Ensure Session Updates Happen

Update `update_session_with_page_results/1` to:
1. Update `cases_found` field (currently missing)
2. Add debug logging before/after Ash.update
3. Handle update failures gracefully

### Fix 2: Update on First Page

Currently, `pages_processed` only increments in `advance_to_next_page/1`. But if the first page fails, we never reach that function. Solution:
- Update `pages_processed` at START of `process_current_page/1`, not after
- Or: Split increment into "page_started" and "page_completed"

### Fix 3: Better Error Handling

```elixir
defp process_current_page(session) do
  result = case session.database do
    "notices" -> scrape_notices(session)
    _ -> scrape_cases(session)
  end

  case result do
    {:ok, records} ->
      # Process successfully
      process_records_and_update_session(session, records)

    {:error, reason} ->
      Logger.error("Failed to scrape page: #{inspect(reason)}")
      # Still update session with error, don't just stop
      update_session_with_error(session, reason)
  end
end
```

## Testing Plan

1. **Unit Tests**
   - Test `update_session_with_page_results/1` in isolation
   - Mock session and verify all fields update correctly

2. **Integration Tests**
   - Test full HSE scraping flow (pages 1-3)
   - Assert session updates after each page
   - Verify PubSub broadcasts fire

3. **Manual Testing**
   - Start HSE notice scrape in dev environment
   - Watch progress tracker update in real-time
   - Verify database session values increment

## Success Criteria

✅ HSE scraping updates `pages_processed` after each page
✅ HSE scraping updates `cases_found` as records are discovered
✅ HSE scraping updates `cases_created`, `cases_exist_total` as records are processed
✅ Progress tracker displays real-time updates for HSE (like it does for EA)
✅ Database shows non-zero values in scrape_sessions table for HSE scrapes
✅ No regression in EA scraping functionality

## Related Files

- `lib/ehs_enforcement/scraping/agencies/hse.ex` - Main HSE scraping logic
- `lib/ehs_enforcement/scraping/strategies/hse/case_strategy.ex` - HSE case strategy
- `lib/ehs_enforcement/scraping/strategies/hse/notice_strategy.ex` - HSE notice strategy
- `lib/ehs_enforcement/scraping/resources/scrape_session.ex` - Ash resource
- `lib/ehs_enforcement_web/live/admin/scrape_live.ex` - LiveView UI
- `lib/ehs_enforcement_web/components/progress_component.ex` - Progress display

## Session Reference

Full investigation documented in: `.claude/sessions/2025-11-10-Github Issue #18 HSE Scrape Progress Tracker.md`

## Priority

**P0** - Blocks HSE scraping monitoring, core user-facing feature

## Labels

- bug
- scraping
- hse
- progress-tracker
- high-priority

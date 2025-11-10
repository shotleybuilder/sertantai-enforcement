# HSE Progress Tracking - Incremental Update Specification

## Current Behavior (Bug)

Progress tracker only updates **at the end of each page**:
- User sees: 0% → (long pause) → 50% → (long pause) → 100%
- `cases_created` jumps: 0 → 10 → 20 (all at once)
- No feedback during page processing

## Required Behavior

Progress tracker should update **as each record is processed**:

### Example: 2-page scrape, 3 records per page

| Event | pages_processed | cases_found | cases_created | Percentage | Display |
|-------|----------------|-------------|---------------|------------|---------|
| **Start** | 0 | 0 | 0 | 0% | "Ready" |
| Process record 1 | 0 | 1 | 1 | 0% | "Processing page 1..." |
| Process record 2 | 0 | 2 | 2 | 0% | "Processing page 1..." |
| Process record 3 | 0 | 3 | 3 | 0% | "Processing page 1..." |
| **Page 1 Complete** | **1** | 3 | 3 | **50%** | "Processing page 2..." |
| Process record 4 | 1 | 4 | 4 | 50% | "Processing page 2..." |
| Process record 5 | 1 | 5 | 5 | 50% | "Processing page 2..." |
| Process record 6 | 1 | 6 | 6 | 50% | "Processing page 2..." |
| **Page 2 Complete** | **2** | 6 | 6 | **100%** | "Completed!" |

### Key Requirements

1. **`cases_created` increments per record**: 1 → 2 → 3 → 4 → 5 → 6
2. **`cases_found` increments per record**: 1 → 2 → 3 → 4 → 5 → 6
3. **`pages_processed` increments per page**: 0 → 1 → 2
4. **Percentage based on pages**: 0% (page 0/2) → 50% (page 1/2) → 100% (page 2/2)
5. **Session updates trigger PubSub broadcasts** for real-time UI

## Implementation Requirements

### 1. Modify `process_notices_serially/2`

**Current Code** (line 450-478 in hse.ex):
```elixir
defp process_notices_serially(session, notices) do
  # Process all notices
  results = Enum.reduce(notices, %{cases_created: 0, cases_existing: 0, cases_errors: 0}, fn notice, acc ->
    # ... process notice ...
    acc  # Returns accumulated results
  end)

  # Update session ONCE at end
  update_session_with_page_results(session, results)
end
```

**Required Code**:
```elixir
defp process_notices_serially(session, notices) do
  # Track current session state through the reduction
  {final_session, results} = Enum.reduce(notices, {session, %{cases_created: 0, cases_existing: 0, cases_errors: 0}},
    fn notice, {current_session, acc} ->
      # Process notice
      case process_and_save_notice(notice, current_session) do
        {:ok, _created_notice} ->
          # UPDATE SESSION IMMEDIATELY after each record
          updated_session = update_session_incremental(current_session, :created)
          {updated_session, %{acc | cases_created: acc.cases_created + 1}}

        {:error, :exists} ->
          updated_session = update_session_incremental(current_session, :existing)
          {updated_session, %{acc | cases_existing: acc.cases_existing + 1}}

        {:error, _reason} ->
          updated_session = update_session_incremental(current_session, :error)
          {updated_session, %{acc | cases_errors: acc.cases_errors + 1}}
      end
    end)

  # Return final session (already updated incrementally)
  final_session
end
```

### 2. New Function: `update_session_incremental/2`

```elixir
defp update_session_incremental(session, result_type) do
  update_params = case result_type do
    :created ->
      %{
        cases_found: session.cases_found + 1,
        cases_created: session.cases_created + 1,
        cases_processed: session.cases_processed + 1
      }
    :existing ->
      %{
        cases_found: session.cases_found + 1,
        cases_exist_total: session.cases_exist_total + 1,
        cases_processed: session.cases_processed + 1
      }
    :error ->
      %{
        cases_found: session.cases_found + 1,
        errors_count: session.errors_count + 1,
        cases_processed: session.cases_processed + 1
      }
  end

  # Preserve validated_params
  validated_params = Map.get(session, :validated_params)

  case Ash.update(session, update_params) do
    {:ok, updated_session} ->
      Logger.debug("📊 HSE: Updated session incrementally - cases_found: #{updated_session.cases_found}, cases_created: #{updated_session.cases_created}")

      # Ash PubSub will broadcast "scrape_session:updated" automatically

      if validated_params do
        Map.put(updated_session, :validated_params, validated_params)
      else
        updated_session
      end

    {:error, reason} ->
      Logger.error("❌ HSE: Failed incremental update: #{inspect(reason)}")
      session  # Return original session on failure
  end
end
```

### 3. Keep `update_session_with_page_results/1` for Final Counts

This function stays but now only updates `pages_processed`:

```elixir
defp update_session_with_page_results(session, _results) do
  # Cases/notices already updated incrementally
  # Just increment pages_processed at page end

  update_params = %{
    pages_processed: session.pages_processed + 1
  }

  # Rest of function remains same...
end
```

## Test Coverage

### Fixture Data
- **Location**: `test/support/fixtures/hse_notices.json`
- **Content**: 2 pages with 3 records each (lightweight test data)

### Test Cases

1. **Progress percentage calculation**
   - Assert: 0/2 pages = 0%, 1/2 pages = 50%, 2/2 pages = 100%

2. **Incremental cases_created**
   - Assert: Updates after each record (1, 2, 3, 4, 5, 6)
   - Not batch updates (0, 3, 6)

3. **Incremental cases_found**
   - Assert: Accumulates across pages (1, 2, 3, 4, 5, 6)

4. **Pages processed at page boundaries**
   - Assert: 0 → 1 (after page 1) → 2 (after page 2)

5. **PubSub broadcasts**
   - Assert: Broadcast fired after each record processed
   - UI receives real-time updates

## Acceptance Criteria

✅ User sees `cases_created` increment in real-time as records process
✅ Progress percentage updates at page boundaries (0% → 50% → 100%)
✅ `cases_found` accumulates correctly across pages
✅ No delays between individual record processing and UI update
✅ Tests pass using fixture data without hitting live HSE website
✅ EA scraping continues to work (no regression)

## Migration Path

1. ✅ Create fixture data
2. ✅ Write test specs (template created)
3. ⏳ Implement `update_session_incremental/2`
4. ⏳ Modify `process_notices_serially/2` to use incremental updates
5. ⏳ Update `process_cases_serially/2` similarly (for convictions)
6. ⏳ Run tests to verify behavior
7. ⏳ Test manually in dev environment
8. ✅ Deploy and verify in production

## Performance Considerations

**Concern**: Will updating the session after EVERY record cause performance issues?

**Analysis**:
- Current: 1 DB update per page (10 records)
- Proposed: 10 DB updates per page

**Mitigation**:
- Ash handles updates efficiently
- PubSub broadcasts are fast
- Trade-off: Better UX is worth slight performance cost
- Alternative: Batch updates every N records (e.g., every 5)

**Recommendation**: Start with per-record updates. If performance issues arise, batch every 5 records.

# CRITICAL BUG: EA Duplicate Detection Data Corruption

**Date Discovered:** 2025-10-21
**Date Resolved:** 2025-10-22
**Severity:** CRITICAL - Data Loss & Corruption
**Status:** ✅ FIXED - Ready for Deployment

## Bug Summary

When scraping multiple EA cases for the same offender in reverse chronological order, the system incorrectly updates an existing case instead of creating a new one, resulting in:
- **Data corruption** (wrong fine amounts)
- **Data loss** (missing cases entirely)

## Reproduction Steps (Verified)

1. Scrape EA case from 2005-07-22 (£4,000 fine)
   - ✅ Creates case with `regulator_id: "T/H/2005/257487/02"`
   - ✅ Fine: £4,000
   - ✅ Status: Created

2. Scrape EA case from 2004-11-24 (£10,500 fine)
   - ❌ **UPDATES** 2005 case instead of creating new case
   - ❌ Fine changes: £4,000 → £10,500 (CORRUPTION)
   - ❌ 2004 case never created (DATA LOSS)

**Log Evidence:**
```
[info] Successfully updated existing case: T/H/2005/257487/02
[info] EA: Updated case: T/H/2005/257487/02
```

## Database State After Bug

```sql
SELECT regulator_id, offence_action_date, offence_fine
FROM cases WHERE offender_name LIKE '%ROOFING SPECIALISTS%'

Results:
- T/H/2005/257487/02 | 2005-07-22 | £10,500 (WRONG - should be £4,000)
- 2004 case MISSING ENTIRELY
```

## Root Cause Confirmed

**Location:** `lib/ehs_enforcement/agencies/ea/data_transformer.ex:63`

```elixir
regulator_id: ea_record.case_reference || generate_regulator_id_from_detail(ea_record),
```

**The Problem:** EA website returns the **same "Case Reference" for different EA records**

**Evidence from scraping logs:**
- EA record **2482** (2005 case): HTML has `Case Reference: T/H/2005/257487/02`
- EA record **3424** (2004 case): HTML has `Case Reference: T/H/2005/257487/02` **(IDENTICAL!)**

Both generate: `regulator_id = "T/H/2005/257487/02"`

The unique constraint `identity(:unique_regulator_id, [:regulator_id])` detects them as the same case, causing the second scrape to **UPDATE** the first case instead of creating a new one.

**Why same case reference?**
These are likely related cases (appeals, linked proceedings, etc.) that share a parent case number but are distinct EA records with unique EA record IDs (2482 vs 3424).

## Immediate Action Required

1. ✅ Bug reproduced in development
2. ⏳ Identify why `regulator_id` values collide
3. ⏳ Implement fix to use unique EA record IDs
4. ⏳ Audit production database for other corrupted cases
5. ⏳ Re-scrape affected cases with fix deployed

## Proposed Solution

### Schema Changes Required

1. **Repurpose `airtable_id` field** → rename to `reference_id`
   - ✅ Currently unused: 0 of 1057 cases have `airtable_id` populated
   - Store EA "Case Reference" field here (e.g., `T/H/2005/257487/02`)
   - Can be shared by multiple cases (not unique)

2. **Store EA record ID in `regulator_id`**
   - Use EA record ID from URL (e.g., `2482`, `3424`)
   - These ARE unique per EA record
   - Note: Numeric IDs will clash with HSE, so need composite unique constraint

3. **Change unique constraint to composite:**
   ```elixir
   # BEFORE (BROKEN):
   identity(:unique_regulator_id, [:regulator_id])

   # AFTER (FIXED):
   identity(:unique_case_per_agency, [:agency_id, :regulator_id])
   ```

### Benefits

- ✅ Duplicate detection scoped per agency (HSE "3424" ≠ EA "3424")
- ✅ EA record ID guaranteed unique within EA
- ✅ Case Reference preserved in `reference_id` for display/reference
- ✅ No data migration needed (`airtable_id` is empty)
- ✅ Fixes data corruption bug
- ✅ Prevents data loss (missing cases)

### Implementation Checklist

1. ✅ Reproduce bug in development
2. ✅ Identify root cause (case_reference not unique)
3. ✅ Create migration to rename `airtable_id` → `case_reference`
4. ✅ Update Case resource identity to `[:agency_id, :regulator_id]`
5. ✅ Update EA data transformer to use `ea_record_id` for `regulator_id`
6. ✅ Update EA data transformer to store `case_reference` in `case_reference`
7. ✅ Update duplicate detection logic in case processor
8. ✅ Test fix with A & F ROOFING cases (2/2 tests passing)
9. ✅ Clean up unused test fixtures
10. ⏳ Deploy to development server
11. ⏳ Deploy to production server
12. ⏳ Delete all EA cases and re-scrape with fix

---

## Implementation Summary (2025-10-22)

### Changes Delivered

**Code Changes:**
- `lib/ehs_enforcement/enforcement/resources/case.ex`: Renamed `airtable_id` → `case_reference`, composite unique key
- `lib/ehs_enforcement/agencies/ea/data_transformer.ex`: Use `ea_record_id` for `regulator_id`, store `case_reference` separately
- `lib/ehs_enforcement/scraping/ea/case_processor.ex`: Updated duplicate detection with composite key filter
- `test/ehs_enforcement/agencies/ea/roofing_specialists_bug_test.exs`: Test reproducing bug scenario

**Migration:**
- `priv/repo/migrations/20251022071558_rename_airtable_id_to_case_reference_and_composite_key.exs`
- Renames column, drops old unique index, creates composite unique index

**Test Results:**
- ✅ Roofing Specialists Bug Test: 2/2 passing
- Confirms fix prevents duplicate `regulator_id` collisions
- Confirms separate cases created for same `case_reference`

### Deployment Strategy

**Recommended approach:** Delete all EA cases and re-scrape

**Rationale:**
- Bug caused data corruption (wrong fines) and data loss (missing cases)
- Extent of corruption unknown
- Clean re-scrape ensures data integrity
- Avoids complex manual auditing and correction

**Deployment steps documented in:** `.claude/sessions/2025-10-21.md`

---

**Investigation Session:** 2025-10-21
**Implementation Session:** 2025-10-22
**Test Case:** A & F ROOFING SPECIALISTS LIMITED (EA records 2482, 3424)
**Production Impact:** All EA cases - requires deletion and re-scraping
**Status:** ✅ Fixed, tested, documented, ready for deployment

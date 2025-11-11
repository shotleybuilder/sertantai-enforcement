# Test Cleanup Plan II - File-by-File Approach

**Date Created**: 2025-11-11
**Status**: IN PROGRESS
**GitHub Issue**: [#8 - Fix broken tests to enable test suite in pre-push hook](https://github.com/shotleybuilder/ehs_enforcement/issues/8)
**Related**: `TEST_CLEANUP_PLAN.md` (original plan - deprecated)

---

## Overview

This is a **methodical, file-by-file approach** to achieving a 100% passing test suite. Each test file must:

1. ✅ Compile without errors
2. ✅ Run without failures
3. ✅ Not hit external services (proper mocking)
4. ✅ Run in reasonable time (<5 seconds per file)

**Total Test Files**: 98

---

## Approach

### For Each File:

1. **Run individually**: `mix test path/to/file_test.exs`
2. **Document status**: Pass/Fail/Skip count
3. **Fix issues**: One file at a time, commit when green
4. **Verify**: Re-run to confirm 100% pass
5. **Mark complete**: Check off in list below

### Commit Strategy:

- Commit after each file is 100% passing
- Use descriptive messages: `fix(tests): make agency_test.exs pass (3/98)`
- Link to this plan in commits

---

## Progress Tracker

**Completed**: 6/98 (6%)
**Last Updated**: 2025-11-11

**Status by Category**:
- Agency Logic: 6/11 PASS (55%)
- Enforcement Domain: Not tested yet
- Scraping: Not tested yet
- Utility: Not tested yet
- Components: Not tested yet
- Controllers: Not tested yet
- LiveViews: Not tested yet

---

## Test Files Checklist

### Agency Logic Tests (11 files) - 6/11 PASSING ✓

- [ ] `test/ehs_enforcement/agencies/ea/case_scraper_test.exs` ❌ 1 failure
- [ ] `test/ehs_enforcement/agencies/ea/data_transformer_test.exs` ❌ 1 failure
- [ ] `test/ehs_enforcement/agencies/ea/duplicate_handling_test.exs` ❌ 4 failures
- [x] `test/ehs_enforcement/agencies/ea/offender_matcher_test.exs` ✅ PASS
- [x] `test/ehs_enforcement/agencies/ea/roofing_specialists_bug_test.exs` ✅ PASS
- [ ] `test/ehs_enforcement/agencies/hse/breaches_deduplication_test.exs` ❌ 5 failures
- [ ] `test/ehs_enforcement/agencies/hse/cases_test.exs` ❌ 2 failures
- [x] `test/ehs_enforcement/agencies/hse/offender_builder_test.exs` ✅ PASS
- [x] `test/ehs_enforcement/countries/uk/legl_enforcement/hse_notices_test.exs` ✅ PASS
- [x] `test/ehs_enforcement/consent/storage_test.exs` ✅ PASS
- [x] `test/ehs_enforcement/config/config_integration_test.exs` ✅ PASS

### Enforcement Domain Tests (9 files)

- [ ] `test/ehs_enforcement/enforcement/agency_auto_population_test.exs`
- [ ] `test/ehs_enforcement/enforcement/agency_test.exs`
- [ ] `test/ehs_enforcement/enforcement/case_test.exs`
- [ ] `test/ehs_enforcement/enforcement/enforcement_domain_test.exs`
- [ ] `test/ehs_enforcement/enforcement/legislation_deduplication_test.exs`
- [ ] `test/ehs_enforcement/enforcement/metrics_test.exs`
- [ ] `test/ehs_enforcement/enforcement/offender_test.exs`
- [ ] `test/ehs_enforcement/enforcement/workflows_integration_test.exs`
- [ ] `test/ehs_enforcement/enforcement_test.exs`

### Scraping Tests (21 files)

- [ ] `test/ehs_enforcement/scraping/ea/case_scraper_test.exs`
- [ ] `test/ehs_enforcement/scraping/ea/date_parameter_test.exs`
- [ ] `test/ehs_enforcement/scraping/ea/integration_test.exs`
- [ ] `test/ehs_enforcement/scraping/hse/case_processor_test.exs`
- [ ] `test/ehs_enforcement/scraping/hse/case_scraper_test.exs`
- [ ] `test/ehs_enforcement/scraping/hse/notice_prefiltering_test.exs`
- [ ] `test/ehs_enforcement/scraping/hse/notice_processor_test.exs`
- [ ] `test/ehs_enforcement/scraping/hse_progress_test.exs`
- [ ] `test/ehs_enforcement/scraping/resources/processing_log_test.exs`
- [ ] `test/ehs_enforcement/scraping/resources/scrape_session_test.exs`
- [ ] `test/ehs_enforcement/scraping/scrape_coordinator_test.exs`
- [ ] `test/ehs_enforcement/scraping/scrape_request_test.exs`
- [ ] `test/ehs_enforcement/scraping/strategies/ea/case_strategy_test.exs`
- [ ] `test/ehs_enforcement/scraping/strategies/ea/notice_strategy_test.exs`
- [ ] `test/ehs_enforcement/scraping/strategies/hse/case_strategy_test.exs`
- [ ] `test/ehs_enforcement/scraping/strategies/hse/notice_strategy_test.exs`
- [ ] `test/ehs_enforcement/scraping/strategy_registry_test.exs`
- [ ] `test/ehs_enforcement/scraping/workflows/notice_scraping_integration_test.exs`

### Utility Tests (3 files)

- [ ] `test/ehs_enforcement/error_handler_test.exs`
- [ ] `test/ehs_enforcement/logger_test.exs`
- [ ] `test/ehs_enforcement/retry_logic_test.exs`
- [ ] `test/ehs_enforcement/telemetry_test.exs`
- [ ] `test/ehs_enforcement/utility_test.exs`

### Component Tests (7 files)

- [ ] `test/ehs_enforcement_web/components/agency_card_test.exs`
- [ ] `test/ehs_enforcement_web/components/cases_action_card_test.exs`
- [ ] `test/ehs_enforcement_web/components/dashboard_action_card_test.exs`
- [ ] `test/ehs_enforcement_web/components/notices_action_card_test.exs`
- [ ] `test/ehs_enforcement_web/components/offenders_action_card_test.exs`
- [ ] `test/ehs_enforcement_web/components/reports_action_card_test.exs`
- [ ] `test/ehs_enforcement_web/live/enforcement_timeline_component_test.exs`
- [ ] `test/ehs_enforcement_web/live/notice_timeline_component_test.exs`
- [ ] `test/ehs_enforcement_web/live/offender_card_component_test.exs`
- [ ] `test/ehs_enforcement_web/live/offender_table_component_test.exs`

### Controller Tests (3 files)

- [ ] `test/ehs_enforcement_web/controllers/error_html_test.exs`
- [ ] `test/ehs_enforcement_web/controllers/error_json_test.exs`
- [ ] `test/ehs_enforcement_web/controllers/page_controller_test.exs`

### Admin LiveView Tests (11 files)

- [ ] `test/ehs_enforcement_web/live/admin/case_live/cases_processed_keyerror_test.exs`
- [ ] `test/ehs_enforcement_web/live/admin/case_live/ea_progress_test.exs`
- [ ] `test/ehs_enforcement_web/live/admin/case_live/ea_progress_unit_test.exs`
- [ ] `test/ehs_enforcement_web/live/admin/case_live/ea_records_display_test.exs`
- [ ] `test/ehs_enforcement_web/live/admin/case_live/ea_stop_scraping_test.exs`
- [ ] `test/ehs_enforcement_web/live/admin/case_live/scraping_completion_keyerror_test.exs`
- [ ] `test/ehs_enforcement_web/live/admin/notice_live/ea_notice_progress_test.exs`
- [ ] `test/ehs_enforcement_web/live/admin_routes_test.exs`
- [ ] `test/ehs_enforcement_web/live/admin/scrape_live_test.exs`
- [ ] `test/ehs_enforcement_web/live/admin/scrape_sessions_live_test.exs`
- [ ] `test/ehs_enforcement_web/live/error_boundary_test.exs`

### Case LiveView Tests (5 files)

- [ ] `test/ehs_enforcement_web/live/case_csv_export_test.exs`
- [ ] `test/ehs_enforcement_web/live/case_filter_component_test.exs`
- [ ] `test/ehs_enforcement_web/live/case_live_index_test.exs`
- [ ] `test/ehs_enforcement_web/live/case_live_show_test.exs`
- [ ] `test/ehs_enforcement_web/live/case_manual_entry_test.exs`
- [ ] `test/ehs_enforcement_web/live/case_search_test.exs`

### Dashboard LiveView Tests (12 files)

- [ ] `test/ehs_enforcement_web/live/dashboard_auth_simple_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_auth_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_case_notice_count_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_cases_integration_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_integration_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_live_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_metrics_simple_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_metrics_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_notices_integration_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_offenders_integration_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_period_dropdown_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_recent_activity_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_reports_integration_test.exs`
- [ ] `test/ehs_enforcement_web/live/dashboard_unit_test.exs`

### Notice LiveView Tests (5 files)

- [ ] `test/ehs_enforcement_web/live/notice_compliance_test.exs`
- [ ] `test/ehs_enforcement_web/live/notice_filter_component_test.exs`
- [ ] `test/ehs_enforcement_web/live/notice_live_index_test.exs`
- [ ] `test/ehs_enforcement_web/live/notice_live_show_test.exs`
- [ ] `test/ehs_enforcement_web/live/notice_search_test.exs`

### Offender LiveView Tests (3 files)

- [ ] `test/ehs_enforcement_web/live/offender_integration_test.exs`
- [ ] `test/ehs_enforcement_web/live/offender_live_index_test.exs`
- [ ] `test/ehs_enforcement_web/live/offender_live_show_test.exs`

### Reports LiveView Tests (2 files)

- [ ] `test/ehs_enforcement_web/live/reports_live_offenders_test.exs`
- [ ] `test/ehs_enforcement_web/live/reports_live_test.exs`

### Other LiveView Tests (1 file)

- [ ] `test/ehs_enforcement_web/live/search_debounce_test.exs`

---

## Common Issues Reference

### Issue: Tests hit real websites
**Solution**: Mock HTTP requests with `Req.Test` or `Bypass`

### Issue: Database state contamination
**Solution**: Verify `Ecto.Adapters.SQL.Sandbox` is working, use `async: false` if needed

### Issue: Async/timing issues
**Solution**: Add `Process.sleep()` or use `assert_receive` with timeout

### Issue: Missing test data
**Solution**: Improve fixtures in test setup

### Issue: Undefined variable warnings
**Solution**: Check if variable is actually used before marking as `_unused`

---

## Success Criteria

**Ready for Pre-Push Hook When**:
- ✅ All 98 files pass (100% pass rate)
- ✅ No external HTTP calls (all mocked)
- ✅ Full suite runs in <5 minutes
- ✅ 5 consecutive runs pass (no flakiness)

---

## Progress Log

### 2025-11-11

**Initial Baseline Testing**:
- Created TEST_CLEANUP_PLAN_II.md with all 98 test files
- Tested Agency Logic files (11 total)
- **Results**: 6/11 PASS (55%)
  - ✅ PASS: offender_matcher, roofing_specialists_bug, offender_builder, hse_notices, storage, config_integration
  - ❌ FAIL: case_scraper (1), data_transformer (1), duplicate_handling (4), breaches_deduplication (5), cases (2)
- **Total failures in category**: 13 test failures across 5 files
- **Progress**: 6/98 files passing (6%)

---

**Next Action**: Start with first file in Agency Logic Tests section

#!/bin/bash
# Test runner for Other LiveView Tests (28 files - excludes admin and component tests already counted)
# Usage: ./test/runners/test_liveviews_other.sh
# Note: Automatically skips tests tagged with @moduletag :integration, :external, or :slow

files=(
  "test/ehs_enforcement_web/live/case_csv_export_test.exs"
  "test/ehs_enforcement_web/live/case_live_index_test.exs"
  "test/ehs_enforcement_web/live/case_live_show_test.exs"
  "test/ehs_enforcement_web/live/case_manual_entry_test.exs"
  "test/ehs_enforcement_web/live/case_search_test.exs"
  "test/ehs_enforcement_web/live/dashboard_auth_simple_test.exs"
  "test/ehs_enforcement_web/live/dashboard_auth_test.exs"
  "test/ehs_enforcement_web/live/dashboard_case_notice_count_test.exs"
  "test/ehs_enforcement_web/live/dashboard_cases_integration_test.exs"
  "test/ehs_enforcement_web/live/dashboard_integration_test.exs"
  "test/ehs_enforcement_web/live/dashboard_live_test.exs"
  "test/ehs_enforcement_web/live/dashboard_metrics_simple_test.exs"
  "test/ehs_enforcement_web/live/dashboard_metrics_test.exs"
  "test/ehs_enforcement_web/live/dashboard_notices_integration_test.exs"
  "test/ehs_enforcement_web/live/dashboard_offenders_integration_test.exs"
  "test/ehs_enforcement_web/live/dashboard_period_dropdown_test.exs"
  "test/ehs_enforcement_web/live/dashboard_recent_activity_test.exs"
  "test/ehs_enforcement_web/live/dashboard_reports_integration_test.exs"
  "test/ehs_enforcement_web/live/dashboard_unit_test.exs"
  "test/ehs_enforcement_web/live/notice_compliance_test.exs"
  "test/ehs_enforcement_web/live/notice_live_index_test.exs"
  "test/ehs_enforcement_web/live/notice_live_show_test.exs"
  "test/ehs_enforcement_web/live/notice_search_test.exs"
  "test/ehs_enforcement_web/live/offender_integration_test.exs"
  "test/ehs_enforcement_web/live/offender_live_index_test.exs"
  "test/ehs_enforcement_web/live/offender_live_show_test.exs"
  "test/ehs_enforcement_web/live/reports_live_offenders_test.exs"
  "test/ehs_enforcement_web/live/reports_live_test.exs"
  "test/ehs_enforcement_web/live/search_debounce_test.exs"
)

echo "=== Other LiveView Tests (29 files) ==="
echo ""

pass_count=0
fail_count=0
skipped_count=0

for i in "${!files[@]}"; do
  file="${files[$i]}"
  num=$((i+1))
  echo -n "[$num/29] Testing $(basename "$file")... "

  # Check if file contains integration/external/slow tags
  if grep -q "@moduletag :integration" "$file" 2>/dev/null || \
     grep -q "@moduletag :external" "$file" 2>/dev/null || \
     grep -q "@moduletag :slow" "$file" 2>/dev/null || \
     grep -q "@tag :integration" "$file" 2>/dev/null || \
     grep -q "@tag :external" "$file" 2>/dev/null || \
     grep -q "@tag :slow" "$file" 2>/dev/null || \
     [[ "$file" == *"integration_test.exs" ]]; then
    echo "⚠ SKIPPED (integration/external/slow test)"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  # Run test excluding integration/slow/external tags
  output=$(mix test "$file" --exclude integration --exclude external --exclude slow 2>&1)

  if echo "$output" | grep -q "0 failures"; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
  else
    failures=$(echo "$output" | grep -oP '\d+ failures?' | head -1)
    echo "✗ FAIL ($failures)"
    fail_count=$((fail_count + 1))
  fi
done

echo ""
echo "=== Summary ==="
echo "PASS: $pass_count/29"
echo "FAIL: $fail_count/29"
echo "SKIPPED: $skipped_count/29 (integration/external/slow tests)"

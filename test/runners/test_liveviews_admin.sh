#!/bin/bash
# Test runner for Admin LiveView Tests (11 files)
# Usage: ./test/runners/test_liveviews_admin.sh
# Note: Automatically skips tests tagged with @moduletag :integration, :external, or :slow

files=(
  "test/ehs_enforcement_web/live/admin/case_live/cases_processed_keyerror_test.exs"
  "test/ehs_enforcement_web/live/admin/case_live/ea_progress_test.exs"
  "test/ehs_enforcement_web/live/admin/case_live/ea_progress_unit_test.exs"
  "test/ehs_enforcement_web/live/admin/case_live/ea_records_display_test.exs"
  "test/ehs_enforcement_web/live/admin/case_live/ea_stop_scraping_test.exs"
  "test/ehs_enforcement_web/live/admin/case_live/scraping_completion_keyerror_test.exs"
  "test/ehs_enforcement_web/live/admin/notice_live/ea_notice_progress_test.exs"
  "test/ehs_enforcement_web/live/admin_routes_test.exs"
  "test/ehs_enforcement_web/live/admin/scrape_live_test.exs"
  "test/ehs_enforcement_web/live/admin/scrape_sessions_live_test.exs"
  "test/ehs_enforcement_web/live/error_boundary_test.exs"
)

echo "=== Admin LiveView Tests (11 files) ==="
echo ""

pass_count=0
fail_count=0
skipped_count=0

for i in "${!files[@]}"; do
  file="${files[$i]}"
  num=$((i+1))
  echo -n "[$num/11] Testing $(basename "$file")... "

  # Check if file contains integration/external/slow tags
  if grep -q "@moduletag :integration" "$file" 2>/dev/null || \
     grep -q "@moduletag :external" "$file" 2>/dev/null || \
     grep -q "@moduletag :slow" "$file" 2>/dev/null || \
     grep -q "@tag :integration" "$file" 2>/dev/null || \
     grep -q "@tag :external" "$file" 2>/dev/null || \
     grep -q "@tag :slow" "$file" 2>/dev/null; then
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
echo "PASS: $pass_count/11"
echo "FAIL: $fail_count/11"
echo "SKIPPED: $skipped_count/11 (integration/external/slow tests)"

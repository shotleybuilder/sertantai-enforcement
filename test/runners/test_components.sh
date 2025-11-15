#!/bin/bash
# Test runner for Component Tests (12 files)
# Usage: ./test/runners/test_components.sh

files=(
  "test/ehs_enforcement_web/components/agency_card_test.exs"
  "test/ehs_enforcement_web/components/cases_action_card_test.exs"
  "test/ehs_enforcement_web/components/dashboard_action_card_test.exs"
  "test/ehs_enforcement_web/components/notices_action_card_test.exs"
  "test/ehs_enforcement_web/components/offenders_action_card_test.exs"
  "test/ehs_enforcement_web/components/reports_action_card_test.exs"
  "test/ehs_enforcement_web/live/case_filter_component_test.exs"
  "test/ehs_enforcement_web/live/enforcement_timeline_component_test.exs"
  "test/ehs_enforcement_web/live/notice_filter_component_test.exs"
  "test/ehs_enforcement_web/live/notice_timeline_component_test.exs"
  "test/ehs_enforcement_web/live/offender_card_component_test.exs"
  "test/ehs_enforcement_web/live/offender_table_component_test.exs"
)

echo "=== Component Tests (12 files) ==="
echo ""

pass_count=0
fail_count=0

for i in "${!files[@]}"; do
  file="${files[$i]}"
  num=$((i+1))
  echo -n "[$num/12] Testing $(basename "$file")... "

  output=$(mix test "$file" 2>&1)

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
echo "PASS: $pass_count/12"
echo "FAIL: $fail_count/12"

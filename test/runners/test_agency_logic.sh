#!/bin/bash
# Test runner for Agency Logic tests (11 files)
# Usage: ./test/runners/test_agency_logic.sh

files=(
  "test/ehs_enforcement/agencies/ea/case_scraper_test.exs"
  "test/ehs_enforcement/agencies/ea/data_transformer_test.exs"
  "test/ehs_enforcement/agencies/ea/duplicate_handling_test.exs"
  "test/ehs_enforcement/agencies/ea/offender_matcher_test.exs"
  "test/ehs_enforcement/agencies/ea/roofing_specialists_bug_test.exs"
  "test/ehs_enforcement/agencies/hse/breaches_deduplication_test.exs"
  "test/ehs_enforcement/agencies/hse/cases_test.exs"
  "test/ehs_enforcement/agencies/hse/offender_builder_test.exs"
  "test/ehs_enforcement/countries/uk/legl_enforcement/hse_notices_test.exs"
  "test/ehs_enforcement/consent/storage_test.exs"
  "test/ehs_enforcement/config/config_integration_test.exs"
)

echo "=== Agency Logic Tests (11 files) ==="
echo ""

pass_count=0
fail_count=0

for i in "${!files[@]}"; do
  file="${files[$i]}"
  num=$((i+1))
  echo -n "[$num/11] Testing $(basename "$file")... "

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
echo "PASS: $pass_count/11"
echo "FAIL: $fail_count/11"

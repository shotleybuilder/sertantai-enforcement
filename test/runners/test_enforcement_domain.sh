#!/bin/bash
# Test runner for Enforcement Domain tests (9 files)
# Usage: ./test/runners/test_enforcement_domain.sh

files=(
  "test/ehs_enforcement/enforcement/agency_auto_population_test.exs"
  "test/ehs_enforcement/enforcement/agency_test.exs"
  "test/ehs_enforcement/enforcement/case_test.exs"
  "test/ehs_enforcement/enforcement/enforcement_domain_test.exs"
  "test/ehs_enforcement/enforcement/legislation_deduplication_test.exs"
  "test/ehs_enforcement/enforcement/metrics_test.exs"
  "test/ehs_enforcement/enforcement/offender_test.exs"
  "test/ehs_enforcement/enforcement/workflows_integration_test.exs"
  "test/ehs_enforcement/enforcement_test.exs"
)

echo "=== Enforcement Domain Tests (9 files) ==="
echo ""

pass_count=0
fail_count=0

for i in "${!files[@]}"; do
  file="${files[$i]}"
  num=$((i+1))
  echo -n "[$num/9] Testing $(basename "$file")... "

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
echo "PASS: $pass_count/9"
echo "FAIL: $fail_count/9"

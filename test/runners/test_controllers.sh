#!/bin/bash
# Test runner for Controller Tests (3 files)
# Usage: ./test/runners/test_controllers.sh

files=(
  "test/ehs_enforcement_web/controllers/error_html_test.exs"
  "test/ehs_enforcement_web/controllers/error_json_test.exs"
  "test/ehs_enforcement_web/controllers/page_controller_test.exs"
)

echo "=== Controller Tests (3 files) ==="
echo ""

pass_count=0
fail_count=0

for i in "${!files[@]}"; do
  file="${files[$i]}"
  num=$((i+1))
  echo -n "[$num/3] Testing $(basename "$file")... "

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
echo "PASS: $pass_count/3"
echo "FAIL: $fail_count/3"

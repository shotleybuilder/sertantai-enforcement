#!/bin/bash

files=(
  "test/ehs_enforcement/error_handler_test.exs"
  "test/ehs_enforcement/logger_test.exs"
  "test/ehs_enforcement/retry_logic_test.exs"
  "test/ehs_enforcement/telemetry_test.exs"
  "test/ehs_enforcement/utility_test.exs"
)

echo "=== Utility Tests (5 files) ==="
echo ""

pass_count=0
fail_count=0

for i in "${!files[@]}"; do
  file="${files[$i]}"
  num=$((i+1))
  echo -n "[$num/5] Testing $(basename "$file")... "

  output=$(mix test "$file" 2>&1)

  if echo "$output" | grep -q "0 failures"; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
  else
    failures=$(echo "$output" | grep -oP '\d+ failures?' | head -1)
    if [ -z "$failures" ]; then
      echo "⚠ BROKEN (compile error)"
    else
      echo "✗ FAIL ($failures)"
      fail_count=$((fail_count + 1))
    fi
  fi
done

echo ""
echo "=== Summary ==="
echo "PASS: $pass_count/5"
echo "FAIL: $fail_count/5"

#!/bin/bash

files=(
  "test/ehs_enforcement/scraping/ea/case_scraper_test.exs"
  "test/ehs_enforcement/scraping/ea/date_parameter_test.exs"
  "test/ehs_enforcement/scraping/ea/integration_test.exs"
  "test/ehs_enforcement/scraping/hse/case_processor_test.exs"
  "test/ehs_enforcement/scraping/hse/case_scraper_test.exs"
  "test/ehs_enforcement/scraping/hse/notice_prefiltering_test.exs"
  "test/ehs_enforcement/scraping/hse/notice_processor_test.exs"
  "test/ehs_enforcement/scraping/hse_progress_test.exs"
  "test/ehs_enforcement/scraping/resources/processing_log_test.exs"
  "test/ehs_enforcement/scraping/resources/scrape_session_test.exs"
  "test/ehs_enforcement/scraping/scrape_coordinator_test.exs"
  "test/ehs_enforcement/scraping/scrape_request_test.exs"
  "test/ehs_enforcement/scraping/strategies/ea/case_strategy_test.exs"
  "test/ehs_enforcement/scraping/strategies/ea/notice_strategy_test.exs"
  "test/ehs_enforcement/scraping/strategies/hse/case_strategy_test.exs"
  "test/ehs_enforcement/scraping/strategies/hse/notice_strategy_test.exs"
  "test/ehs_enforcement/scraping/strategy_registry_test.exs"
  "test/ehs_enforcement/scraping/workflows/notice_scraping_integration_test.exs"
)

echo "=== Scraping Tests (18 files - excluding integration tests) ==="
echo ""

pass_count=0
fail_count=0
broken_count=0

for i in "${!files[@]}"; do
  file="${files[$i]}"
  num=$((i+1))
  echo -n "[$num/18] Testing $(basename "$file")... "
  
  # Check if file contains integration tags or external API calls
  if grep -q "@tag :integration" "$file" 2>/dev/null || \
     grep -q "@tag :external" "$file" 2>/dev/null || \
     grep -q "@tag :slow" "$file" 2>/dev/null || \
     [[ "$file" == *"integration_test.exs" ]]; then
    echo "⚠ BROKEN (external API calls)"
    broken_count=$((broken_count + 1))
    continue
  fi
  
  # Run test excluding integration/slow/external tags
  output=$(mix test "$file" --exclude integration --exclude external --exclude slow 2>&1)
  
  if echo "$output" | grep -q "0 failures"; then
    echo "✓ PASS"
    pass_count=$((pass_count + 1))
  else
    failures=$(echo "$output" | grep -oP '\d+ failure' | head -1)
    if [ -z "$failures" ]; then
      failures=$(echo "$output" | grep -oP '\d+ failures' | head -1)
    fi
    if [ -z "$failures" ]; then
      echo "⚠ BROKEN (compile error or no tests)"
      broken_count=$((broken_count + 1))
    else
      echo "✗ FAIL ($failures)"
      fail_count=$((fail_count + 1))
    fi
  fi
done

echo ""
echo "=== Summary ==="
echo "PASS: $pass_count/18"
echo "FAIL: $fail_count/18"
echo "BROKEN/SKIPPED: $broken_count/18"

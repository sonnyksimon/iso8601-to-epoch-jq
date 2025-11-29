#!/bin/bash
# basic structure test to verify modules load correctly

set -e

echo "testing project structure..."
echo ""

PASSED=0
FAILED=0
TEST_START=$(date +%s)

# test 1: Verify core utilities load
echo -n "Test 1: loading core utilities... "
start_time=$(date +%s%3N)
if timeout 3 bash -c 'echo "{}" | jq -L lib "include \"lib/core/utils\"; empty"' > /dev/null 2>&1; then
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

# test 2: Verify error module loads
echo -n "Test 2: loading error module... "
start_time=$(date +%s%3N)
if timeout 3 bash -c 'echo "{}" | jq -L lib "include \"lib/core/error\"; empty"' > /dev/null 2>&1; then
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

# test 3: Verify validation module loads
echo -n "Test 3: loading validation module... "
start_time=$(date +%s%3N)
if timeout 3 bash -c 'echo "{}" | jq -L lib "include \"lib/validation/input_validation\"; empty"' > /dev/null 2>&1; then
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

# test 4: Test input length validation (valid input)
echo -n "Test 4: input length validation (valid)... "
start_time=$(date +%s%3N)
result=$(timeout 3 bash -c 'echo "\"2025-11-28\"" | jq -L lib "include \"lib/validation/input_validation\"; validate_input_length"' 2>&1)
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
if [ "$result" = '"2025-11-28"' ]; then
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

# test 5: Test input length validation (too long)
echo -n "Test 5: input length validation (too long)... "
start_time=$(date +%s%3N)
long_input=$(printf '"%0101d"' 0)  # 101 character string
if timeout 3 bash -c "echo '$long_input' | jq -L lib 'include \"lib/validation/input_validation\"; validate_input_length' 2>&1 | grep -q 'exceeds maximum length'"; then
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

# test 6: Test utility functions
echo -n "Test 6: leap year detection (2024)... "
start_time=$(date +%s%3N)
result=$(timeout 3 bash -c 'echo "2024" | jq -L lib "include \"lib/core/utils\"; is_leap_year(.)"' 2>&1)
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
if [ "$result" = "true" ]; then
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

echo -n "Test 7: leap year detection (2023)... "
start_time=$(date +%s%3N)
result=$(timeout 3 bash -c 'echo "2023" | jq -L lib "include \"lib/core/utils\"; is_leap_year(.)"' 2>&1)
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
if [ "$result" = "false" ]; then
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

echo -n "Test 8: BCE leap year detection (-1)... "
start_time=$(date +%s%3N)
result=$(timeout 3 bash -c 'echo "-1" | jq -L lib "include \"lib/core/utils\"; is_leap_year(.)"' 2>&1)
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
if [ "$result" = "true" ]; then
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

echo -n "Test 9: days in February (leap year)... "
start_time=$(date +%s%3N)
result=$(timeout 3 bash -c 'echo "null" | jq -L lib "include \"lib/core/utils\"; days_in_month(2024; 2)"' 2>&1)
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
if [ "$result" = "29" ]; then
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

echo -n "Test 10: days in February (non-leap)... "
start_time=$(date +%s%3N)
result=$(timeout 3 bash -c 'echo "null" | jq -L lib "include \"lib/core/utils\"; days_in_month(2023; 2)"' 2>&1)
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
if [ "$result" = "28" ]; then
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  echo "✗ FAILED (${duration}ms)"
  FAILED=$((FAILED + 1))
  exit 1
fi

echo -n "Test 11: decimal truncation... "
start_time=$(date +%s%3N)
result=$(timeout 3 bash -c 'echo "3.123456789012" | jq -L lib "include \"lib/core/utils\"; truncate_decimal(9)"' 2>&1)
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
if [ "$result" = "3.123456789" ]; then
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  echo "✗ FAILED (${duration}ms)"
  echo "  expected: 3.123456789"
  echo "  got: $result"
  FAILED=$((FAILED + 1))
  exit 1
fi

# test error formatting
echo -n "Test 12: error formatting... "
start_time=$(date +%s%3N)
result=$(timeout 3 bash -c 'echo "null" | jq -L lib -r "include \"lib/core/error\"; format_error(\"month\"; \"13\"; \"2025-13-01\")"' 2>&1)
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
expected="Invalid month '13' in input '2025-13-01'"
if [ "$result" = "$expected" ]; then
  echo "✓ PASSED (${duration}ms)"
  PASSED=$((PASSED + 1))
else
  echo "✗ FAILED (${duration}ms)"
  echo "  expected: $expected"
  echo "  got: $result"
  FAILED=$((FAILED + 1))
  exit 1
fi

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASSED"
echo "failed: $FAILED"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "all structure tests passed! ✓"
  exit 0
else
  echo "some tests failed."
  exit 1
fi

#!/bin/bash
# test input validation
# tests for input length validation

set -e

echo "testing input validation..."
echo ""

PASS=0
FAIL=0
TEST_START=$(date +%s)

# helper function to run test
run_test() {
  local test_name="$1"
  local input="$2"
  local should_pass="$3"
  local expected_error="$4"
  
  echo -n "running: $test_name... "
  
  local start_time=$(date +%s%3N)
  
  if [ "$should_pass" = "true" ]; then
    # test should pass
    result=$(timeout 3 bash -c "echo '$input' | jq -L lib 'include \"lib/validation/input_validation\"; validate_input_length'" 2>&1)
    local exit_code=$?
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 124 ]; then
      echo "✗ FAILED (TIMEOUT after 3s)"
      FAIL=$((FAIL + 1))
    elif echo "$result" | grep -q "error"; then
      echo "✗ FAILED (${duration}ms - should pass but got error)"
      echo "  input: $input"
      echo "  error: $result"
      FAIL=$((FAIL + 1))
    else
      echo "✓ PASSED (${duration}ms)"
      PASS=$((PASS + 1))
    fi
  else
    # test should fail with specific error
    result=$(timeout 3 bash -c "echo '$input' | jq -L lib 'include \"lib/validation/input_validation\"; validate_input_length'" 2>&1 || true)
    local exit_code=$?
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 124 ]; then
      echo "✗ FAILED (TIMEOUT after 3s)"
      FAIL=$((FAIL + 1))
    elif echo "$result" | grep -q "$expected_error"; then
      echo "✓ PASSED (${duration}ms)"
      PASS=$((PASS + 1))
    else
      echo "✗ FAILED (${duration}ms - expected error not found)"
      echo "  input: $input"
      echo "  Expected error: $expected_error"
      echo "  got: $result"
      FAIL=$((FAIL + 1))
    fi
  fi
}

echo "=== total input length tests ==="
echo ""

# valid inputs (within 100 characters)
run_test "valid short input" '"2025-11-28"' "true" ""
run_test "valid medium input" '"2025-11-28T12:34:56.789+05:30"' "true" ""
run_test "valid long input (58 chars)" '"gregorian:+999999-12-31T23:59:59.999999999+23:59"' "true" ""
run_test "valid at limit (100 chars)" "\"$(printf '%0100d' 0)\"" "true" ""

# invalid inputs (exceeds 100 characters)
run_test "input exceeds 100 chars (101)" "\"$(printf '%0101d' 0)\"" "false" "exceeds maximum length"
run_test "input exceeds 100 chars (150)" "\"$(printf '%0150d' 0)\"" "false" "exceeds maximum length"

echo ""
echo "=== year component length tests ==="
echo ""

# valid year lengths
run_test "year 4 digits" '"2025-11-28"' "true" ""
run_test "year 5 digits" '"+10000-11-28"' "true" ""
run_test "year 6 digits" '"+100000-11-28"' "true" ""
run_test "year 7 digits with sign" '"+999999-11-28"' "true" ""
run_test "year 7 digits negative" '"-999999-11-28"' "true" ""

# invalid year lengths (exceeds 7 digits)
run_test "year 8 digits" '"+1000000-11-28"' "false" "Year component exceeds maximum length"
run_test "year 9 digits" '"+10000000-11-28"' "false" "Year component exceeds maximum length"

echo ""
echo "=== fractional seconds length tests ==="
echo ""

# valid fractional seconds (1-9 digits)
run_test "fractional seconds 1 digit" '"2025-11-28T12:34:56.1Z"' "true" ""
run_test "fractional seconds 5 digits" '"2025-11-28T12:34:56.12345Z"' "true" ""
run_test "fractional seconds 9 digits" '"2025-11-28T12:34:56.123456789Z"' "true" ""

# invalid fractional seconds (exceeds 9 digits)
run_test "fractional seconds 10 digits" '"2025-11-28T12:34:56.1234567890Z"' "false" "Fractional seconds component exceeds maximum length"
run_test "fractional seconds 15 digits" '"2025-11-28T12:34:56.123456789012345Z"' "false" "Fractional seconds component exceeds maximum length"

echo ""
echo "=== fractional minutes length tests ==="
echo ""

# valid fractional minutes (treated as fractional seconds limit)
run_test "fractional minutes 1 digit" '"2025-11-28T12:34.1Z"' "true" ""
run_test "fractional minutes 9 digits" '"2025-11-28T12:34.123456789Z"' "true" ""

# invalid fractional minutes (exceeds 9 digits)
run_test "fractional minutes 10 digits" '"2025-11-28T12:34.1234567890Z"' "false" "Fractional seconds component exceeds maximum length"

echo ""
echo "=== fractional hours length tests ==="
echo ""

# valid fractional hours (treated as fractional seconds limit)
run_test "fractional hours 1 digit" '"2025-11-28T12.1Z"' "true" ""
run_test "fractional hours 9 digits" '"2025-11-28T12.123456789Z"' "true" ""

# invalid fractional hours (exceeds 9 digits)
run_test "fractional hours 10 digits" '"2025-11-28T12.1234567890Z"' "false" "Fractional seconds component exceeds maximum length"

echo ""
echo "=== fractional timezone length tests ==="
echo ""

# valid fractional timezone (1-4 digits)
run_test "fractional timezone 1 digit" '"2025-11-28T12:00+05.1"' "true" ""
run_test "fractional timezone 2 digits" '"2025-11-28T12:00+05.12"' "true" ""
run_test "fractional timezone 4 digits" '"2025-11-28T12:00+05.1234"' "true" ""

# invalid fractional timezone (exceeds 4 digits)
run_test "fractional timezone 5 digits" '"2025-11-28T12:00+05.12345"' "false" "Fractional timezone component exceeds maximum length"
run_test "fractional timezone 10 digits" '"2025-11-28T12:00+05.1234567890"' "false" "Fractional timezone component exceeds maximum length"

echo ""
echo "=== calendar indicator length tests ==="
echo ""

# valid calendar indicators
run_test "calendar indicator 'gregorian'" '"gregorian:2025-11-28"' "true" ""
run_test "calendar indicator 'julian'" '"julian:2025-11-28"' "true" ""
run_test "calendar indicator 'islamic'" '"islamic:1446-05-27"' "true" ""
run_test "calendar indicator 'buddhist'" '"buddhist:2568-11-28"' "true" ""
run_test "calendar indicator 20 chars" '"abcdefghijklmnopqrst:2025-11-28"' "true" ""

# invalid calendar indicators (exceeds 20 characters)
run_test "calendar indicator 21 chars" '"abcdefghijklmnopqrstu:2025-11-28"' "false" "Calendar indicator exceeds maximum length"
run_test "calendar indicator 30 chars" '"abcdefghijklmnopqrstuvwxyzabcd:2025-11-28"' "false" "Calendar indicator exceeds maximum length"

echo ""
echo "=== combined edge cases ==="
echo ""

# valid combined cases
run_test "max year + fractional seconds" '"+999999-12-31T23:59:59.123456789Z"' "true" ""
run_test "max year + fractional timezone" '"+999999-12-31T23:59:59+05.1234"' "true" ""
run_test "calendar + max year + fractional" '"gregorian:+999999-12-31T23:59:59.123456789+05.1234"' "true" ""

# invalid combined cases
run_test "exceeds year + valid fractional" '"+1000000-12-31T23:59:59.123456789Z"' "false" "Year component exceeds maximum length"
run_test "valid year + exceeds fractional seconds" '"+999999-12-31T23:59:59.1234567890Z"' "false" "Fractional seconds component exceeds maximum length"
run_test "valid year + exceeds fractional timezone" '"+999999-12-31T23:59:59+05.12345"' "false" "Fractional timezone component exceeds maximum length"

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASS"
echo "failed: $FAIL"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "all input validation tests passed! ✓"
  exit 0
else
  echo "some tests failed! ✗"
  exit 1
fi

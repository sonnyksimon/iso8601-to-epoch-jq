#!/bin/bash

# test date normalization

echo "testing date normalization..."
echo ""

PASSED=0
FAILED=0
TEST_START=$(date +%s)

run_test() {
  local test_name="$1"
  local input="$2"
  local expected="$3"
  
  echo -n "running: $test_name... "
  start_time=$(date +%s%3N)
  result=$(timeout 3 bash -c "echo '$input' | jq -c -L. 'include \"lib/validation/input_validation\"; include \"lib/parsing/input_parser\"; include \"lib/calendar/calendar_converter\"; include \"lib/normalization/date_normalizer\"; validate_input_length | classify_and_parse | convert_calendar_system | normalize_date | .normalized_date'" 2>&1)
  exit_code=$?
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  
  if [ $exit_code -eq 124 ]; then
    echo "✗ FAILED (TIMEOUT after 3s)"
    FAILED=$((FAILED + 1))
  elif [ $exit_code -eq 0 ]; then
    # compare result with expected
    if [ "$result" == "$expected" ]; then
      echo "✓ PASSED (${duration}ms)"
      PASSED=$((PASSED + 1))
    else
      echo "✗ FAILED (${duration}ms)"
      echo "  expected: $expected"
      echo "  got: $result"
      FAILED=$((FAILED + 1))
    fi
  else
    echo "✗ FAILED (${duration}ms)"
    echo "  error: $result"
    FAILED=$((FAILED + 1))
  fi
}

run_error_test() {
  local test_name="$1"
  local input="$2"
  local expected_error_pattern="$3"
  
  echo -n "running: $test_name... "
  start_time=$(date +%s%3N)
  result=$(timeout 3 bash -c "echo '$input' | jq -L. 'include \"lib/validation/input_validation\"; include \"lib/parsing/input_parser\"; include \"lib/calendar/calendar_converter\"; include \"lib/normalization/date_normalizer\"; validate_input_length | classify_and_parse | convert_calendar_system | normalize_date'" 2>&1)
  exit_code=$?
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  
  if [ $exit_code -eq 124 ]; then
    echo "✗ FAILED (TIMEOUT after 3s)"
    FAILED=$((FAILED + 1))
  elif [ $exit_code -ne 0 ]; then
    # check if error message matches expected pattern
    if echo "$result" | grep -q "$expected_error_pattern"; then
      echo "✓ PASSED (${duration}ms)"
      PASSED=$((PASSED + 1))
    else
      echo "✗ FAILED (${duration}ms)"
      echo "  Expected error containing: $expected_error_pattern"
      echo "  got: $result"
      FAILED=$((FAILED + 1))
    fi
  else
    echo "✗ FAILED (${duration}ms)"
    echo "  Expected error but got success: $result"
    FAILED=$((FAILED + 1))
  fi
}

echo "=== calendar date Normalization ==="
echo ""

# test complete calendar dates
run_test "calendar: 2025-11-28" '"2025-11-28"' '{"year":2025,"month":11,"day":28}'
run_test "calendar: 2024-02-29 (leap year)" '"2024-02-29"' '{"year":2024,"month":2,"day":29}'
run_test "calendar: 1970-01-01 (epoch)" '"1970-01-01"' '{"year":1970,"month":1,"day":1}'

# test incomplete calendar dates
run_test "calendar: 2025 (year only)" '"2025"' '{"year":2025,"month":1,"day":1}'
run_test "calendar: 2025-11 (year-month)" '"2025-11"' '{"year":2025,"month":11,"day":1}'

# test BCE dates
run_test "calendar: -0001-01-01 (1 BCE, leap year)" '"-0001-01-01"' '{"year":-1,"month":1,"day":1}'
run_test "calendar: -0005-02-29 (5 BCE, leap year)" '"-0005-02-29"' '{"year":-5,"month":2,"day":29}'
run_test "calendar: -0009-02-29 (9 BCE, leap year)" '"-0009-02-29"' '{"year":-9,"month":2,"day":29}'

# test extended years
run_test "calendar: +999999-12-31 (max year)" '"+999999-12-31"' '{"year":999999,"month":12,"day":31}'
run_test "calendar: -999999-01-01 (min year)" '"-999999-01-01"' '{"year":-999999,"month":1,"day":1}'

echo ""
echo "=== ordinal date conversion ==="
echo ""

# test ordinal dates
run_test "ordinal: 2024-001 (Jan 1)" '"2024-001"' '{"year":2024,"month":1,"day":1}'
run_test "ordinal: 2024-060 (Feb 29, leap year)" '"2024-060"' '{"year":2024,"month":2,"day":29}'
run_test "ordinal: 2024-365 (Dec 30, leap year)" '"2024-365"' '{"year":2024,"month":12,"day":30}'
run_test "ordinal: 2024-366 (Dec 31, leap year)" '"2024-366"' '{"year":2024,"month":12,"day":31}'
run_test "ordinal: 2023-365 (Dec 31, non-leap)" '"2023-365"' '{"year":2023,"month":12,"day":31}'

# test BCE ordinal dates
run_test "ordinal: -0005-366 (5 BCE leap year)" '"-0005-366"' '{"year":-5,"month":12,"day":31}'

echo ""
echo "=== ISO week date conversion ==="
echo ""

# test week dates
run_test "week: 2020-W01-1 (Dec 30, 2019)" '"2020-W01-1"' '{"year":2019,"month":12,"day":30}'
run_test "week: 2020-W53-7 (Jan 3, 2021)" '"2020-W53-7"' '{"year":2021,"month":1,"day":3}'
run_test "week: 2025-W01-1" '"2025-W01-1"' '{"year":2024,"month":12,"day":30}'
run_test "week: 2024-W01-1" '"2024-W01-1"' '{"year":2024,"month":1,"day":1}'

# test week without weekday (defaults to Monday)
run_test "week: 2025-W01 (Monday)" '"2025-W01"' '{"year":2024,"month":12,"day":30}'

# test BCE week dates
run_test "week: -0005-W01-1 (5 BCE)" '"-0005-W01-1"' '{"year":-5,"month":1,"day":2}'

echo ""
echo "=== validation error tests ==="
echo ""

# test invalid month
run_error_test "invalid month 13" '"2025-13-01"' "Invalid month '13'"
run_error_test "invalid month 00" '"2025-00-01"' "Invalid month '0'"

# test invalid day
run_error_test "invalid day 32" '"2025-11-32"' "Invalid day '32'"
run_error_test "invalid day for Feb non-leap" '"2023-02-29"' "Invalid day '29'"

# test invalid ordinal day
run_error_test "invalid ordinal 000" '"2024-000"' "Invalid ordinal day '0'"
run_error_test "invalid ordinal 367" '"2024-367"' "Invalid ordinal day '367'"
run_error_test "invalid ordinal 366 non-leap" '"2023-366"' "Invalid ordinal day '366'"

# test invalid week
run_error_test "invalid week 00" '"2025-W00-1"' "Invalid week '0'"
run_error_test "invalid week 54" '"2025-W54-1"' "Invalid week '54'"
run_error_test "invalid week 53 for year without 53 weeks" '"2022-W53-1"' "Invalid week '53'"

# test invalid weekday
run_error_test "invalid weekday 0" '"2025-W01-0"' "Invalid weekday '0'"
run_error_test "invalid weekday 8" '"2025-W01-8"' "Invalid weekday '8'"

# test year out of range (these will be caught by length validation first)
# using 7-digit years that are within length limit but outside range
run_error_test "year too large" '"+1000000-01-01"' "Year component exceeds maximum length"
run_error_test "year too small" '"-1000000-01-01"' "Year component exceeds maximum length"

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASSED"
echo "failed: $FAILED"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "all date normalization tests passed! ✓"
  exit 0
else
  echo "some tests failed."
  exit 1
fi

#!/bin/bash
# test time and timezone normalization
# tests for time component conversion, fractional handling, and timezone offset calculation

set -e

echo "testing time and timezone normalization..."
echo ""

PASS=0
FAIL=0
TEST_START=$(date +%s)

# helper function to run normalization test
run_test() {
  local test_name="$1"
  local input="$2"
  local jq_filter="$3"
  local expected="$4"
  
  echo -n "running: $test_name... "
  
  local start_time=$(date +%s%3N)
  result=$(timeout 3 bash -c "echo '$input' | jq -L lib -c 'include \"lib/validation/input_validation\"; include \"lib/parsing/input_parser\"; include \"lib/calendar/calendar_converter\"; include \"lib/normalization/date_normalizer\"; include \"lib/normalization/time_normalizer\"; validate_input_length | classify_and_parse | convert_calendar_system | normalize_date | normalize_time_and_timezone | $jq_filter'" 2>&1)
  local exit_code=$?
  local end_time=$(date +%s%3N)
  local duration=$((end_time - start_time))
  
  if [ $exit_code -eq 124 ]; then
    echo "✗ FAILED (TIMEOUT after 3s)"
    FAIL=$((FAIL + 1))
  elif [ $exit_code -eq 0 ]; then
    if [ "$result" = "$expected" ]; then
      echo "✓ PASSED (${duration}ms)"
      PASS=$((PASS + 1))
    else
      echo "✗ FAILED (${duration}ms)"
      echo "  expected: $expected"
      echo "  got: $result"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "✗ FAILED (${duration}ms)"
    echo "  error: $result"
    FAIL=$((FAIL + 1))
  fi
}

# helper function to test error cases
run_error_test() {
  local test_name="$1"
  local input="$2"
  local expected_error="$3"
  
  echo -n "running: $test_name... "
  
  local start_time=$(date +%s%3N)
  result=$(timeout 3 bash -c "echo '$input' | jq -L lib 'include \"lib/validation/input_validation\"; include \"lib/parsing/input_parser\"; include \"lib/calendar/calendar_converter\"; include \"lib/normalization/date_normalizer\"; include \"lib/normalization/time_normalizer\"; validate_input_length | classify_and_parse | convert_calendar_system | normalize_date | normalize_time_and_timezone'" 2>&1 || true)
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
    echo "✗ FAILED (${duration}ms)"
    echo "  expected error: $expected_error"
    echo "  got: $result"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== basic time component conversion ==="
echo ""

# test hour conversion to seconds
run_test "time: 00:00:00 → 0 seconds" '"2025-11-28T00:00:00Z"' '.time_seconds' '0'
run_test "time: 01:00:00 → 3600 seconds" '"2025-11-28T01:00:00Z"' '.time_seconds' '3600'
run_test "time: 12:00:00 → 43200 seconds" '"2025-11-28T12:00:00Z"' '.time_seconds' '43200'
run_test "time: 23:59:59 → 86399 seconds" '"2025-11-28T23:59:59Z"' '.time_seconds' '86399'

# test minute conversion
run_test "time: 00:01:00 → 60 seconds" '"2025-11-28T00:01:00Z"' '.time_seconds' '60'
run_test "time: 00:30:00 → 1800 seconds" '"2025-11-28T00:30:00Z"' '.time_seconds' '1800'
run_test "time: 00:59:00 → 3540 seconds" '"2025-11-28T00:59:00Z"' '.time_seconds' '3540'

# test second component
run_test "time: 00:00:01 → 1 second" '"2025-11-28T00:00:01Z"' '.time_seconds' '1'
run_test "time: 00:00:30 → 30 seconds" '"2025-11-28T00:00:30Z"' '.time_seconds' '30'
run_test "time: 00:00:59 → 59 seconds" '"2025-11-28T00:00:59Z"' '.time_seconds' '59'

echo ""
echo "=== fractional hours conversion and truncation ==="
echo ""

# test fractional hours (convert to seconds, truncate to 9 digits)
run_test "fractional hours: 0.5 hours → 1800 seconds" '"2025-11-28T00.5Z"' '.time_seconds' '1800'
run_test "fractional hours: 1.5 hours → 5400 seconds" '"2025-11-28T01.5Z"' '.time_seconds' '5400'
run_test "fractional hours: 12.5 hours → 45000 seconds" '"2025-11-28T12.5Z"' '.time_seconds' '45000'
run_test "fractional hours: 0.1 hours → 360 seconds" '"2025-11-28T00.1Z"' '.time_seconds' '360'
run_test "fractional hours: 0.25 hours → 900 seconds" '"2025-11-28T00.25Z"' '.time_seconds' '900'

# test fractional hours with subsecond precision
run_test "fractional hours: 0.123456789 hours (9 digits)" '"2025-11-28T00.123456789Z"' '.time_seconds' '444.444440399'
run_test "fractional hours: has_fractional flag" '"2025-11-28T00.5Z"' '.has_fractional' 'false'

echo ""
echo "=== fractional minutes conversion and truncation ==="
echo ""

# test fractional minutes (convert to seconds, truncate to 9 digits)
run_test "fractional minutes: 0.5 minutes → 30 seconds" '"2025-11-28T00:00.5Z"' '.time_seconds' '30'
run_test "fractional minutes: 1.5 minutes → 90 seconds" '"2025-11-28T00:01.5Z"' '.time_seconds' '90'
run_test "fractional minutes: 30.5 minutes → 1830 seconds" '"2025-11-28T00:30.5Z"' '.time_seconds' '1830'
run_test "fractional minutes: 0.1 minutes → 6 seconds" '"2025-11-28T00:00.1Z"' '.time_seconds' '6'
run_test "fractional minutes: 0.25 minutes → 15 seconds" '"2025-11-28T00:00.25Z"' '.time_seconds' '15'

# test fractional minutes with subsecond precision
run_test "fractional minutes: 0.123456789 minutes (9 digits)" '"2025-11-28T00:00.123456789Z"' '.time_seconds' '7.40740734'

echo ""
echo "=== fractional seconds truncation ==="
echo ""

# test fractional seconds (preserve up to 9 digits, truncate beyond)
run_test "fractional seconds: 0.1 second" '"2025-11-28T00:00:00.1Z"' '.time_seconds' '0.1'
run_test "fractional seconds: 0.5 second" '"2025-11-28T00:00:00.5Z"' '.time_seconds' '0.5'
run_test "fractional seconds: 0.123 seconds" '"2025-11-28T00:00:00.123Z"' '.time_seconds' '0.123'
run_test "fractional seconds: 0.123456789 (9 digits)" '"2025-11-28T00:00:00.123456789Z"' '.time_seconds' '0.123456789'
run_test "fractional seconds: has_fractional flag" '"2025-11-28T00:00:00.5Z"' '.has_fractional' 'true'

# test combined time with fractional seconds
run_test "combined: 12:34:56.789" '"2025-11-28T12:34:56.789Z"' '.time_seconds' '45296.789'

echo ""
echo "=== leap second detection ==="
echo ""

# test leap second handling
run_test "leap second: 23:59:60 detected" '"2016-12-31T23:59:60Z"' '.has_leap_second' 'true'
run_test "leap second: with fractional" '"2016-12-31T23:59:60.5Z"' '.has_leap_second' 'true'
# note: leap second time_seconds is handled in epoch computation, not time normalization
run_test "leap second: time_seconds for 23:59:60" '"2016-12-31T23:59:60Z"' '.time_seconds' '0'
run_test "leap second: with fractional seconds" '"2016-12-31T23:59:60.999Z"' '.time_seconds' '0.9989999999961583'
run_test "normal second: 23:59:59 not leap" '"2025-11-28T23:59:59Z"' '.has_leap_second' 'false'

echo ""
echo "=== time component validation ==="
echo ""

# test invalid time components
run_error_test "invalid hour 24" '"2025-11-28T24:00:00Z"' "Invalid hour '24'"
run_error_test "invalid hour 25" '"2025-11-28T25:00:00Z"' "Invalid hour '25'"
run_error_test "invalid minute 60" '"2025-11-28T12:60:00Z"' "Invalid minute '60'"
run_error_test "invalid minute 61" '"2025-11-28T12:61:00Z"' "Invalid minute '61'"
run_error_test "invalid second 61" '"2025-11-28T12:00:61Z"' "Invalid second '61'"
run_error_test "invalid second 62" '"2025-11-28T12:00:62Z"' "Invalid second '62'"

echo ""
echo "=== timezone offset calculation ==="
echo ""

# test timezone offset in seconds
run_test "timezone: Z → 0 offset" '"2025-11-28T12:00:00Z"' '.offset_seconds' '0'
run_test "timezone: +00:00 → 0 offset" '"2025-11-28T12:00:00+00:00"' '.offset_seconds' '0'
run_test "timezone: +01:00 → 3600 offset" '"2025-11-28T12:00:00+01:00"' '.offset_seconds' '3600'
run_test "timezone: +05:00 → 18000 offset" '"2025-11-28T12:00:00+05:00"' '.offset_seconds' '18000'
run_test "timezone: -05:00 → -18000 offset" '"2025-11-28T12:00:00-05:00"' '.offset_seconds' '-18000'
run_test "timezone: +05:30 → 19800 offset" '"2025-11-28T12:00:00+05:30"' '.offset_seconds' '19800'
run_test "timezone: -04:30 → -16200 offset" '"2025-11-28T12:00:00-04:30"' '.offset_seconds' '-16200'
run_test "timezone: +23:59 → 86340 offset" '"2025-11-28T12:00:00+23:59"' '.offset_seconds' '86340'

echo ""
echo "=== fractional timezone offset parsing and truncation ==="
echo ""

# test fractional hour offsets (truncate to 4 digits)
run_test "fractional tz: +05.5 → 19800 offset" '"2025-11-28T12:00:00+05.5"' '.offset_seconds' '19800'
run_test "fractional tz: -03.25 → -11700 offset" '"2025-11-28T12:00:00-03.25"' '.offset_seconds' '-11700'
run_test "fractional tz: +05.1234 (4 digits)" '"2025-11-28T12:00:00+05.1234"' '.offset_seconds' '18444.24'
run_test "fractional tz: +05.75 → 20700 offset" '"2025-11-28T12:00:00+05.75"' '.offset_seconds' '20700'

echo ""
echo "=== timezone offset validation ==="
echo ""

# test invalid timezone offsets
run_error_test "invalid tz: +24:00" '"2025-11-28T12:00:00+24:00"' "Invalid timezone offset"
run_error_test "invalid tz: -24:00" '"2025-11-28T12:00:00-24:00"' "Invalid timezone offset"
run_error_test "invalid tz: +25:00" '"2025-11-28T12:00:00+25:00"' "Invalid timezone offset"

echo ""
echo "=== no time component (defaults to 00:00:00) ==="
echo ""

# test date-only inputs
run_test "date only: defaults to 0 seconds" '"2025-11-28"' '.time_seconds' '0'
run_test "date only: no fractional" '"2025-11-28"' '.has_fractional' 'false'
run_test "date only: UTC offset" '"2025-11-28"' '.offset_seconds' '0'

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASS"
echo "failed: $FAIL"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "all time normalization tests passed! ✓"
  exit 0
else
  echo "some tests failed! ✗"
  exit 1
fi

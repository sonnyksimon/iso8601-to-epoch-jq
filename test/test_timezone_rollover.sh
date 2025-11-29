#!/bin/bash
# test timezone rollover handling
# tests for day, month, and year boundary crossings when applying timezone offsets

set -e

echo "testing timezone rollover..."
echo ""

PASS=0
FAIL=0
TEST_START=$(date +%s)

# helper function to run rollover test
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

echo "=== rollover to previous day (negative offset) ==="
echo ""

# negative offset causes time to go forward, potentially rolling to next day
# UTC = local time - offset, so 01:00-03:00 = 01:00 - (-03:00) = 04:00 UTC same day
run_test "rollover: 01:00-03:00 date unchanged" '"2025-01-02T01:00:00-03:00"' '.normalized_date.day' '2'
run_test "rollover: 01:00-03:00 time (01:00 + 3 hours)" '"2025-01-02T01:00:00-03:00"' '.time_seconds' '14400'
run_test "rollover: 01:00-03:00 offset" '"2025-01-02T01:00:00-03:00"' '.offset_seconds' '-10800'
# 00:30-01:00 = 00:30 - (-01:00) = 01:30 UTC same day
run_test "rollover: 00:30-01:00 date unchanged" '"2025-01-02T00:30:00-01:00"' '.normalized_date.day' '2'
run_test "rollover: 00:30-01:00 time (00:30 + 1 hour)" '"2025-01-02T00:30:00-01:00"' '.time_seconds' '5400'
run_test "rollover: 00:30-01:00 offset" '"2025-01-02T00:30:00-01:00"' '.offset_seconds' '-3600'

echo ""
echo "=== rollover to previous day (positive offset) ==="
echo ""

# positive offset causes time to go backward, potentially rolling to previous day
# UTC = local time - offset, so 23:00+02:00 = 23:00 - 02:00 = 21:00 UTC same day
run_test "rollover: 23:00+02:00 date unchanged" '"2025-01-01T23:00:00+02:00"' '.normalized_date.day' '1'
run_test "rollover: 23:00+02:00 time (23:00 - 2 hours)" '"2025-01-01T23:00:00+02:00"' '.time_seconds' '75600'
run_test "rollover: 23:00+02:00 offset" '"2025-01-01T23:00:00+02:00"' '.offset_seconds' '7200'
# 23:30+01:00 = 23:30 - 01:00 = 22:30 UTC same day
run_test "rollover: 23:30+01:00 date unchanged" '"2025-01-01T23:30:00+01:00"' '.normalized_date.day' '1'
run_test "rollover: 23:30+01:00 time (23:30 - 1 hour)" '"2025-01-01T23:30:00+01:00"' '.time_seconds' '81000'
run_test "rollover: 23:30+01:00 offset" '"2025-01-01T23:00:00+01:00"' '.offset_seconds' '3600'

echo ""
echo "=== rollover across month boundary ==="
echo ""

# test rollover at month boundaries
# Jan 31 23:00+02:00 = Jan 31 21:00 UTC (no rollover)
run_test "month boundary: Jan 31 23:00+02:00 month" '"2025-01-31T23:00:00+02:00"' '.normalized_date.month' '1'
run_test "month boundary: Jan 31 23:00+02:00 day" '"2025-01-31T23:00:00+02:00"' '.normalized_date.day' '31'
run_test "month boundary: Jan 31 23:00+02:00 time" '"2025-01-31T23:00:00+02:00"' '.time_seconds' '75600'
# Feb 1 01:00-03:00 = Feb 1 04:00 UTC (no rollover)
run_test "month boundary: Feb 1 01:00-03:00 month" '"2025-02-01T01:00:00-03:00"' '.normalized_date.month' '2'
run_test "month boundary: Feb 1 01:00-03:00 day" '"2025-02-01T01:00:00-03:00"' '.normalized_date.day' '1'
run_test "month boundary: Feb 1 01:00-03:00 time" '"2025-02-01T01:00:00-03:00"' '.time_seconds' '14400'

# test leap year February
run_test "leap year: Feb 29 23:00+02:00 month" '"2024-02-29T23:00:00+02:00"' '.normalized_date.month' '2'
run_test "leap year: Feb 29 23:00+02:00 day" '"2024-02-29T23:00:00+02:00"' '.normalized_date.day' '29'
run_test "leap year: Mar 1 01:00-03:00 day" '"2024-03-01T01:00:00-03:00"' '.normalized_date.day' '1'

echo ""
echo "=== rollover across year boundary ==="
echo ""

# test rollover at year boundaries
# Dec 31 23:00+02:00 = Dec 31 21:00 UTC (no rollover)
run_test "year boundary: Dec 31 23:00+02:00 year" '"2024-12-31T23:00:00+02:00"' '.normalized_date.year' '2024'
run_test "year boundary: Dec 31 23:00+02:00 month" '"2024-12-31T23:00:00+02:00"' '.normalized_date.month' '12'
run_test "year boundary: Dec 31 23:00+02:00 day" '"2024-12-31T23:00:00+02:00"' '.normalized_date.day' '31'
run_test "year boundary: Dec 31 23:00+02:00 time" '"2024-12-31T23:00:00+02:00"' '.time_seconds' '75600'
# Jan 1 01:00-03:00 = Jan 1 04:00 UTC (no rollover)
run_test "year boundary: Jan 1 01:00-03:00 year" '"2025-01-01T01:00:00-03:00"' '.normalized_date.year' '2025'
run_test "year boundary: Jan 1 01:00-03:00 month" '"2025-01-01T01:00:00-03:00"' '.normalized_date.month' '1'
run_test "year boundary: Jan 1 01:00-03:00 day" '"2025-01-01T01:00:00-03:00"' '.normalized_date.day' '1'
run_test "year boundary: Jan 1 01:00-03:00 time" '"2025-01-01T01:00:00-03:00"' '.time_seconds' '14400'

echo ""
echo "=== fractional seconds with offset ==="
echo ""

# test that fractional seconds are maintained with timezone offset
# 00:30:45.789-01:00 = 01:30:45.789 UTC
run_test "fractional: seconds with offset applied" '"2025-01-02T00:30:45.789-01:00"' '.time_seconds' '5445.789'
run_test "fractional: date unchanged" '"2025-01-02T00:30:45.789-01:00"' '.normalized_date.day' '2'
run_test "fractional: flag set" '"2025-01-02T00:30:45.789-01:00"' '.has_fractional' 'true'
run_test "fractional: offset stored" '"2025-01-02T00:30:45.789-01:00"' '.offset_seconds' '-3600'

echo ""
echo "=== fractional timezone offset ==="
echo ""

# test fractional hour offset application
# 23:00+05.5 = 23:00 - 05:30 = 17:30 UTC same day
run_test "fractional tz: +05.5 date unchanged" '"2025-01-01T23:00:00+05.5"' '.normalized_date.day' '1'
run_test "fractional tz: +05.5 time (23:00 - 5.5 hours)" '"2025-01-01T23:00:00+05.5"' '.time_seconds' '63000'
run_test "fractional tz: +05.5 offset" '"2025-01-01T23:00:00+05.5"' '.offset_seconds' '19800'
# 01:00-03.25 = 01:00 + 03:15 = 04:15 UTC same day
run_test "fractional tz: -03.25 date unchanged" '"2025-01-02T01:00:00-03.25"' '.normalized_date.day' '2'
run_test "fractional tz: -03.25 time (01:00 + 3.25 hours)" '"2025-01-02T01:00:00-03.25"' '.time_seconds' '15300'
run_test "fractional tz: -03.25 offset" '"2025-01-02T01:00:00-03.25"' '.offset_seconds' '-11700'

echo ""
echo "=== midnight with offsets ==="
echo ""

# test times exactly at midnight with offsets
# 00:00+01:00 = 00:00 - 01:00 = 23:00 previous day
run_test "midnight: 00:00+01:00 rolls to previous day" '"2025-01-02T00:00:00+01:00"' '.normalized_date.day' '1'
run_test "midnight: 00:00+01:00 time (23:00)" '"2025-01-02T00:00:00+01:00"' '.time_seconds' '82800'
run_test "midnight: 00:00+01:00 offset" '"2025-01-02T00:00:00+01:00"' '.offset_seconds' '3600'
# 00:00-01:00 = 00:00 + 01:00 = 01:00 same day
run_test "midnight: 00:00-01:00 date unchanged" '"2025-01-02T00:00:00-01:00"' '.normalized_date.day' '2'
run_test "midnight: 00:00-01:00 time (01:00)" '"2025-01-02T00:00:00-01:00"' '.time_seconds' '3600'
run_test "midnight: 00:00-01:00 offset" '"2025-01-02T00:00:00-01:00"' '.offset_seconds' '-3600'

echo ""
echo "=== ordinal date with offset ==="
echo ""

# test ordinal dates with timezone offsets
run_test "ordinal: 2024-366 23:00+02:00 year" '"2024-366T23:00:00+02:00"' '.normalized_date.year' '2024'
run_test "ordinal: 2024-366 23:00+02:00 month" '"2024-366T23:00:00+02:00"' '.normalized_date.month' '12'
run_test "ordinal: 2024-366 23:00+02:00 day" '"2024-366T23:00:00+02:00"' '.normalized_date.day' '31'
run_test "ordinal: 2024-366 23:00+02:00 offset" '"2024-366T23:00:00+02:00"' '.offset_seconds' '7200'

echo ""
echo "=== week date with offset ==="
echo ""

# test week dates with timezone offsets
run_test "week: 2020-W53-7 23:00+02:00 day" '"2020-W53-7T23:00:00+02:00"' '.normalized_date.day' '3'
run_test "week: 2020-W53-7 23:00+02:00 month" '"2020-W53-7T23:00:00+02:00"' '.normalized_date.month' '1'
run_test "week: 2020-W53-7 23:00+02:00 year" '"2020-W53-7T23:00:00+02:00"' '.normalized_date.year' '2021'
run_test "week: 2020-W53-7 23:00+02:00 offset" '"2020-W53-7T23:00:00+02:00"' '.offset_seconds' '7200'

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASS"
echo "failed: $FAIL"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "all timezone rollover tests passed! ✓"
  exit 0
else
  echo "some tests failed! ✗"
  exit 1
fi

#!/bin/bash
# test component validation
# tests for year, date, time, and timezone validation

set -e

echo "testing component validation..."
echo ""

PASS=0
FAIL=0
TEST_START=$(date +%s)

# helper function to run validation test
run_test() {
  local test_name="$1"
  local jq_expr="$2"
  local should_pass="$3"
  local expected_error="$4"
  
  echo -n "running: $test_name... "
  
  local start_time=$(date +%s%3N)
  
  if [ "$should_pass" = "true" ]; then
    # test should pass
    result=$(timeout 3 bash -c "echo 'null' | jq -L lib '$jq_expr'" 2>&1)
    local exit_code=$?
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 124 ]; then
      echo "✗ FAILED (TIMEOUT after 3s)"
      FAIL=$((FAIL + 1))
    elif echo "$result" | grep -q "error"; then
      echo "✗ FAILED (${duration}ms - should pass but got error)"
      echo "  expression: $jq_expr"
      echo "  error: $result"
      FAIL=$((FAIL + 1))
    else
      echo "✓ PASSED (${duration}ms)"
      PASS=$((PASS + 1))
    fi
  else
    # test should fail with specific error
    result=$(timeout 3 bash -c "echo 'null' | jq -L lib '$jq_expr'" 2>&1 || true)
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
      echo "  expression: $jq_expr"
      echo "  expected error: $expected_error"
      echo "  got: $result"
      FAIL=$((FAIL + 1))
    fi
  fi
}

echo "=== year range validation tests ==="
echo ""

# valid years
run_test "year 1970" 'include "lib/validation/component_validation"; validate_year_range(1970; "1970-01-01")' "true" ""
run_test "year 2025" 'include "lib/validation/component_validation"; validate_year_range(2025; "2025-11-28")' "true" ""
run_test "year -1 (1 BCE)" 'include "lib/validation/component_validation"; validate_year_range(-1; "-0001-01-01")' "true" ""
run_test "year -999999 (min)" 'include "lib/validation/component_validation"; validate_year_range(-999999; "-999999-01-01")' "true" ""
run_test "year 999999 (max)" 'include "lib/validation/component_validation"; validate_year_range(999999; "+999999-12-31")' "true" ""
run_test "year 0" 'include "lib/validation/component_validation"; validate_year_range(0; "0000-01-01")' "true" ""

# invalid years
run_test "year -1000000 (below min)" 'include "lib/validation/component_validation"; validate_year_range(-1000000; "-1000000-01-01")' "false" "outside supported range"
run_test "year 1000000 (above max)" 'include "lib/validation/component_validation"; validate_year_range(1000000; "+1000000-01-01")' "false" "outside supported range"

echo ""
echo "=== month validation tests ==="
echo ""

# valid months
run_test "month 1 (january)" 'include "lib/validation/component_validation"; validate_month(1; "2025-01-01")' "true" ""
run_test "month 6 (june)" 'include "lib/validation/component_validation"; validate_month(6; "2025-06-15")' "true" ""
run_test "month 12 (december)" 'include "lib/validation/component_validation"; validate_month(12; "2025-12-31")' "true" ""

# invalid months
run_test "month 0" 'include "lib/validation/component_validation"; validate_month(0; "2025-00-01")' "false" "Invalid month"
run_test "month 13" 'include "lib/validation/component_validation"; validate_month(13; "2025-13-01")' "false" "Invalid month"
run_test "month -1" 'include "lib/validation/component_validation"; validate_month(-1; "2025--1-01")' "false" "Invalid month"

echo ""
echo "=== day validation tests ==="
echo ""

# valid days
run_test "day 1" 'include "lib/validation/component_validation"; validate_day(2025; 1; 1; "2025-01-01")' "true" ""
run_test "day 31 in january" 'include "lib/validation/component_validation"; validate_day(2025; 1; 31; "2025-01-31")' "true" ""
run_test "day 28 in february (non-leap)" 'include "lib/validation/component_validation"; validate_day(2025; 2; 28; "2025-02-28")' "true" ""
run_test "day 29 in february (leap)" 'include "lib/validation/component_validation"; validate_day(2024; 2; 29; "2024-02-29")' "true" ""
run_test "day 30 in april" 'include "lib/validation/component_validation"; validate_day(2025; 4; 30; "2025-04-30")' "true" ""

# invalid days
run_test "day 0" 'include "lib/validation/component_validation"; validate_day(2025; 1; 0; "2025-01-00")' "false" "Invalid day"
run_test "day 32 in january" 'include "lib/validation/component_validation"; validate_day(2025; 1; 32; "2025-01-32")' "false" "Invalid day"
run_test "day 29 in february (non-leap)" 'include "lib/validation/component_validation"; validate_day(2025; 2; 29; "2025-02-29")' "false" "Invalid day"
run_test "day 31 in april" 'include "lib/validation/component_validation"; validate_day(2025; 4; 31; "2025-04-31")' "false" "Invalid day"

echo ""
echo "=== calendar date validation tests ==="
echo ""

# valid calendar dates
run_test "valid date 2025-01-01" 'include "lib/validation/component_validation"; validate_calendar_date(2025; 1; 1; "2025-01-01")' "true" ""
run_test "valid date 2024-02-29 (leap)" 'include "lib/validation/component_validation"; validate_calendar_date(2024; 2; 29; "2024-02-29")' "true" ""
run_test "valid date -1-12-31 (BCE)" 'include "lib/validation/component_validation"; validate_calendar_date(-1; 12; 31; "-0001-12-31")' "true" ""

# invalid calendar dates
run_test "invalid month 13" 'include "lib/validation/component_validation"; validate_calendar_date(2025; 13; 1; "2025-13-01")' "false" "Invalid month"
run_test "invalid day 32" 'include "lib/validation/component_validation"; validate_calendar_date(2025; 1; 32; "2025-01-32")' "false" "Invalid day"
run_test "invalid year range" 'include "lib/validation/component_validation"; validate_calendar_date(1000000; 1; 1; "+1000000-01-01")' "false" "outside supported range"

echo ""
echo "=== ordinal day validation tests ==="
echo ""

# valid ordinal days
run_test "ordinal day 1" 'include "lib/validation/component_validation"; validate_ordinal_day(2025; 1; "2025-001")' "true" ""
run_test "ordinal day 60 (non-leap)" 'include "lib/validation/component_validation"; validate_ordinal_day(2025; 60; "2025-060")' "true" ""
run_test "ordinal day 365 (non-leap)" 'include "lib/validation/component_validation"; validate_ordinal_day(2025; 365; "2025-365")' "true" ""
run_test "ordinal day 366 (leap)" 'include "lib/validation/component_validation"; validate_ordinal_day(2024; 366; "2024-366")' "true" ""

# invalid ordinal days
run_test "ordinal day 0" 'include "lib/validation/component_validation"; validate_ordinal_day(2025; 0; "2025-000")' "false" "Invalid ordinal day"
run_test "ordinal day 366 (non-leap)" 'include "lib/validation/component_validation"; validate_ordinal_day(2025; 366; "2025-366")' "false" "Invalid ordinal day"
run_test "ordinal day 367" 'include "lib/validation/component_validation"; validate_ordinal_day(2024; 367; "2024-367")' "false" "Invalid ordinal day"

echo ""
echo "=== ordinal date validation tests ==="
echo ""

# valid ordinal dates
run_test "valid ordinal 2025-001" 'include "lib/validation/component_validation"; validate_ordinal_date(2025; 1; "2025-001")' "true" ""
run_test "valid ordinal 2024-366 (leap)" 'include "lib/validation/component_validation"; validate_ordinal_date(2024; 366; "2024-366")' "true" ""

# invalid ordinal dates
run_test "invalid ordinal 2025-366 (non-leap)" 'include "lib/validation/component_validation"; validate_ordinal_date(2025; 366; "2025-366")' "false" "Invalid ordinal day"
run_test "invalid ordinal year range" 'include "lib/validation/component_validation"; validate_ordinal_date(1000000; 1; "+1000000-001")' "false" "outside supported range"

echo ""
echo "=== week number validation tests ==="
echo ""

# valid week numbers
run_test "week 1" 'include "lib/validation/component_validation"; validate_week_number(2025; 1; "2025-W01")' "true" ""
run_test "week 52" 'include "lib/validation/component_validation"; validate_week_number(2025; 52; "2025-W52")' "true" ""
run_test "week 53 (year with 53 weeks)" 'include "lib/validation/component_validation"; validate_week_number(2020; 53; "2020-W53")' "true" ""

# invalid week numbers
run_test "week 0" 'include "lib/validation/component_validation"; validate_week_number(2025; 0; "2025-W00")' "false" "Invalid week number"
run_test "week 53 (year with 52 weeks)" 'include "lib/validation/component_validation"; validate_week_number(2022; 53; "2022-W53")' "false" "Invalid week number"
run_test "week 54" 'include "lib/validation/component_validation"; validate_week_number(2025; 54; "2025-W54")' "false" "Invalid week number"

echo ""
echo "=== weekday validation tests ==="
echo ""

# valid weekdays
run_test "weekday 1 (monday)" 'include "lib/validation/component_validation"; validate_weekday(1; "2025-W01-1")' "true" ""
run_test "weekday 4 (thursday)" 'include "lib/validation/component_validation"; validate_weekday(4; "2025-W01-4")' "true" ""
run_test "weekday 7 (sunday)" 'include "lib/validation/component_validation"; validate_weekday(7; "2025-W01-7")' "true" ""

# invalid weekdays
run_test "weekday 0" 'include "lib/validation/component_validation"; validate_weekday(0; "2025-W01-0")' "false" "Invalid weekday"
run_test "weekday 8" 'include "lib/validation/component_validation"; validate_weekday(8; "2025-W01-8")' "false" "Invalid weekday"

echo ""
echo "=== week date validation tests ==="
echo ""

# valid week dates
run_test "valid week date 2025-W01-1" 'include "lib/validation/component_validation"; validate_week_date(2025; 1; 1; "2025-W01-1")' "true" ""
run_test "valid week date 2020-W53-7" 'include "lib/validation/component_validation"; validate_week_date(2020; 53; 7; "2020-W53-7")' "true" ""

# invalid week dates
run_test "invalid week 53 for 2022" 'include "lib/validation/component_validation"; validate_week_date(2022; 53; 1; "2022-W53-1")' "false" "Invalid week number"
run_test "invalid weekday 0" 'include "lib/validation/component_validation"; validate_week_date(2025; 1; 0; "2025-W01-0")' "false" "Invalid weekday"
run_test "invalid year range" 'include "lib/validation/component_validation"; validate_week_date(1000000; 1; 1; "+1000000-W01-1")' "false" "outside supported range"

echo ""
echo "=== hour validation tests ==="
echo ""

# valid hours
run_test "hour 0" 'include "lib/validation/component_validation"; validate_hour(0; "2025-01-01T00:00:00")' "true" ""
run_test "hour 12" 'include "lib/validation/component_validation"; validate_hour(12; "2025-01-01T12:00:00")' "true" ""
run_test "hour 23" 'include "lib/validation/component_validation"; validate_hour(23; "2025-01-01T23:00:00")' "true" ""

# invalid hours
run_test "hour -1" 'include "lib/validation/component_validation"; validate_hour(-1; "2025-01-01T-1:00:00")' "false" "Invalid hour"
run_test "hour 24" 'include "lib/validation/component_validation"; validate_hour(24; "2025-01-01T24:00:00")' "false" "Invalid hour"
run_test "hour 25" 'include "lib/validation/component_validation"; validate_hour(25; "2025-01-01T25:00:00")' "false" "Invalid hour"

echo ""
echo "=== minute validation tests ==="
echo ""

# valid minutes
run_test "minute 0" 'include "lib/validation/component_validation"; validate_minute(0; "2025-01-01T12:00:00")' "true" ""
run_test "minute 30" 'include "lib/validation/component_validation"; validate_minute(30; "2025-01-01T12:30:00")' "true" ""
run_test "minute 59" 'include "lib/validation/component_validation"; validate_minute(59; "2025-01-01T12:59:00")' "true" ""

# invalid minutes
run_test "minute -1" 'include "lib/validation/component_validation"; validate_minute(-1; "2025-01-01T12:-1:00")' "false" "Invalid minute"
run_test "minute 60" 'include "lib/validation/component_validation"; validate_minute(60; "2025-01-01T12:60:00")' "false" "Invalid minute"
run_test "minute 61" 'include "lib/validation/component_validation"; validate_minute(61; "2025-01-01T12:61:00")' "false" "Invalid minute"

echo ""
echo "=== second validation tests ==="
echo ""

# valid seconds
run_test "second 0" 'include "lib/validation/component_validation"; validate_second(0; "2025-01-01T12:00:00")' "true" ""
run_test "second 30" 'include "lib/validation/component_validation"; validate_second(30; "2025-01-01T12:00:30")' "true" ""
run_test "second 59" 'include "lib/validation/component_validation"; validate_second(59; "2025-01-01T12:00:59")' "true" ""
run_test "second 60 (leap second)" 'include "lib/validation/component_validation"; validate_second(60; "2016-12-31T23:59:60")' "true" ""

# invalid seconds
run_test "second -1" 'include "lib/validation/component_validation"; validate_second(-1; "2025-01-01T12:00:-1")' "false" "Invalid second"
run_test "second 61" 'include "lib/validation/component_validation"; validate_second(61; "2025-01-01T12:00:61")' "false" "Invalid second"
run_test "second 62" 'include "lib/validation/component_validation"; validate_second(62; "2025-01-01T12:00:62")' "false" "Invalid second"

echo ""
echo "=== time validation tests ==="
echo ""

# valid times
run_test "valid time 00:00:00" 'include "lib/validation/component_validation"; validate_time(0; 0; 0; "2025-01-01T00:00:00")' "true" ""
run_test "valid time 12:34:56" 'include "lib/validation/component_validation"; validate_time(12; 34; 56; "2025-01-01T12:34:56")' "true" ""
run_test "valid time 23:59:59" 'include "lib/validation/component_validation"; validate_time(23; 59; 59; "2025-01-01T23:59:59")' "true" ""
run_test "valid time 23:59:60 (leap)" 'include "lib/validation/component_validation"; validate_time(23; 59; 60; "2016-12-31T23:59:60")' "true" ""

# invalid times
run_test "invalid hour 24" 'include "lib/validation/component_validation"; validate_time(24; 0; 0; "2025-01-01T24:00:00")' "false" "Invalid hour"
run_test "invalid minute 60" 'include "lib/validation/component_validation"; validate_time(12; 60; 0; "2025-01-01T12:60:00")' "false" "Invalid minute"
run_test "invalid second 61" 'include "lib/validation/component_validation"; validate_time(12; 0; 61; "2025-01-01T12:00:61")' "false" "Invalid second"

echo ""
echo "=== timezone offset validation tests ==="
echo ""

# valid timezone offsets (in seconds)
run_test "offset 0 (UTC)" 'include "lib/validation/component_validation"; validate_timezone_offset(0; "2025-01-01T12:00:00Z")' "true" ""
run_test "offset +5 hours" 'include "lib/validation/component_validation"; validate_timezone_offset(18000; "2025-01-01T12:00:00+05:00")' "true" ""
run_test "offset -5 hours" 'include "lib/validation/component_validation"; validate_timezone_offset(-18000; "2025-01-01T12:00:00-05:00")' "true" ""
run_test "offset +23:59" 'include "lib/validation/component_validation"; validate_timezone_offset(86340; "2025-01-01T12:00:00+23:59")' "true" ""
run_test "offset -23:59" 'include "lib/validation/component_validation"; validate_timezone_offset(-86340; "2025-01-01T12:00:00-23:59")' "true" ""

# invalid timezone offsets (≥±24 hours = ±86400 seconds)
run_test "offset +24:00" 'include "lib/validation/component_validation"; validate_timezone_offset(86400; "2025-01-01T12:00:00+24:00")' "false" "Invalid timezone offset"
run_test "offset -24:00" 'include "lib/validation/component_validation"; validate_timezone_offset(-86400; "2025-01-01T12:00:00-24:00")' "false" "Invalid timezone offset"
run_test "offset +25:00" 'include "lib/validation/component_validation"; validate_timezone_offset(90000; "2025-01-01T12:00:00+25:00")' "false" "Invalid timezone offset"

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASS"
echo "failed: $FAIL"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "all component validation tests passed! ✓"
  exit 0
else
  echo "some tests failed! ✗"
  exit 1
fi

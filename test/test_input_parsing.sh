#!/bin/bash
# test input classification and parsing
# tests for date format detection, time parsing, timezone parsing, and calendar system indicators

set -e

echo "testing input classification and parsing..."
echo ""

PASS=0
FAIL=0
TEST_START=$(date +%s)

# helper function to run parsing test
run_test() {
  local test_name="$1"
  local input="$2"
  local jq_filter="$3"
  local expected="$4"
  
  echo -n "running: $test_name... "
  
  local start_time=$(date +%s%3N)
  result=$(timeout 3 bash -c "echo '$input' | jq -L lib -c 'include \"lib/validation/input_validation\"; include \"lib/parsing/input_parser\"; validate_input_length | classify_and_parse | $jq_filter'" 2>&1)
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
  result=$(timeout 3 bash -c "echo '$input' | jq -L lib 'include \"lib/validation/input_validation\"; include \"lib/parsing/input_parser\"; validate_input_length | classify_and_parse'" 2>&1 || true)
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

echo "=== calendar date format detection ==="
echo ""

# test calendar date patterns with precedence
run_test "calendar: YYYY-MM-DD" '"2025-11-28"' '.date_format' '"calendar"'
run_test "calendar: YYYY-MM" '"2025-11"' '.date_format' '"calendar"'
run_test "calendar: YYYY" '"2025"' '.date_format' '"calendar"'
run_test "calendar: YYYYMMDD" '"20251128"' '.date_format' '"calendar"'
run_test "calendar: extended year +YYYYYY-MM-DD" '"+999999-12-31"' '.date_format' '"calendar"'
run_test "calendar: BCE year -YYYY-MM-DD" '"-0001-01-01"' '.date_format' '"calendar"'

# test calendar date component extraction
run_test "calendar: extract year from 2025-11-28" '"2025-11-28"' '.date_parts.year' '2025'
run_test "calendar: extract month from 2025-11-28" '"2025-11-28"' '.date_parts.month' '11'
run_test "calendar: extract day from 2025-11-28" '"2025-11-28"' '.date_parts.day' '28'
run_test "calendar: year only has null month" '"2025"' '.date_parts.month' 'null'
run_test "calendar: year-month has null day" '"2025-11"' '.date_parts.day' 'null'

echo ""
echo "=== ordinal date format detection ==="
echo ""

# test ordinal date patterns
run_test "ordinal: YYYY-DDD" '"2024-060"' '.date_format' '"ordinal"'
run_test "ordinal: YYYYDDD" '"2024060"' '.date_format' '"ordinal"'
run_test "ordinal: extended year +YYYYYY-DDD" '"+999999-365"' '.date_format' '"ordinal"'
run_test "ordinal: BCE year -YYYY-DDD" '"-0004-366"' '.date_format' '"ordinal"'

# test ordinal date component extraction
run_test "ordinal: extract year from 2024-060" '"2024-060"' '.date_parts.year' '2024'
run_test "ordinal: extract ordinal day from 2024-060" '"2024-060"' '.date_parts.ordinal_day' '60'
run_test "ordinal: extract ordinal day from 2024366" '"2024366"' '.date_parts.ordinal_day' '366'

echo ""
echo "=== week date format detection ==="
echo ""

# test week date patterns
run_test "week: YYYY-Www-D" '"2025-W48-5"' '.date_format' '"week"'
run_test "week: YYYYWwwD" '"2025W485"' '.date_format' '"week"'
run_test "week: YYYY-Www" '"2025-W48"' '.date_format' '"week"'
run_test "week: YYYYWww" '"2025W48"' '.date_format' '"week"'
run_test "week: extended year +YYYYYY-Www-D" '"+999999-W52-7"' '.date_format' '"week"'
run_test "week: BCE year -YYYY-Www-D" '"-0004-W01-1"' '.date_format' '"week"'

# test week date component extraction
run_test "week: extract year from 2025-W48-5" '"2025-W48-5"' '.date_parts.year' '2025'
run_test "week: extract week from 2025-W48-5" '"2025-W48-5"' '.date_parts.week' '48'
run_test "week: extract weekday from 2025-W48-5" '"2025-W48-5"' '.date_parts.weekday' '5'
run_test "week: week without weekday has null" '"2025-W48"' '.date_parts.weekday' 'null'

echo ""
echo "=== time format parsing ==="
echo ""

# test time patterns
run_test "time: Thh" '"2025-11-28T12"' '.time_parts.hour' '12'
run_test "time: Thh:mm" '"2025-11-28T12:34"' '.time_parts.minute' '34'
run_test "time: Thhmm" '"2025-11-28T1234"' '.time_parts.minute' '34'
run_test "time: Thh:mm:ss" '"2025-11-28T12:34:56"' '.time_parts.second' '56'
run_test "time: Thhmmss" '"2025-11-28T123456"' '.time_parts.second' '56'

# test fractional time components
run_test "time: fractional hours Thh.h" '"2025-11-28T12.5"' '.time_parts.fractional' '"5"'
run_test "time: fractional hours unit" '"2025-11-28T12.5"' '.time_parts.fractional_unit' '"hour"'
run_test "time: fractional minutes Thh:mm.m" '"2025-11-28T12:34.5"' '.time_parts.fractional' '"5"'
run_test "time: fractional minutes unit" '"2025-11-28T12:34.5"' '.time_parts.fractional_unit' '"minute"'
run_test "time: fractional seconds Thh:mm:ss.s" '"2025-11-28T12:34:56.789"' '.time_parts.fractional' '"789"'
run_test "time: fractional seconds unit" '"2025-11-28T12:34:56.789"' '.time_parts.fractional_unit' '"second"'
run_test "time: 9 digit fractional seconds" '"2025-11-28T12:34:56.123456789"' '.time_parts.fractional' '"123456789"'

# test leap second detection
run_test "time: leap second 60" '"2016-12-31T23:59:60Z"' '.has_leap_second' 'true'
run_test "time: leap second with fractional" '"2016-12-31T23:59:60.5Z"' '.has_leap_second' 'true'
run_test "time: normal second 59" '"2025-11-28T23:59:59Z"' '.has_leap_second' 'false'

echo ""
echo "=== timezone format parsing ==="
echo ""

# test timezone patterns
run_test "timezone: Z indicator" '"2025-11-28T12:00Z"' '.timezone.indicator' '"Z"'
run_test "timezone: +hh" '"2025-11-28T12:00+05"' '.timezone.offset_hours' '5'
run_test "timezone: -hh sign" '"2025-11-28T12:00-05"' '.timezone.sign' '"-"'
run_test "timezone: -hh hours" '"2025-11-28T12:00-05"' '.timezone.offset_hours' '5'
run_test "timezone: +hhmm" '"2025-11-28T12:00+0530"' '.timezone.offset_minutes' '30'
run_test "timezone: +hh:mm" '"2025-11-28T12:00+05:30"' '.timezone.offset_minutes' '30'
run_test "timezone: -hh:mm" '"2025-11-28T12:00-05:30"' '.timezone.offset_minutes' '30'

# test fractional timezone offsets
run_test "timezone: +hh.h fractional" '"2025-11-28T12:00+05.5"' '.timezone.offset_fractional' '"5"'
run_test "timezone: +hh.hhhh fractional" '"2025-11-28T12:00+05.1234"' '.timezone.offset_fractional' '"1234"'
run_test "timezone: -hh.hh fractional" '"2025-11-28T12:00-03.25"' '.timezone.offset_fractional' '"25"'

# test no timezone (defaults to UTC)
run_test "timezone: no timezone indicator" '"2025-11-28T12:00"' '.timezone' 'null'
run_test "timezone: date only no timezone" '"2025-11-28"' '.timezone' 'null'

echo ""
echo "=== calendar system indicator parsing ==="
echo ""

# test calendar system indicators
run_test "calendar system: gregorian" '"gregorian:2025-11-28"' '.calendar_system' '"gregorian"'
run_test "calendar system: julian" '"julian:2025-11-28"' '.calendar_system' '"julian"'
run_test "calendar system: islamic" '"islamic:1446-05-27"' '.calendar_system' '"islamic"'
run_test "calendar system: buddhist" '"buddhist:2568-11-28"' '.calendar_system' '"buddhist"'
run_test "calendar system: hebrew" '"hebrew:5786-03-15"' '.calendar_system' '"hebrew"'
run_test "calendar system: persian" '"persian:1404-09-07"' '.calendar_system' '"persian"'
run_test "calendar system: chinese" '"chinese:4723-10-15"' '.calendar_system' '"chinese"'
run_test "calendar system: default gregorian" '"2025-11-28"' '.calendar_system' '"gregorian"'

echo ""
echo "=== ambiguous format rejection ==="
echo ""

# test ambiguous formats
run_error_test "ambiguous: YYYYMM" '"202511"' "Ambiguous date format"
# note: "20251" is parsed as year 20251 (5-digit year), not ambiguous

echo ""
echo "=== pattern matching precedence ==="
echo ""

# test that more specific patterns match first
run_test "precedence: YYYY-MM-DD over YYYY-MM" '"2025-11-28"' '.date_format' '"calendar"'
run_test "precedence: YYYY-MM over YYYY" '"2025-11"' '.date_format' '"calendar"'
run_test "precedence: YYYY-DDD over YYYY" '"2025-365"' '.date_format' '"ordinal"'
run_test "precedence: YYYY-Www-D over YYYY-Www" '"2025-W48-5"' '.date_format' '"week"'

echo ""
echo "=== combined date-time-timezone parsing ==="
echo ""

# test complete ISO-8601 strings
run_test "combined: calendar + time + timezone" '"2025-11-28T12:34:56+05:30"' '.date_format' '"calendar"'
run_test "combined: ordinal + time + Z" '"2025-365T23:59:59Z"' '.date_format' '"ordinal"'
run_test "combined: week + time + fractional offset" '"2025-W48-5T12:34:56.789+05.5"' '.date_format' '"week"'
run_test "combined: calendar system + date + time" '"julian:2025-11-15T12:00:00Z"' '.calendar_system' '"julian"'

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASS"
echo "failed: $FAIL"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "all input parsing tests passed! ✓"
  exit 0
else
  echo "some tests failed! ✗"
  exit 1
fi

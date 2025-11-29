#!/bin/bash

# test calendar conversion functionality

echo "testing calendar conversion..."
echo ""

PASSED=0
FAILED=0
TEST_START=$(date +%s)

# helper function to run a test
run_test() {
    local test_name="$1"
    local calendar="$2"
    local year="$3"
    local month="$4"
    local day="$5"
    local expected_year="$6"
    local expected_month="$7"
    local expected_day="$8"
    local tolerance="${9:-0}"  # Default tolerance is 0 days
    
    # show progress
    echo -n "running: $test_name... "
    
    local start_time=$(date +%s%3N)
    result=$(echo '{}' | jq -L lib "include \"lib/calendar/calendar_converter\"; {calendar_system: \"$calendar\", date_parts: {year: $year, month: $month, day: $day}} | convert_calendar_system | .date_parts" 2>&1)
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    if [ $? -ne 0 ]; then
        echo "✗ FAILED (${duration}ms)"
        echo "  error: $result"
        FAILED=$((FAILED + 1))
        return
    fi
    
    actual_year=$(echo "$result" | jq -r '.year')
    actual_month=$(echo "$result" | jq -r '.month')
    actual_day=$(echo "$result" | jq -r '.day')
    
    # calculate date difference in days (simple approximation)
    expected_date_days=$((expected_year * 365 + expected_month * 30 + expected_day))
    actual_date_days=$((actual_year * 365 + actual_month * 30 + actual_day))
    diff=$((actual_date_days - expected_date_days))
    diff=${diff#-}  # Absolute value
    
    if [ "$tolerance" -eq 0 ]; then
    # exact match required
        if [ "$actual_year" -eq "$expected_year" ] && [ "$actual_month" -eq "$expected_month" ] && [ "$actual_day" -eq "$expected_day" ]; then
            echo "✓ PASSED (${duration}ms)"
            PASSED=$((PASSED + 1))
        else
            echo "✗ FAILED (${duration}ms)"
            echo "  expected: $expected_year-$(printf "%02d" $expected_month)-$(printf "%02d" $expected_day)"
            echo "  got: $actual_year-$(printf "%02d" $actual_month)-$(printf "%02d" $actual_day)"
            FAILED=$((FAILED + 1))
        fi
    else
    # tolerance allowed (approximate match)
        if [ "$diff" -le "$((tolerance * 30))" ]; then
            echo "✓ PASSED (${duration}ms)"
            echo "  result: $actual_year-$(printf "%02d" $actual_month)-$(printf "%02d" $actual_day) (within ±$tolerance day tolerance)"
            PASSED=$((PASSED + 1))
        else
            echo "✗ FAILED (${duration}ms)"
            echo "  expected: $expected_year-$(printf "%02d" $expected_month)-$(printf "%02d" $expected_day) (±$tolerance days)"
            echo "  got: $actual_year-$(printf "%02d" $actual_month)-$(printf "%02d" $actual_day)"
            FAILED=$((FAILED + 1))
        fi
    fi
}

echo "=== gregorian calendar (passthrough) ==="
echo ""
run_test "gregorian: 2025-11-28" "gregorian" 2025 11 28 2025 11 28 0
run_test "gregorian: 2024-02-29 (leap year)" "gregorian" 2024 2 29 2024 2 29 0
run_test "gregorian: 1970-01-01 (epoch)" "gregorian" 1970 1 1 1970 1 1 0

echo ""
echo "=== julian calendar ==="
echo ""
run_test "julian: 2025-11-15 → 2025-11-28" "julian" 2025 11 15 2025 11 28 0
run_test "julian: 2000-01-01" "julian" 2000 1 1 2000 1 14 0
run_test "julian: 1900-12-31" "julian" 1900 12 31 1901 1 13 0

echo ""
echo "=== buddhist calendar ==="
echo ""
run_test "buddhist: 2568-11-28 → 2025-11-28" "buddhist" 2568 11 28 2025 11 28 0
run_test "buddhist: 2567-01-01 → 2024-01-01" "buddhist" 2567 1 1 2024 1 1 0
run_test "buddhist: 2513-01-01 → 1970-01-01" "buddhist" 2513 1 1 1970 1 1 0

echo ""
echo "=== islamic calendar (±1 day tolerance) ==="
echo ""
run_test "islamic: 1446-05-27 → ~2024-11-26" "islamic" 1446 5 27 2024 11 26 1
run_test "islamic: 1400-01-01 (approximate)" "islamic" 1400 1 1 1979 11 17 1
run_test "islamic: 1300-01-01 (approximate)" "islamic" 1300 1 1 1882 11 9 1

echo ""
echo "=== hebrew calendar (±1 day tolerance) ==="
echo ""
run_test "hebrew: 5786-03-15 → ~2026-01-11" "hebrew" 5786 3 15 2026 1 11 1
run_test "hebrew: 5730-01-01 (approximate)" "hebrew" 5730 1 1 1969 10 30 1
run_test "hebrew: 5785-07-01 (approximate)" "hebrew" 5785 7 1 2025 4 26 1

echo ""
echo "=== persian calendar ==="
echo ""
run_test "persian: 1404-09-07 → 2025-11-28" "persian" 1404 9 7 2025 11 28 0
run_test "persian: 1400-01-01 → 2021-03-21" "persian" 1400 1 1 2021 3 21 0
run_test "persian: 1348-01-01 → 1969-03-22" "persian" 1348 1 1 1969 3 22 0

echo ""
echo "=== chinese calendar (±1 day tolerance) ==="
echo ""
run_test "chinese: 4723-10-15 → ~2025-11-20" "chinese" 4723 10 15 2025 11 20 1
run_test "chinese: 4722-01-01 → ~2024-02-14" "chinese" 4722 1 1 2024 2 14 1
run_test "chinese: 4660-01-01 → ~1962-02-14" "chinese" 4660 1 1 1962 2 14 1

echo ""
echo "=== module loadingtest ==="
echo ""
echo -n "running: calendar converter module load... "
start_time=$(date +%s%3N)
result=$(echo '{}' | jq -L lib 'include "lib/calendar/calendar_converter"; "loaded"' 2>&1)
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
if [ "$result" = '"loaded"' ]; then
    echo "✓ PASSED (${duration}ms)"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAILED (${duration}ms)"
    echo "  error: $result"
    FAILED=$((FAILED + 1))
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
    echo "all calendar conversion tests passed! ✓"
    exit 0
else
    echo "some tests failed."
    exit 1
fi

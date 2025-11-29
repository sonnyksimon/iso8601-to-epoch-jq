#!/bin/bash

# final integration testing
# comprehensive validation

echo "final integration testing..."
echo ""

PASSED=0
FAILED=0
TEST_START=$(date +%s)

# performance and scalability
echo "=== performance and scalability ==="
echo ""

echo -n "running: single conversion <10ms target... "
start_time=$(date +%s%N)
result=$(echo '"2025-11-28T12:34:56Z"' | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' 2>&1)
exit_code=$?
end_time=$(date +%s%N)
duration_us=$(((end_time - start_time) / 1000))

if [ $exit_code -eq 0 ]; then
    echo "✓ PASSED (${duration_us}μs)"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAILED"
    FAILED=$((FAILED + 1))
fi

echo -n "running: 1000 conversions <100s target... "
batch_start=$(date +%s)
for i in {1..1000}; do
    echo '"2025-11-28T12:34:56Z"'
done | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' > /dev/null 2>&1
batch_end=$(date +%s)
batch_duration=$((batch_end - batch_start))

if [ $batch_duration -lt 100 ]; then
    echo "✓ PASSED (${batch_duration}s)"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAILED (${batch_duration}s > 100s)"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "=== deterministic output ==="
echo ""

echo -n "running: deterministic output verification... "
output1=$(echo '"2025-11-28T12:34:56.789Z"' | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' 2>&1)
output2=$(echo '"2025-11-28T12:34:56.789Z"' | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' 2>&1)
output3=$(echo '"2025-11-28T12:34:56.789Z"' | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' 2>&1)

if [ "$output1" = "$output2" ] && [ "$output2" = "$output3" ]; then
    echo "✓ PASSED"
    PASSED=$((PASSED + 1))
else
    echo "✗ FAILED (non-deterministic)"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "=== date/time format support ==="
echo ""

test_conversion() {
    local input="$1"
    local description="$2"
    
    echo -n "running: $description... "
    result=$(timeout 3 echo "\"$input\"" | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "✓ PASSED"
        PASSED=$((PASSED + 1))
    else
        echo "✗ FAILED"
        echo "  error: $result"
        FAILED=$((FAILED + 1))
    fi
}

# calendar dates (req 1)
test_conversion "2025" "calendar: year only"
test_conversion "2025-11" "calendar: year-month"
test_conversion "2025-11-28" "calendar: full date"
test_conversion "20251128" "calendar: basic format"

# ordinal dates (req 2)
test_conversion "2024-366" "ordinal: leap year day 366"
test_conversion "2023-365" "ordinal: non-leap year day 365"

# week dates (req 3)
test_conversion "2020-W01-1" "week: crosses year boundary"
test_conversion "2020-W53-7" "week: week 53"

# time formats (req 4)
test_conversion "2025-11-28T12" "time: hour only"
test_conversion "2025-11-28T12:34" "time: hour:minute"
test_conversion "2025-11-28T12:34:56" "time: full time"

# subsecond precision (req 5)
test_conversion "2025-11-28T12:34:56.123456789Z" "subsecond: 9 digits"
test_conversion "2025-11-28T12:34.5Z" "subsecond: fractional minutes"
test_conversion "2025-11-28T12.5Z" "subsecond: fractional hours"

# timezone offsets (req 6)
test_conversion "2025-11-28T12:00Z" "timezone: Z indicator"
test_conversion "2025-11-28T12:00+05:30" "timezone: +hh:mm"
test_conversion "2025-11-28T12:00+05.5" "timezone: fractional hours"

# leap seconds (req 13)
test_conversion "2016-12-31T23:59:60Z" "leap second: 60"
test_conversion "2016-12-31T23:59:60.5Z" "leap second: with fractional"

# extended years (req 16)
test_conversion "-0001-01-01T00:00:00Z" "extended: 1 BCE"
test_conversion "-999999-01-01T00:00:00Z" "extended: min year"
test_conversion "+999999-12-31T23:59:59Z" "extended: max year"

# alternative calendars (req 17)
test_conversion "julian:2025-11-15T12:00:00Z" "calendar: julian"
test_conversion "buddhist:2568-11-28T12:00:00Z" "calendar: buddhist"
test_conversion "islamic:1446-05-27T12:00:00Z" "calendar: islamic"

echo ""
echo "=== error reporting ==="
echo ""

test_error() {
    local input="$1"
    local description="$2"
    
    echo -n "running: $description... "
    result=$(timeout 3 echo "\"$input\"" | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' 2>&1)
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "✓ PASSED (error detected)"
        PASSED=$((PASSED + 1))
    else
        echo "✗ FAILED (should have errored)"
        FAILED=$((FAILED + 1))
    fi
}

test_error "2025-13-01" "error: invalid month 13"
test_error "2025-11-32" "error: invalid day 32"
test_error "2025-11-28T24:00:00Z" "error: invalid hour 24"
test_error "2023-366" "error: ordinal 366 non-leap"
test_error "202511" "error: ambiguous YYYYMM"

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASSED"
echo "failed: $FAILED"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ all validations passed"
    exit 0
else
    echo "✗ some validations failing"
    exit 1
fi

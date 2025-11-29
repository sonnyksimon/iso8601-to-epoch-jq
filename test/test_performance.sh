#!/bin/bash

# performance testing and profiling
# measures conversion speed and identifies bottlenecks

echo "performance testing..."
echo ""

# test single conversion performance
echo "=== single conversion performance ==="
echo ""

test_single() {
    local input="$1"
    local description="$2"
    
    echo -n "testing: $description... "
    
    local start_time=$(date +%s%N)
    result=$(timeout 3 echo "\"$input\"" | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' 2>&1)
    local exit_code=$?
    local end_time=$(date +%s%N)
    
    if [ $exit_code -eq 124 ]; then
        echo "✗ TIMEOUT"
        return 1
    elif [ $exit_code -ne 0 ]; then
        echo "✗ FAILED"
        echo "  error: $result"
        return 1
    fi
    
    # calculate duration in microseconds
    local duration_ns=$((end_time - start_time))
    local duration_us=$((duration_ns / 1000))
    local duration_ms=$((duration_us / 1000))
    
    echo "✓ ${duration_ms}ms (${duration_us}μs)"
}

# test various input types
test_single "2025-11-28" "simple calendar date"
test_single "2025-11-28T12:34:56.789Z" "full datetime with fractional"
test_single "2025-11-28T12:34:56.789+05:30" "datetime with timezone offset"
test_single "2024-366" "ordinal date (leap year)"
test_single "2020-W53-7" "week date (week 53)"
test_single "-0001-01-01T00:00:00Z" "BCE date"
test_single "2016-12-31T23:59:60.5Z" "leap second with fractional"
test_single "buddhist:2568-11-28T12:00:00Z" "alternative calendar"

echo ""
echo "=== batch conversion performance ==="
echo ""

# test batch processing (1000 conversions)
echo -n "testing: 1000 conversions... "
BATCH_START=$(date +%s%N)

# generate 1000 test inputs
for i in {1..1000}; do
    echo '"2025-11-28T12:34:56Z"'
done | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' > /dev/null 2>&1

BATCH_END=$(date +%s%N)
BATCH_DURATION_NS=$((BATCH_END - BATCH_START))
BATCH_DURATION_MS=$((BATCH_DURATION_NS / 1000000))
BATCH_DURATION_S=$((BATCH_DURATION_MS / 1000))
AVG_PER_CONVERSION_US=$((BATCH_DURATION_NS / 1000 / 1000))

echo "✓ ${BATCH_DURATION_MS}ms total (${AVG_PER_CONVERSION_US}μs avg per conversion)"

# check if we meet performance target (<10ms per conversion)
if [ $AVG_PER_CONVERSION_US -lt 10000 ]; then
    echo "  performance target met: <10ms per conversion ✓"
else
    echo "  performance target not met: ${AVG_PER_CONVERSION_US}μs > 10ms ✗"
fi

echo ""
echo "=== performance summary ==="
echo "target: <10ms per conversion"
echo "actual: ${AVG_PER_CONVERSION_US}μs per conversion"
echo ""

if [ $AVG_PER_CONVERSION_US -lt 10000 ]; then
    echo "✓ performance within acceptable thresholds"
    exit 0
else
    echo "✗ performance NOT within acceptable thresholds"
    exit 1
fi

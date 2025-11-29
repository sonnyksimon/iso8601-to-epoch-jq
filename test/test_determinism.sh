#!/bin/bash

# determinism testing
# verifies identical outputs across multiple runs

echo "testing deterministic output..."
echo ""

PASSED=0
FAILED=0
TEST_START=$(date +%s)

# test inputs covering various features
test_inputs=(
    "2025-11-28"
    "2025-11-28T12:34:56.789Z"
    "2025-11-28T12:34:56.789+05:30"
    "2024-366"
    "2020-W53-7"
    "-0001-01-01T00:00:00Z"
    "2016-12-31T23:59:60.5Z"
    "buddhist:2568-11-28T12:00:00Z"
    "julian:2025-11-15T12:00:00Z"
    "1970-01-01T00:00:00.123456789Z"
    "-999999-01-01T00:00:00Z"
    "+999999-12-31T23:59:59Z"
)

run_determinism_test() {
    local input="$1"
    local description="$2"
    
    echo -n "running: $description... "
    
    local start_time=$(date +%s%3N)
    
    # run conversion 5 times and collect outputs
    local outputs=()
    for i in {1..5}; do
        result=$(timeout 3 echo "\"$input\"" | jq -L lib 'include "lib/iso8601_to_epoch"; iso8601_to_epoch' 2>&1)
        local exit_code=$?
        
        if [ $exit_code -eq 124 ]; then
            echo "✗ FAILED (TIMEOUT)"
            FAILED=$((FAILED + 1))
            return
        elif [ $exit_code -ne 0 ]; then
            echo "✗ FAILED"
            echo "  error: $result"
            FAILED=$((FAILED + 1))
            return
        fi
        
        outputs+=("$result")
    done
    
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    # verify all outputs are identical
    local first_output="${outputs[0]}"
    local all_identical=true
    
    for output in "${outputs[@]}"; do
        if [ "$output" != "$first_output" ]; then
            all_identical=false
            break
        fi
    done
    
    if [ "$all_identical" = true ]; then
        echo "✓ PASSED (${duration}ms)"
        PASSED=$((PASSED + 1))
    else
        echo "✗ FAILED (non-deterministic output)"
        echo "  first output: $first_output"
        echo "  different outputs detected across 5 runs"
        FAILED=$((FAILED + 1))
    fi
}

# run determinism tests for each input
run_determinism_test "${test_inputs[0]}" "simple calendar date"
run_determinism_test "${test_inputs[1]}" "full datetime with fractional"
run_determinism_test "${test_inputs[2]}" "datetime with timezone offset"
run_determinism_test "${test_inputs[3]}" "ordinal date (leap year)"
run_determinism_test "${test_inputs[4]}" "week date (week 53)"
run_determinism_test "${test_inputs[5]}" "BCE date"
run_determinism_test "${test_inputs[6]}" "leap second with fractional"
run_determinism_test "${test_inputs[7]}" "buddhist calendar"
run_determinism_test "${test_inputs[8]}" "julian calendar"
run_determinism_test "${test_inputs[9]}" "maximum fractional precision"
run_determinism_test "${test_inputs[10]}" "minimum year"
run_determinism_test "${test_inputs[11]}" "maximum year"

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASSED"
echo "failed: $FAILED"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ all determinism tests passed"
    exit 0
else
    echo "✗ some determinism tests failed"
    exit 1
fi

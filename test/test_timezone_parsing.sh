#!/bin/bash

# test timezone offset parsing

echo "testing timezone offset parsing..."
echo ""

PASSED=0
FAILED=0
TEST_START=$(date +%s)

run_test() {
  local test_name="$1"
  local input="$2"
  
  echo -n "running: $test_name... "
  start_time=$(date +%s%3N)
  result=$(timeout 3 bash -c "echo '$input' | jq -L. 'include \"lib/parsing/input_parser\"; classify_and_parse | .timezone'" 2>&1)
  exit_code=$?
  end_time=$(date +%s%3N)
  duration=$((end_time - start_time))
  
  if [ $exit_code -eq 124 ]; then
    echo "✗ FAILED (TIMEOUT after 3s)"
    FAILED=$((FAILED + 1))
  elif [ $exit_code -eq 0 ]; then
    echo "✓ PASSED (${duration}ms)"
    PASSED=$((PASSED + 1))
  else
    echo "✗ FAILED (${duration}ms)"
    echo "  error: $result"
    FAILED=$((FAILED + 1))
  fi
}

# test z indicator
run_test "z indicator" '"2025-11-28T12:00:00Z"'

# test +hh format
run_test "+hh format" '"2025-11-28T12:00:00+05"'

# test -hh format
run_test "-hh format" '"2025-11-28T12:00:00-03"'

# test +hh:mm format
run_test "+hh:mm format" '"2025-11-28T12:00:00+05:30"'

# test +hhmm format
run_test "+hhmm format" '"2025-11-28T12:00:00+0530"'

# test -hh:mm format
run_test "-hh:mm format" '"2025-11-28T12:00:00-04:00"'

# test +hh.hhhh fractional format
run_test "+hh.hhhh fractional format" '"2025-11-28T12:00:00+05.5"'

# test -hh.hhhh fractional format
run_test "-hh.hhhh fractional format" '"2025-11-28T12:00:00-03.25"'

# test +hh.hhhh with 4 digits fractional format
run_test "+hh.hhhh with 4 digits" '"2025-11-28T12:00:00+05.3333"'

# test no timezone (should be null)
run_test "no timezone" '"2025-11-28T12:00:00"'

TEST_END=$(date +%s)
TOTAL_DURATION=$((TEST_END - TEST_START))

echo ""
echo "=== summary ==="
echo "passed: $PASSED"
echo "failed: $FAILED"
echo "total time: ${TOTAL_DURATION}s"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "all timezone parsing tests passed! ✓"
  exit 0
else
  echo "some tests failed."
  exit 1
fi

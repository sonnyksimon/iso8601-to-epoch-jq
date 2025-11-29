#!/bin/bash
# Examples demonstrating input validation

echo "=== Input Length Validation Examples ==="
echo ""

echo "1. Valid input (within limits):"
echo '"2025-11-28T12:34:56.789+05:30"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length'
echo ""

echo "2. Valid input with maximum year digits (7):"
echo '"+999999-12-31T23:59:59Z"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length'
echo ""

echo "3. Valid input with maximum fractional seconds (9 digits):"
echo '"2025-11-28T12:34:56.123456789Z"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length'
echo ""

echo "4. Valid input with maximum fractional timezone (4 digits):"
echo '"2025-11-28T12:00+05.1234"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length'
echo ""

echo "5. Invalid: Total input exceeds 100 characters:"
echo '"'$(printf '%0101d' 0)'"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length' 2>&1 || true
echo ""

echo "6. Invalid: Year component exceeds 7 digits:"
echo '"+1000000-11-28"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length' 2>&1 || true
echo ""

echo "7. Invalid: Fractional seconds exceed 9 digits:"
echo '"2025-11-28T12:34:56.1234567890Z"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length' 2>&1 || true
echo ""

echo "8. Invalid: Fractional timezone exceeds 4 digits:"
echo '"2025-11-28T12:00+05.12345"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length' 2>&1 || true
echo ""

echo "9. Invalid: Calendar indicator exceeds 20 characters:"
echo '"abcdefghijklmnopqrstu:2025-11-28"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length' 2>&1 || true
echo ""

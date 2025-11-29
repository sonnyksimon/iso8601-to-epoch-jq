#!/bin/bash
# Basic usage examples for the ISO-8601 to Unix epoch converter

echo "ISO-8601 to Unix Epoch Converter - Examples"
echo "============================================"
echo ""

# Example 1: Test input validation
echo "Example 1: Input length validation"
echo "Input: \"2025-11-28\""
echo '"2025-11-28"' | jq -L lib 'include "lib/validation/input_validation"; validate_input_length'
echo ""

# Example 2: Test utility functions
echo "Example 2: Leap year detection"
echo "Is 2024 a leap year?"
echo '2024' | jq -L lib 'include "lib/core/utils"; is_leap_year(.)'
echo ""

echo "Is 2023 a leap year?"
echo '2023' | jq -L lib 'include "lib/core/utils"; is_leap_year(.)'
echo ""

# Example 3: Days in month
echo "Example 3: Days in February"
echo "Days in February 2024 (leap year):"
echo 'null' | jq -L lib 'include "lib/core/utils"; days_in_month(2024; 2)'
echo ""

echo "Days in February 2023 (non-leap year):"
echo 'null' | jq -L lib 'include "lib/core/utils"; days_in_month(2023; 2)'
echo ""

# Example 4: Error formatting
echo "Example 4: Error message formatting"
echo "Format error for invalid month:"
echo 'null' | jq -L lib -r 'include "lib/core/error"; format_error("month"; "13"; "2025-13-01")'
echo ""

echo "Format year range error:"
echo 'null' | jq -L lib -r 'include "lib/core/error"; format_year_range_error("-1000000"; "-1000000-01-01")'
echo ""

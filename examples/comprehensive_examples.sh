#!/bin/bash
# comprehensive usage examples for the ISO-8601 to Unix epoch converter

echo "=== ISO-8601 to Unix Epoch Converter - Comprehensive Examples ==="
echo ""

# helper function to run example
run_example() {
    local description="$1"
    local input="$2"
    echo "$description"
    echo "input: $input"
    echo -n "output: "
    echo "$input" | jq -L lib -f lib/iso8601_to_epoch.jq 'iso8601_to_epoch' 2>&1
    echo ""
}

# calendar dates
echo "=== Calendar Dates ==="
echo ""
run_example "year only (assumes Jan 1, 00:00:00 UTC)" '"2025"'
run_example "year-month (assumes first day, 00:00:00 UTC)" '"2025-11"'
run_example "year-month-day" '"2025-11-28"'
run_example "compact format (YYYYMMDD)" '"20251128"'

# ordinal dates
echo "=== Ordinal Dates ==="
echo ""
run_example "ordinal date (day 60 of 2024 = Feb 29)" '"2024-060"'
run_example "ordinal date (day 366 of leap year)" '"2024-366"'
run_example "compact ordinal format" '"2024366"'

# week dates
echo "=== Week Dates ==="
echo ""
run_example "ISO week date (week 1, day 1 of 2020)" '"2020-W01-1"'
run_example "ISO week 53 (extends into next year)" '"2020-W53-7"'
run_example "week only (assumes Monday)" '"2020-W53"'
run_example "compact week format" '"2020W537"'

# time formats
echo "=== Time Formats ==="
echo ""
run_example "hour only" '"2025-11-28T12Z"'
run_example "fractional hour" '"1970-01-01T05.5Z"'
run_example "hour and minute" '"2025-11-28T12:34Z"'
run_example "fractional minute" '"1970-01-01T05:30.5Z"'
run_example "full time with seconds" '"2025-11-28T12:34:56Z"'
run_example "fractional seconds (9 digits)" '"2025-11-28T12:34:56.123456789Z"'

# timezone offsets
echo "=== Timezone Offsets ==="
echo ""
run_example "UTC (Z indicator)" '"2025-11-28T12:00Z"'
run_example "hour offset" '"2025-11-28T12:00+05"'
run_example "hour:minute offset" '"2025-11-28T12:00+05:30"'
run_example "fractional hour offset" '"2025-11-28T12:00+05.5"'
run_example "negative offset" '"2025-11-28T12:00-03:00"'
run_example "no timezone (assumes UTC)" '"2025-11-28T12:00"'

# extended year ranges
echo "=== Extended Year Ranges ==="
echo ""
run_example "BCE date (1 BCE)" '"-0001-01-01T00:00:00Z"'
run_example "BCE leap year (day 366 of 4 BCE)" '"-0004-366T00:00:00Z"'
run_example "extended year beyond 9999" '"+10000-01-01T00:00:00Z"'

# leap seconds
echo "=== Leap Seconds ==="
echo ""
run_example "leap second (23:59:60)" '"2016-12-31T23:59:60Z"'
run_example "leap second with fractional seconds" '"2016-12-31T23:59:60.5Z"'
run_example "leap second with fractional offset" '"2016-12-31T23:59:60.5+05.5"'

# alternative calendars
echo "=== Alternative Calendar Systems ==="
echo ""
run_example "Julian calendar" '"julian:2025-11-15T12:00:00Z"'
run_example "Buddhist calendar" '"buddhist:2568-11-28T12:00:00Z"'
run_example "Islamic calendar" '"islamic:1446-05-27T12:00:00Z"'
run_example "Hebrew calendar" '"hebrew:5786-03-15T12:00:00Z"'
run_example "Persian calendar" '"persian:1404-09-07T12:00:00Z"'
run_example "Chinese calendar" '"chinese:4723-10-15T12:00:00Z"'

# error examples
echo "=== Error Examples ==="
echo ""
run_example "invalid month" '"2025-13-01"'
run_example "invalid day" '"2025-11-32"'
run_example "invalid hour" '"2025-11-28T25:00:00Z"'
run_example "ambiguous format (YYYYMM)" '"202511"'
run_example "year out of range" '"-1000000-01-01"'
run_example "unsupported calendar" '"mayan:2025-11-28"'

# batch processing
echo "=== Batch Processing ==="
echo ""
echo "processing multiple dates:"
echo 'input: ["2025-11-28", "2025-11-29", "2025-11-30"]'
echo -n "output: "
echo '["2025-11-28", "2025-11-29", "2025-11-30"]' | \
  jq -L lib 'include "lib/iso8601_to_epoch"; map(iso8601_to_epoch)'
echo ""

echo "=== Examples Complete ==="

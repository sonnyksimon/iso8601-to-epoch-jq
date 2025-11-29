# Design Document: ISO-8601 to Unix Epoch Converter with Extended Features

## Overview

This document describes the design for implementing the `iso8601_to_epoch` function in jq. The function converts ISO-8601 date/datetime strings (including extended features) to Unix epoch timestamps (UTC seconds). The implementation supports:

- **Extended year ranges**: -999999 to +999999 (including BCE dates)
- **Leap seconds**: 23:59:60 with fractional precision
- **Fractional timezone offsets**: ±hh.hhhh format
- **Alternative calendar systems**: Julian, Islamic, Buddhist, Hebrew, Persian, Chinese
- **High precision**: Up to 9 digits of subsecond precision
- **Deterministic output**: Identical results across all jq versions and environments

The design prioritizes:
- **Correctness**: Exact Unix epoch calculations for all valid inputs
- **Determinism**: No reliance on system timezone, locale, or jq built-in date functions
- **Performance**: <10ms per conversion, scalable to 1M+ conversions
- **Maintainability**: Modular architecture with clear separation of concerns

## Architecture

The function follows a pipeline architecture with six distinct phases:

```
Input String
    ↓
Phase 1: Input Validation & Length Check
    ↓
Phase 2: Input Classification & Parsing
    ↓
Phase 3: Calendar System Conversion (if needed)
    ↓
Phase 4: Date Normalization (to Gregorian YYYY-MM-DD)
    ↓
Phase 5: Time & Timezone Normalization
    ↓
Phase 6: Unix Epoch Computation
    ↓
Output (Integer or Float)
```

Each phase is implemented as a separate jq function to maintain modularity, testability, and adherence to the strict validation order specified in Requirement 15.

## Components and Interfaces

### 1. Main Entry Point

```jq
def iso8601_to_epoch:
  # Main function that orchestrates the conversion pipeline
  # Input: ISO-8601 string (with optional calendar system prefix)
  # Output: Unix epoch (integer or float)
  # Throws: Error object for invalid inputs (first error only)
  
  validate_input_length
  | classify_and_parse
  | convert_calendar_system
  | normalize_date
  | normalize_time_and_timezone
  | compute_epoch;
```

### 2. Phase 1: Input Validation & Length Check

```jq
def validate_input_length:
  # Validates input length constraints
  # Returns: input string (unchanged) or error
  # Max lengths:
  #   - Total: 100 characters
  #   - Year: 7 digits (including sign)
  #   - Fractional seconds: 9 digits
  #   - Fractional timezone: 4 digits
  #   - Calendar indicator: 20 characters
```

**Responsibilities:**
- Check total input length ≤ 100 characters
- Prevent resource exhaustion from extremely long inputs
- Report first validation error and stop

**Implementation approach:**
- Use jq `length` function
- Error format: `"Input exceeds maximum length of 100 characters: '<truncated>...'"`

### 3. Phase 2: Input Classification & Parsing

```jq
def classify_and_parse:
  # Parses input string and identifies all components
  # Returns object: {
  #   calendar_system: "gregorian" | "julian" | "islamic" | "buddhist" | "hebrew" | "persian" | "chinese",
  #   date_format: "calendar" | "ordinal" | "week",
  #   date_parts: {...},
  #   time_parts: {...} | null,
  #   timezone: {...} | null,
  #   has_leap_second: boolean
  # }
```

**Responsibilities:**
- Extract calendar system indicator (if present)
- Detect date format using pattern matching precedence:
  - Calendar: YYYY-MM-DD → YYYY-MM → YYYY → YYYYMMDD
  - Ordinal: YYYY-DDD → YYYYDDD
  - Week: YYYY-Www-D → YYYYWwwD → YYYY-Www → YYYYWww
- Extract date components (year, month, day, or week/weekday, or ordinal day)
- Extract time components (hour, minute, second, fractional)
- Extract timezone offset (Z, ±hh, ±hhmm, ±hh:mm, ±hh.hhhh)
- Detect leap second (second == 60)
- Validate format structure (not values)
- Reject ambiguous formats (YYYYMM)

**Implementation approach:**
- Use regex patterns for each format
- Calendar system: `^(gregorian|julian|islamic|buddhist|hebrew|persian|chinese):(.+)$`
- Calendar date: `^([+-]?\d{1,6})(?:-(\d{2})(?:-(\d{2}))?)?$`
- Ordinal date: `^([+-]?\d{1,6})-?(\d{3})$`
- Week date: `^([+-]?\d{1,6})-?W(\d{2})(?:-?(\d))?$`
- Time: `^T(\d{2})(?::?(\d{2})(?::?(\d{2})(?:\.(\d{1,9}))?)?)?$` or fractional variants
- Timezone: `^(Z|([+-])(\d{2})(?::?(\d{2})|\.(\d{1,4}))?)$`

### 4. Phase 3: Calendar System Conversion

```jq
def convert_calendar_system:
  # Converts alternative calendar dates to Gregorian
  # Input: parsed object from Phase 2
  # Output: same object with date_parts converted to Gregorian
  
  if .calendar_system == "gregorian" then .
  elif .calendar_system == "julian" then convert_julian_to_gregorian
  elif .calendar_system == "buddhist" then convert_buddhist_to_gregorian
  elif .calendar_system == "islamic" then convert_islamic_to_gregorian
  elif .calendar_system == "hebrew" then convert_hebrew_to_gregorian
  elif .calendar_system == "persian" then convert_persian_to_gregorian
  elif .calendar_system == "chinese" then convert_chinese_to_gregorian
  else error("Unsupported calendar system")
  end;
```

**Sub-components:**

```jq
def convert_julian_to_gregorian:
  # Algorithmic conversion (exact)
  # Julian calendar: every year divisible by 4 is a leap year
  # Difference from Gregorian increases by 3 days every 400 years
  # As of 2025: 13-day difference

def convert_buddhist_to_gregorian:
  # Simple offset conversion (exact)
  # Buddhist year = Gregorian year + 543

def convert_islamic_to_gregorian:
  # Lunar calendar conversion (±1 day tolerance)
  # Uses lookup tables with algorithmic interpolation
  # 12 lunar months, ~354-355 days per year

def convert_hebrew_to_gregorian:
  # Lunisolar calendar conversion (±1 day tolerance)
  # 19-year cycle with 7 leap years
  # Uses lookup tables with algorithmic interpolation

def convert_persian_to_gregorian:
  # Solar calendar conversion (exact)
  # Year begins at vernal equinox
  # Uses astronomical algorithms

def convert_chinese_to_gregorian:
  # Lunisolar calendar conversion (±1 day tolerance)
  # 60-year cycle, complex intercalation
  # Uses lookup tables with algorithmic interpolation
```

**Responsibilities:**
- Convert alternative calendar dates to Gregorian calendar
- Maintain accuracy: exact for algorithmic calendars, ±1 day for astronomical
- Use deterministic algorithms (no external libraries)
- Validate date components for the specified calendar system

**Implementation approach:**
- Julian: Calculate day difference based on century
- Buddhist: Subtract 543 from year
- Islamic/Hebrew/Chinese: Use pre-computed lookup tables for common date ranges, algorithmic interpolation for others
- Persian: Use Meeus algorithms for vernal equinox calculation
- All conversions normalize to Gregorian YYYY-MM-DD before proceeding

### 5. Phase 4: Date Normalization

```jq
def normalize_date:
  # Converts any Gregorian date format to calendar date (YYYY-MM-DD)
  # Input: date_parts object from Phase 3
  # Output: {year: YYYY, month: MM, day: DD}
  
  if .date_format == "calendar" then normalize_calendar_date
  elif .date_format == "ordinal" then ordinal_to_calendar
  elif .date_format == "week" then week_to_calendar
  end;
```

**Sub-components:**

```jq
def is_leap_year(year):
  # Determines if a year is a leap year (works for negative years)
  # Input: year (integer, can be negative)
  # Output: boolean
  # Rules:
  #   - Divisible by 4 AND not by 100: leap year
  #   - Divisible by 400: leap year
  #   - For negative years: year -1 = 1 BCE (leap), year -5 = 5 BCE (leap)

def normalize_calendar_date:
  # Validates and normalizes calendar date
  # Handles year-only (→ Jan 1), year-month (→ day 1)
  # Validates month (01-12) and day ranges
  # Returns: {year, month, day}

def ordinal_to_calendar:
  # Converts ordinal date (YYYY-DDD) to calendar date
  # Input: {year, ordinal_day}
  # Output: {year, month, day}
  # Validates: ordinal_day 001-365 (or 366 for leap years)
  # Handles negative years correctly

def week_to_calendar:
  # Converts ISO week date to calendar date
  # Input: {year, week, weekday}
  # Output: {year, month, day}
  # ISO week 1: first week containing first Thursday
  # Handles week 53 (only valid for certain years)
  # Handles negative years correctly
```

**Responsibilities:**
- Calendar dates: Validate month (01-12) and day ranges, handle incomplete dates
- Ordinal dates: Convert day-of-year to month/day, validate against leap years
- Week dates: Apply ISO week rules, handle year boundary crossings
- Validate all date components according to Requirement 15 order
- Handle extended year ranges (-999999 to +999999)
- Apply leap year rules consistently for negative years

**Implementation approach:**
- Leap year: `(year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)`
- For negative years: adjust calculation to account for year 0 not existing
- Ordinal conversion: Accumulate days per month until ordinal day is reached
- Week conversion:
  1. Find January 4 of the year (always in week 1)
  2. Find the Monday of that week
  3. Add (week - 1) * 7 days
  4. Add (weekday - 1) days
  5. Handle year boundary crossings
- Month day limits: [31, 28/29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

### 6. Phase 5: Time & Timezone Normalization

```jq
def normalize_time_and_timezone:
  # Converts time and timezone to seconds since midnight and offset
  # Input: {date, time_parts, timezone, has_leap_second}
  # Output: {date, time_seconds, offset_seconds, has_fractional}
```

**Sub-components:**

```jq
def normalize_time:
  # Converts time components to seconds since midnight
  # Input: time_parts object (or null)
  # Output: seconds (float if fractional, integer otherwise)
  # Handles:
  #   - Fractional hours: convert to seconds, truncate to 9 digits
  #   - Fractional minutes: convert to seconds, truncate to 9 digits
  #   - Fractional seconds: preserve up to 9 digits, truncate beyond
  #   - Leap seconds: treat 60 as valid, will be handled in epoch computation
  # Validates: hour 00-23, minute 00-59, second 00-60

def normalize_timezone:
  # Calculates timezone offset in seconds
  # Input: timezone object (or null)
  # Output: offset_seconds (float if fractional, integer otherwise)
  # Handles:
  #   - Z: 0 offset
  #   - ±hh: hour offset in seconds
  #   - ±hhmm or ±hh:mm: hour and minute offset in seconds
  #   - ±hh.hhhh: fractional hour offset, truncate to 4 digits
  # Validates: offset < ±24 hours
  # Default: 0 (UTC) if no timezone specified

def apply_timezone_rollover:
  # Applies timezone offset and handles day/month/year rollover
  # Input: {date, time_seconds, offset_seconds}
  # Output: {date, time_seconds} (adjusted for rollover)
  # UTC = local time - offset
  # Handles:
  #   - Positive offset causing negative time: roll back to previous day
  #   - Negative offset causing time > 86400: roll forward to next day
  #   - Month boundary crossings
  #   - Year boundary crossings
  #   - Leap year considerations
```

**Responsibilities:**
- Parse hour, minute, second components
- Handle fractional hours, minutes, seconds with truncation (not rounding)
- Convert all time components to total seconds since midnight
- Validate time ranges (hour 0-23, minute 0-59, second 0-60)
- Preserve subsecond precision (up to 9 digits)
- Parse timezone indicators and fractional offsets
- Convert offset to seconds
- Apply formula: UTC = local time - offset
- Handle rollover across day/month/year boundaries
- Maintain fractional precision through rollover calculations

**Implementation approach:**
- Hours to seconds: `hour * 3600`
- Minutes to seconds: `minute * 60`
- Fractional hours: `(hour + fractional) * 3600`, then truncate to 9 decimal places
- Fractional minutes: `(minute + fractional) * 60`, then truncate to 9 decimal places
- Fractional seconds: preserve as-is, truncate to 9 decimal places
- Timezone offset: `±(hours * 3600 + minutes * 60)` or `±(fractional_hours * 3600)`
- Truncate fractional timezone to 4 decimal places
- Rollover: adjust date by adding/subtracting days, handle month/year changes

### 7. Phase 6: Unix Epoch Computation

```jq
def compute_epoch:
  # Calculates Unix epoch from normalized date, time, and timezone
  # Input: {date: {year, month, day}, time_seconds, has_leap_second, has_fractional}
  # Output: Unix epoch (integer or float)
```

**Sub-components:**

```jq
def days_since_epoch(year; month; day):
  # Counts days from 1970-01-01 to year-month-day
  # Handles negative years (BCE dates)
  # Returns: integer (can be negative)
  # Algorithm:
  #   1. Count leap years between 1970 and target year
  #   2. Sum days for complete years
  #   3. Add days for complete months in target year
  #   4. Add remaining days

def count_leap_years(from_year; to_year):
  # Counts leap years in range [from_year, to_year)
  # Handles negative years correctly
  # Returns: integer

def handle_leap_second:
  # Adjusts epoch for leap second
  # Leap second 23:59:60 = 00:00:00 of next day
  # Returns: adjusted epoch
```

**Responsibilities:**
- Calculate days since Unix epoch (1970-01-01)
- Handle negative years (BCE dates produce negative epochs)
- Convert days to seconds
- Add time seconds
- Subtract timezone offset
- Handle leap seconds (treat as next day's 00:00:00)
- Preserve integer/float type based on subsecond precision
- Ensure deterministic output for all inputs

**Implementation approach:**
- For positive years ≥ 1970:
  - Count complete years: `(year - 1970) * 365`
  - Add leap days: count leap years in range
  - Add days for complete months
  - Add remaining days
- For negative years < 1970:
  - Count backwards from 1970
  - Subtract leap days appropriately
  - Handle year 0 not existing (1 BCE = year -1)
- Convert to seconds: `days * 86400`
- Add time seconds
- Subtract offset: `epoch = (days * 86400 + time_seconds) - offset_seconds`
- Leap second: if `has_leap_second`, treat 23:59:60 as 00:00:00 of next day
- Return integer if no fractional component, float otherwise

### 8. Validation Functions

```jq
def validate_year_range(year):
  # Validates year is within -999999 to +999999
  # Throws error if out of range

def validate_calendar_date(year; month; day):
  # Validates calendar date components
  # Throws error for invalid month/day

def validate_ordinal_date(year; ordinal_day):
  # Validates ordinal day against year (leap year aware)
  # Throws error for invalid ordinal day

def validate_week_date(year; week; weekday):
  # Validates ISO week number and weekday
  # Checks if year has 53 weeks
  # Throws error for invalid week/weekday

def validate_time(hour; minute; second):
  # Validates time components
  # Allows second = 60 for leap seconds
  # Throws error for invalid hour/minute/second

def validate_timezone(offset_hours; offset_minutes_or_fractional):
  # Validates timezone offset
  # Throws error for invalid offset (≥±24 hours)

def validate_calendar_system(system):
  # Validates calendar system indicator
  # Throws error for unsupported system
```

## Data Models

### Parsed Input Object

```json
{
  "calendar_system": "gregorian" | "julian" | "islamic" | "buddhist" | "hebrew" | "persian" | "chinese",
  "date_format": "calendar" | "ordinal" | "week",
  "date_parts": {
    // For calendar format:
    "year": -999999 to +999999,
    "month": 1-12,  // optional
    "day": 1-31     // optional
    
    // For ordinal format:
    "year": -999999 to +999999,
    "ordinal_day": 1-366
    
    // For week format:
    "year": -999999 to +999999,
    "week": 1-53,
    "weekday": 1-7  // optional
  },
  "time_parts": {
    "hour": 0-23,
    "minute": 0-59,      // optional
    "second": 0-60,      // optional (60 for leap seconds)
    "fractional": "0.123456789",  // optional, string to preserve precision
    "fractional_unit": "second" | "minute" | "hour"
  } | null,
  "timezone": {
    "indicator": "Z" | "offset",
    "offset_hours": -23 to +23,    // for offset type
    "offset_minutes": 0-59,        // for ±hh:mm format
    "offset_fractional": "0.1234"  // for ±hh.hhhh format
  } | null,
  "has_leap_second": boolean
}
```

### Normalized Date Object

```json
{
  "year": -999999 to +999999,
  "month": 1-12,
  "day": 1-31
}
```

### Time and Timezone Object

```json
{
  "date": {
    "year": -999999 to +999999,
    "month": 1-12,
    "day": 1-31
  },
  "time_seconds": 0-86400.999999999,  // float or integer
  "has_leap_second": boolean,
  "has_fractional": boolean
}
```

### Error Object

```json
{
  "error": "Invalid <component> '<value>' in input '<original_input>'"
}
```

## Error Handling

All validation errors follow the standardized format and report only the first error encountered:

```
"Invalid <component> '<value>' in input '<original_input>'"
```

Validation order (Requirement 15):
1. Input length
2. Format structure
3. Calendar system
4. Year range
5. Component ranges
6. Leap year rules
7. ISO week rules
8. Timezone offset
9. Subsecond precision

Examples:
- `"Invalid month '13' in input '2025-13-01'"`
- `"Year '-1000000' outside supported range (-999999 to +999999) in input '-1000000-01-01'"`
- `"Unsupported calendar system 'mayan' in input 'mayan:2025-11-28'"`
- `"Ambiguous date format 'YYYYMM' in input '202511'"`

## Testing Strategy

### Unit Tests

Each phase function tested independently:

1. **Input Validation Tests**
   - Test maximum length enforcement
   - Test length limits for each component

2. **Input Classification Tests**
   - Test all date formats (calendar, ordinal, week)
   - Test all time formats (with/without fractional components)
   - Test all timezone formats (including fractional)
   - Test calendar system indicators
   - Test invalid format detection
   - Test pattern matching precedence

3. **Calendar Conversion Tests**
   - Test Julian conversion (exact)
   - Test Buddhist conversion (exact)
   - Test Islamic conversion (±1 day)
   - Test Hebrew conversion (±1 day)
   - Test Persian conversion (exact)
   - Test Chinese conversion (±1 day)

4. **Date Normalization Tests**
   - Test calendar date validation
   - Test ordinal date conversion (leap/non-leap years, BCE)
   - Test week date conversion (boundary cases, week 53, BCE)
   - Test leap year calculation (positive and negative years)

5. **Time Normalization Tests**
   - Test fractional hours, minutes, seconds
   - Test truncation (not rounding)
   - Test time component validation
   - Test subsecond precision preservation
   - Test leap second handling

6. **Timezone Normalization Tests**
   - Test all timezone formats
   - Test fractional hour offsets
   - Test offset calculation
   - Test offset validation
   - Test rollover across day/month/year boundaries

7. **Epoch Computation Tests**
   - Test dates before/after 1970
   - Test negative years (BCE)
   - Test extended year ranges
   - Test leap year handling
   - Test month boundary calculations
   - Test year boundary calculations
   - Test leap second conversion

### Integration Tests

Test complete conversion pipeline:

1. **Calendar Dates**
   - Standard: "2025", "2025-11", "2025-11-28", "20251128"
   - BCE: "-0001-01-01", "-0004-366"
   - Extended: "-999999-01-01", "+999999-12-31"

2. **Ordinal Dates**
   - Leap year: "2024-060" → Feb 29, "2024-366" → Dec 31
   - Non-leap: "2023-365" → Dec 31, "2023-366" → error
   - BCE: "-0004-366" → Dec 31, 4 BCE

3. **Week Dates**
   - Boundary: "2020-W01-1" → Dec 30, 2019
   - Week 53: "2020-W53-7" → Jan 3, 2021
   - BCE: "-0004-W01-1"

4. **Combined Date-Time-Timezone**
   - Standard: "2025-11-28T05:10Z"
   - Equivalent: "2025-11-28T01:10-04:00"
   - Fractional offset: "2025-11-28T12:00+05.5"
   - Leap second: "2016-12-31T23:59:60Z"
   - Combined: "2016-12-31T23:59:60.5+05.5"

5. **Alternative Calendars**
   - Julian: "julian:2025-11-15T12:00:00Z"
   - Buddhist: "buddhist:2568-11-28T12:00:00Z"
   - Islamic: "islamic:1446-05-27T12:00:00Z"
   - Hebrew: "hebrew:5786-03-15T12:00:00Z"
   - Persian: "persian:1404-09-07T12:00:00Z"
   - Chinese: "chinese:4723-10-15T12:00:00Z"

6. **Edge Cases**
   - Negative Unix epochs (pre-1970)
   - Subsecond precision (1-9 digits)
   - Timezone rollover across boundaries
   - Leap year boundaries
   - Maximum/minimum supported years
   - Combined extreme cases

7. **Invalid Inputs**
   - All invalid cases from requirements
   - Ambiguous formats
   - Out-of-range values
   - Unsupported calendars

### Determinism Tests

Verify identical outputs:
- Run same test cases multiple times
- Compare outputs for exact equality (including float precision)
- Test across different jq versions if possible
- Verify no system-dependent behavior

### Performance Tests

Verify performance requirements:
- Single conversion: <10ms
- 10,000 conversions: <100s
- 100,000 conversions: <1000s
- 1M conversions: consistent performance
- Memory usage: no leaks
- Parallel execution: deterministic

## Implementation Notes

### Truncation vs Rounding

All fractional components use truncation (floor), never rounding:
- Fractional seconds: truncate to 9 digits
- Fractional minutes: convert to seconds, truncate to 9 digits
- Fractional hours: convert to seconds, truncate to 9 digits
- Fractional timezone offsets: truncate to 4 digits

### Leap Year Calculation for Negative Years

For negative years (BCE):
- Year -1 = 1 BCE (leap year)
- Year -5 = 5 BCE (leap year)
- Year -100 = 100 BCE (not a leap year)
- Year -400 = 400 BCE (leap year)

Algorithm:
```jq
def is_leap_year(year):
  if year >= 0 then
    (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
  else
    # For negative years, adjust by 1 (no year 0)
    ((year + 1) % 4 == 0 and (year + 1) % 100 != 0) or ((year + 1) % 400 == 0)
  end;
```

### Days in Month

```jq
def days_in_month(year; month):
  if month == 2 then
    if is_leap_year(year) then 29 else 28 end
  elif [1,3,5,7,8,10,12] | index(month) then 31
  else 30
  end;
```

### ISO Week Calculation

ISO week 1 is the week containing the first Thursday of the year.

Algorithm:
```jq
def week_to_calendar(year; week; weekday):
  # Find January 4 (always in week 1)
  jan4 = {year: year, month: 1, day: 4};
  
  # Find day of week for Jan 4 (Monday=1, Sunday=7)
  jan4_dow = day_of_week(jan4);
  
  # Find Monday of week 1
  week1_monday = add_days(jan4, 1 - jan4_dow);
  
  # Add weeks and days
  target = add_days(week1_monday, (week - 1) * 7 + (weekday - 1));
  
  target;
```

### Epoch Calculation for Extended Years

For years far from 1970, use efficient calculation:

```jq
def days_since_epoch(year; month; day):
  # Calculate days from 1970-01-01
  if year >= 1970 then
    # Forward calculation
    days = (year - 1970) * 365;
    days = days + count_leap_years(1970, year);
    days = days + days_in_months_before(year, month);
    days = days + day - 1;
  else
    # Backward calculation
    days = (year - 1970) * 365;
    days = days - count_leap_years(year, 1970);
    days = days + days_in_months_before(year, month);
    days = days + day - 1;
  end;
  
  days;
```

### Leap Second Handling

Leap second 23:59:60 is treated as 00:00:00 of the next day:

```jq
def handle_leap_second(epoch; has_leap_second):
  if has_leap_second then
    # 23:59:60 = 00:00:00 of next day
    # Already calculated as next day's midnight
    epoch
  else
    epoch
  end;
```

### Calendar Conversion Lookup Tables

For astronomical calendars (Islamic, Hebrew, Chinese), use pre-computed lookup tables for common date ranges:

```jq
def islamic_to_gregorian_lookup:
  # Lookup table for Islamic years 1400-1500 (approx 1979-2077 CE)
  # Format: {islamic_year: {month: {day: gregorian_date}}}
  # For dates outside range, use algorithmic approximation
```

## Performance Considerations

- All calculations use integer arithmetic where possible
- Floating-point arithmetic only for subsecond precision
- Regex matching performed once per input
- No recursive functions (use iteration)
- Minimal string manipulation
- Lookup tables for calendar conversions cached in memory
- Efficient leap year counting using mathematical formulas
- Avoid naive iteration over large year ranges

## Limitations and Constraints

- Years must be in range -999999 to +999999
- Total input length ≤ 100 characters
- Fractional seconds truncated to 9 digits
- Fractional timezone offsets truncated to 4 digits
- Alternative calendar conversions: ±1 day tolerance for lunar calendars
- No support for ISO durations or intervals
- No support for time zones by name (only numeric offsets)
- Leap seconds accepted for any date (not just official IERS dates)

## Security Considerations

- Input length limits prevent resource exhaustion
- No external dependencies or system calls
- No reliance on system timezone or locale
- Deterministic output prevents timing attacks
- Error messages do not leak sensitive information
- No buffer overflows (jq handles string safety)

## Future Enhancements

While the current design is comprehensive, potential future enhancements include:

- Support for ISO durations (P1Y2M3DT4H5M6S)
- Support for ISO intervals (start/end or start/duration)
- Support for recurring dates
- Support for additional calendar systems
- Optimization for batch processing
- Caching for frequently converted dates
- Support for timezone names (IANA database)

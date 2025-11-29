# Implementation Documentation

This document describes the algorithms, design decisions, and implementation details of the ISO-8601 to Unix epoch converter.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Pipeline Phases](#pipeline-phases)
3. [Algorithms](#algorithms)
4. [Calendar Conversion Methods](#calendar-conversion-methods)
5. [Truncation vs Rounding Rules](#truncation-vs-rounding-rules)
6. [Validation Order](#validation-order)
7. [Leap Second Handling](#leap-second-handling)
8. [Performance Optimizations](#performance-optimizations)
9. [Design Decisions](#design-decisions)

## Architecture Overview

The converter follows a **6-phase pipeline architecture** where each phase is implemented as a separate jq module:

```
Input String
    ↓
Phase 1: Input Validation & Length Check
    ↓
Phase 2: Input Classification & Parsing
    ↓
Phase 3: Calendar System Conversion
    ↓
Phase 4: Date Normalization
    ↓
Phase 5: Time & Timezone Normalization
    ↓
Phase 6: Unix Epoch Computation
    ↓
Output (Integer or Float)
```

### Module Organization

```
lib/
├── iso8601_to_epoch.jq          # main entry point (pipeline orchestration)
├── core/
│   ├── error.jq                 # standardized error formatting
│   └── utils.jq                 # string, math, date/time utilities
├── validation/
│   └── input_validation.jq      # phase 1: input validation
├── parsing/
│   └── input_parser.jq          # phase 2: input parsing
├── calendar/
│   └── calendar_converter.jq    # phase 3: calendar conversions
├── normalization/
│   ├── date_normalizer.jq       # phase 4: date normalization
│   └── time_normalizer.jq       # phase 5: time/timezone normalization
└── epoch/
    └── epoch_calculator.jq      # phase 6: epoch calculation
```

## Pipeline Phases

### Phase 1: Input Validation & Length Check

**Module**: `lib/validation/input_validation.jq`

**Purpose**: Validate input length constraints before parsing to prevent resource exhaustion.

**Algorithm**:
1. Check total input length ≤ 100 characters
2. Extract and validate component lengths:
   - Year: ≤ 7 digits (including sign)
   - Fractional seconds: ≤ 9 digits
   - Fractional timezone: ≤ 4 digits
   - Calendar indicator: ≤ 20 characters
3. Return input unchanged if valid, throw error otherwise

**Implementation Details**:
- Uses jq's `length` function for string length
- Regex patterns to extract specific components
- First validation error stops further processing

### Phase 2: Input Classification & Parsing

**Module**: `lib/parsing/input_parser.jq`

**Purpose**: Parse ISO-8601 string and identify all components.

**Algorithm**:
1. Extract calendar system indicator (if present): `^(gregorian|julian|islamic|buddhist|hebrew|persian|chinese):(.+)$`
2. Detect date format using pattern matching precedence:
   - Calendar dates: `YYYY-MM-DD` → `YYYY-MM` → `YYYY` → `YYYYMMDD`
   - Ordinal dates: `YYYY-DDD` → `YYYYDDD`
   - Week dates: `YYYY-Www-D` → `YYYYWwwD` → `YYYY-Www` → `YYYYWww`
3. Extract time components: `T(\d{2})(?::?(\d{2})(?::?(\d{2})(?:\.(\d{1,9}))?)?)?`
4. Extract timezone: `(Z|([+-])(\d{2})(?::?(\d{2})|\.(\d{1,4}))?)`
5. Detect leap second (second == 60)

**Pattern Matching Precedence**:
- Try most specific patterns first (with separators)
- Fall back to compact formats
- Reject ambiguous formats (e.g., YYYYMM)

**Output**: Structured object with all parsed components

### Phase 3: Calendar System Conversion

**Module**: `lib/calendar/calendar_converter.jq`

**Purpose**: Convert alternative calendar dates to Gregorian calendar.

**Supported Calendars**:
- **Gregorian** (default): No conversion needed
- **Julian**: Algorithmic conversion (exact)
- **Buddhist**: Simple offset (exact)
- **Islamic**: Lookup tables + interpolation (±1 day)
- **Hebrew**: Lookup tables + interpolation (±1 day)
- **Persian**: Astronomical algorithms (exact)
- **Chinese**: Lookup tables + interpolation (±1 day)

See [Calendar Conversion Methods](#calendar-conversion-methods) for detailed algorithms.

### Phase 4: Date Normalization

**Module**: `lib/normalization/date_normalizer.jq`

**Purpose**: Convert any date format to Gregorian calendar date (YYYY-MM-DD).

**Algorithms**:

#### Calendar Date Normalization
1. Extract year, month (default 1), day (default 1)
2. Validate month range (1-12)
3. Validate day range based on month and leap year
4. Return normalized date

#### Ordinal Date Conversion
1. Validate ordinal day range (1-365 or 1-366 for leap years)
2. Accumulate days per month until ordinal day is reached
3. Return month and day

**Algorithm**:
```
remaining_days = ordinal_day
for month in 1..12:
    days_in_month = get_days_in_month(year, month)
    if remaining_days <= days_in_month:
        return (month, remaining_days)
    remaining_days -= days_in_month
```

#### ISO Week Date Conversion
1. Validate week number (1-53) and weekday (1-7)
2. Check if year has 53 weeks (special rule)
3. Find January 4 (always in week 1)
4. Calculate day of week for January 4
5. Find Monday of week 1
6. Add (week - 1) * 7 + (weekday - 1) days

**ISO Week 1 Rule**: First week containing the first Thursday of the year.

**Algorithm**:
```
jan4 = date(year, 1, 4)
jan4_dow = day_of_week(jan4)  # monday=1, sunday=7
week1_monday = jan4 - (jan4_dow - 1) days
target_date = week1_monday + (week - 1) * 7 + (weekday - 1) days
```

**53-Week Years**: A year has 53 weeks if:
- January 1 falls on Thursday, OR
- It's a leap year AND January 1 falls on Wednesday

#### Day of Week Calculation
Uses **Zeller's Congruence** algorithm adapted for ISO week dates:

```
# adjust for zeller's (jan/feb are months 13/14 of previous year)
if month < 3:
    y = year - 1
    m = month + 12
else:
    y = year
    m = month

K = y % 100
J = y / 100

h = (day + floor(13*(m+1)/5) + K + floor(K/4) + floor(J/4) - 2*J) % 7

# convert zeller's result (0=saturday) to ISO (1=monday, 7=sunday)
iso_dow = ((h + 6) % 7) or 7
```

### Phase 5: Time & Timezone Normalization

**Module**: `lib/normalization/time_normalizer.jq`

**Purpose**: Convert time and timezone to seconds since midnight and apply offset.

**Algorithms**:

#### Time Normalization
1. Parse hour, minute, second, fractional component
2. Identify fractional unit (hour, minute, or second)
3. Convert to total seconds:
   - Fractional hours: `(hour + fractional) * 3600`
   - Fractional minutes: `hour * 3600 + (minute + fractional) * 60`
   - Fractional seconds: `hour * 3600 + minute * 60 + second + fractional`
4. Truncate fractional part to 9 decimal places
5. Validate ranges: hour (0-23), minute (0-59), second (0-60)

#### Timezone Normalization
1. Parse timezone indicator (Z, ±hh, ±hh:mm, ±hh.hhhh)
2. Convert to offset in seconds:
   - Z: 0
   - ±hh: `±(hours * 3600)`
   - ±hh:mm: `±(hours * 3600 + minutes * 60)`
   - ±hh.hhhh: `±(fractional_hours * 3600)` (truncate to 4 decimal places)
3. Validate offset < ±24 hours
4. Default to 0 (UTC) if no timezone specified

#### Timezone Rollover
Apply formula: **UTC = local time - offset**

1. Calculate UTC time: `utc_time = time_seconds - offset_seconds`
2. If `utc_time < 0`: Roll back to previous day
   - `new_date = date - 1 day`
   - `new_time = 86400 + utc_time`
3. If `utc_time >= 86400`: Roll forward to next day
   - `new_date = date + 1 day`
   - `new_time = utc_time - 86400`
4. Handle month and year boundary crossings

**Date Addition Algorithm**:
```
def add_days(date, days):
    if days == 0:
        return date
    elif days > 0:
        days_in_month = get_days_in_month(date.year, date.month)
        if date.day + days <= days_in_month:
            return date(date.year, date.month, date.day + days)
        else:
            remaining = days - (days_in_month - date.day + 1)
            next_month = next_month(date)
            return add_days(date(next_month.year, next_month.month, 1), remaining)
    else:  # days < 0
        if date.day > abs(days):
            return date(date.year, date.month, date.day + days)
        else:
            prev_month = prev_month(date)
            days_in_prev = get_days_in_month(prev_month.year, prev_month.month)
            remaining = days + date.day
            return add_days(date(prev_month.year, prev_month.month, days_in_prev), remaining)
```

### Phase 6: Unix Epoch Computation

**Module**: `lib/epoch/epoch_calculator.jq`

**Purpose**: Calculate Unix epoch from normalized date, time, and timezone.

**Algorithm**:

#### Days Since Epoch Calculation

For **positive years ≥ 1970**:
```
year_days = (year - 1970) * 365
leap_days = count_leap_years(1970, year)
month_days = sum(days_in_month[0..month-1])
total_days = year_days + leap_days + month_days + day - 1
```

For **positive years < 1970**:
```
year_days = (year - 1970) * 365
leap_days = count_leap_years(year, 1970)
month_days = sum(days_in_month[0..month-1])
total_days = year_days - leap_days + month_days + day - 1
```

For **negative years (BCE)**:
```
# account for no year 0 in ISO 8601
days_1_to_1970 = (1970 - 1) * 365 + count_leap_years(1, 1970)
days_target_to_1 = (1 - year - 1) * 365 + count_leap_years(year, 1)
year_days = -(days_target_to_1 + days_1_to_1970)
month_days = sum(days_in_month[0..month-1])
total_days = year_days + month_days + day - 1
```

#### Leap Year Counting
```
def count_leap_years(from_year, to_year):
    count = 0
    for year in range(from_year, to_year):
        if year == 0:
            continue  # no year 0 in ISO 8601
        if is_leap_year(year):
            count += 1
    return count
```

#### Final Epoch Calculation
```
days = days_since_epoch(year, month, day)
epoch = days * 86400 + time_seconds

# return integer if no fractional component, float otherwise
if has_fractional:
    return epoch
else:
    return floor(epoch)
```

## Algorithms

### Leap Year Calculation

**For positive years**:
```
is_leap = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
```

**For negative years (BCE)**:
```
# year -N represents (N) BCE
# account for astronomical year numbering
n = abs(year)
adjusted = n - 1
is_leap = (adjusted % 4 == 0 and adjusted % 100 != 0) or (adjusted % 400 == 0)
```

**Examples**:
- Year -1 (1 BCE): `adjusted = 0` → leap year (divisible by 400)
- Year -4 (4 BCE): `adjusted = 3` → not leap year
- Year -5 (5 BCE): `adjusted = 4` → leap year (divisible by 4)
- Year -100 (100 BCE): `adjusted = 99` → not leap year
- Year -400 (400 BCE): `adjusted = 399` → not leap year
- Year -401 (401 BCE): `adjusted = 400` → leap year (divisible by 400)

### Days in Month

```
def days_in_month(year, month):
    if month == 2:
        return 29 if is_leap_year(year) else 28
    elif month in [1, 3, 5, 7, 8, 10, 12]:
        return 31
    else:
        return 30
```

### Truncation Function

```
def truncate_decimal(value, places):
    if places == 0:
        return floor(value)
    else:
        multiplier = 10^places
        return floor(value * multiplier) / multiplier
```

## Calendar Conversion Methods

### Julian Calendar

**Algorithm**: Algorithmic conversion (exact)

The Julian calendar uses a simpler leap year rule: every year divisible by 4 is a leap year.

**Conversion**:
1. Calculate the difference between Julian and Gregorian calendars
2. As of 2025, the difference is 13 days
3. The difference increases by 3 days every 400 years

**Formula**:
```
century = floor(julian_year / 100)
difference = century - floor(century / 4) - 2

gregorian_date = julian_date + difference days
```

**Example**:
- Julian: 2025-11-15 → Gregorian: 2025-11-28 (13-day difference)

### Buddhist Calendar

**Algorithm**: Simple offset (exact)

The Buddhist calendar is 543 years ahead of the Gregorian calendar.

**Conversion**:
```
gregorian_year = buddhist_year - 543
```

**Example**:
- Buddhist: 2568-11-28 → Gregorian: 2025-11-28

### Islamic Calendar (Hijri)

**Algorithm**: Lookup tables + algorithmic interpolation (±1 day tolerance)

The Islamic calendar is a lunar calendar with 12 months of 29 or 30 days.

**Method**:
1. Use pre-computed lookup tables for common date ranges (1400-1500 AH ≈ 1979-2077 CE)
2. For dates outside lookup range, use algorithmic approximation:
   ```
   # approximate conversion (±1 day)
   islamic_epoch = 1948439.5  # julian day of 1 muharram 1 AH
   gregorian_epoch = 1721425.5  # julian day of 1 jan 1 CE
   
   islamic_days = islamic_year * 354.36667 + month_days + day
   julian_day = islamic_epoch + islamic_days
   gregorian_days = julian_day - gregorian_epoch
   
   gregorian_date = convert_julian_day_to_date(gregorian_days)
   ```

**Accuracy**: ±1 day due to lunar month variations

### Hebrew Calendar

**Algorithm**: Lookup tables + algorithmic interpolation (±1 day tolerance)

The Hebrew calendar is a lunisolar calendar with a 19-year cycle containing 7 leap years.

**Method**:
1. Use pre-computed lookup tables for 19-year cycles
2. For dates outside lookup range, use algorithmic approximation based on Molad calculations
3. Account for leap months (Adar I and Adar II)

**Accuracy**: ±1 day due to complex intercalation rules

### Persian Calendar (Solar Hijri)

**Algorithm**: Astronomical algorithms (exact)

The Persian calendar is a solar calendar where the year begins at the vernal equinox.

**Method**:
1. Calculate vernal equinox using Meeus algorithms
2. Determine year start date
3. Add months and days:
   - First 6 months: 31 days each
   - Next 5 months: 30 days each
   - Last month: 29 or 30 days (leap year)

**Accuracy**: Exact (deterministic astronomical calculations)

### Chinese Calendar

**Algorithm**: Lookup tables + algorithmic interpolation (±1 day tolerance)

The Chinese calendar is a lunisolar calendar with a 60-year cycle.

**Method**:
1. Use pre-computed lookup tables for 60-year cycles
2. For dates outside lookup range, use algorithmic approximation based on new moon calculations
3. Account for intercalary months

**Accuracy**: ±1 day due to complex intercalation rules

## Truncation vs Rounding Rules

**All fractional components use truncation (floor), never rounding.**

This ensures deterministic output across all implementations and prevents floating-point rounding errors.

### Fractional Seconds

```
input: "23:59:59.1234567890"  # 10 digits
truncate to 9 digits: "23:59:59.123456789"
```

### Fractional Minutes

```
input: "23:59.99999999999"  # many digits
convert to seconds: 23 * 3600 + 59.99999999999 * 60 = 86399.99999999994
truncate to 9 digits: 86399.999999999
```

### Fractional Hours

```
input: "23.999999999999"  # many digits
convert to seconds: 23.999999999999 * 3600 = 86399.999999999964
truncate to 9 digits: 86399.999999999
```

### Fractional Timezone Offsets

```
input: "+05.123456"  # 6 digits
truncate to 4 digits: "+05.1234"
convert to seconds: 5.1234 * 3600 = 18442.24
```

### Implementation

```jq
def truncate_decimal(places):
  if places == 0 then
    floor
  else
    . * (pow(10; places)) | floor | . / pow(10; places)
  end;
```

## Validation Order

The function validates input in this exact order and reports only the **first error** encountered:

1. **Input Length**: Check if input exceeds maximum length (100 characters)
2. **Format Structure**: Validate ISO-8601 pattern (calendar, ordinal, week, time, timezone)
3. **Calendar System**: Validate calendar system indicator if present
4. **Year Range**: Validate year is within -999999 to +999999
5. **Component Ranges**: Validate month (01-12), day, hour (00-23), minute (00-59), second (00-60)
6. **Leap Year Rules**: Validate ordinal day 366 only for leap years
7. **ISO Week Rules**: Validate week number (01-53) and weekday (1-7)
8. **Timezone Offset**: Validate offset is within ±23:59 or ±23.9833
9. **Subsecond Precision**: Validate fractional component format

### Example

Input: `"-1000000-13-32T25:61:62.12345678901+25:00"`

First error: `"Year '-1000000' outside supported range (-999999 to +999999) in input '-1000000-13-32T25:61:62.12345678901+25:00'"`

Subsequent errors (month, day, hour, minute, second, fractional digits, timezone) are **not reported**.

## Leap Second Handling

Leap seconds (23:59:60) are treated as equivalent to 00:00:00 of the next day.

### Algorithm

```
if second == 60:
    # leap second detected
    time_seconds = hour * 3600 + minute * 60 + 60 + fractional
    
    if time_seconds >= 86400:
        # rollover to next day
        date = date + 1 day
        time_seconds = time_seconds - 86400
```

### Examples

```
input: "2016-12-31T23:59:60Z"
time_seconds: 23 * 3600 + 59 * 60 + 60 = 86400
rollover: date = 2017-01-01, time = 0
epoch: days_since_epoch(2017, 1, 1) * 86400 + 0 = 1483228800

input: "2016-12-31T23:59:60.5Z"
time_seconds: 86400.5
rollover: date = 2017-01-01, time = 0.5
epoch: 1483228800.5
```

### Officially Recognized Leap Seconds

The function accepts 23:59:60 for any date, but the following are officially announced leap seconds according to IERS:

- 1972-06-30, 1972-12-31, 1973-12-31, 1974-12-31, 1975-12-31
- 1976-12-31, 1977-12-31, 1978-12-31, 1979-12-31
- 1981-06-30, 1982-06-30, 1983-06-30, 1985-06-30
- 1987-12-31, 1989-12-31, 1990-12-31
- 1992-06-30, 1993-06-30, 1994-06-30, 1995-12-31
- 1997-06-30, 1998-12-31
- 2005-12-31, 2008-12-31, 2012-06-30, 2015-06-30, 2016-12-31

## Performance Optimizations

### Integer Arithmetic

- Use integer arithmetic wherever possible
- Floating-point only for subsecond precision
- Avoid unnecessary type conversions

### Efficient Leap Year Counting

Instead of naive iteration:
```jq
# efficient: use mathematical formulas
def count_leap_years_fast(from; to):
  # count years divisible by 4, subtract those divisible by 100, add back those divisible by 400
  (to / 4 | floor) - (from / 4 | floor) -
  ((to / 100 | floor) - (from / 100 | floor)) +
  ((to / 400 | floor) - (from / 400 | floor));
```

However, for correctness with negative years and year 0 handling, we use iteration.

### Minimal String Manipulation

- Parse input once
- Cache parsed components
- Avoid repeated regex matching

### Lookup Tables for Calendar Conversions

- Pre-computed tables for common date ranges
- Algorithmic interpolation for dates outside range
- Cached in memory (jq function definitions)

### No Recursive Functions

- Use iteration instead of recursion
- Avoid stack overflow for large year ranges
- Better performance in jq

## Design Decisions

### Why Pipeline Architecture?

- **Modularity**: Each phase is independent and testable
- **Maintainability**: Clear separation of concerns
- **Validation Order**: Enforces strict validation order per requirements
- **Error Handling**: First error stops pipeline immediately

### Why No External Dependencies?

- **Determinism**: Identical results across all environments
- **Portability**: Works on any system with jq 1.6+
- **Security**: No external code execution
- **Performance**: No network or file I/O

### Why Truncation Instead of Rounding?

- **Determinism**: Rounding can vary across implementations
- **Consistency**: Truncation is unambiguous
- **Requirement**: Specified in requirements document
- **Precision**: Preserves exact input values up to limit

### Why Support Alternative Calendars?

- **Completeness**: Handle dates from various cultural contexts
- **Flexibility**: Support historical and international dates
- **Accuracy**: Provide best-effort conversions with documented tolerances

### Why Limit Input Length?

- **Security**: Prevent resource exhaustion attacks
- **Performance**: Ensure predictable processing time
- **Practicality**: 100 characters sufficient for all valid ISO-8601 dates

### Why Report Only First Error?

- **Clarity**: Avoid overwhelming users with multiple errors
- **Efficiency**: Stop processing as soon as invalid input detected
- **Requirement**: Specified in requirements document

### Why Support Negative Years?

- **Historical Dates**: Enable BCE date conversions
- **Completeness**: Support full ISO-8601 extended year range
- **Proleptic Calendar**: Apply Gregorian rules consistently to all dates

### Why Accept Non-Official Leap Seconds?

- **Compatibility**: Some systems may use 23:59:60 for other purposes
- **Flexibility**: Don't reject valid ISO-8601 format
- **Documentation**: Clearly document official vs non-official leap seconds

## Testing Strategy

### Unit Tests

Each module tested independently:
- Input validation
- Input parsing
- Calendar conversions
- Date normalization
- Time normalization
- Epoch calculation

### Integration Tests

Complete pipeline tested with:
- All date formats
- All time formats
- All timezone formats
- Extended year ranges
- Leap seconds
- Alternative calendars
- Error cases

### Determinism Tests

Verify identical outputs:
- Run same inputs multiple times
- Compare outputs for exact equality
- Test across different jq versions

### Performance Tests

Verify performance requirements:
- Single conversion: <10ms
- 10,000 conversions: <100s
- 100,000 conversions: <1000s
- 1M conversions: consistent performance

## References

- ISO 8601:2004 - Data elements and interchange formats
- RFC 3339 - Date and Time on the Internet: Timestamps
- IERS Bulletin C - Leap second announcements
- Meeus, Jean - Astronomical Algorithms (2nd edition)
- Zeller's Congruence - Day of week calculation
- Proleptic Gregorian Calendar - Wikipedia

## Maintenance

### Adding New Calendar Systems

1. Add calendar identifier to parser regex
2. Implement conversion function in `lib/calendar/calendar_converter.jq`
3. Add validation for calendar-specific date components
4. Add test cases for new calendar
5. Update documentation

### Updating Leap Second List

1. Update list in `IMPLEMENTATION.md`
2. Update documentation in `README.md`
3. Add test cases for new leap second dates
4. No code changes required (function accepts any 23:59:60)

### Performance Improvements

1. Profile with `jq --debug-trace`
2. Identify bottlenecks
3. Optimize hot paths (epoch calculation, leap year counting)
4. Verify determinism maintained
5. Run full test suite
6. Update performance documentation

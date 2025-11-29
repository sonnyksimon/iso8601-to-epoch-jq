# Requirements Document

## Introduction

This document specifies the requirements for implementing an `iso8601_to_epoch` function in jq that converts any valid ISO-8601 date or datetime string into a Unix epoch timestamp (UTC seconds). The function must handle all ISO-8601 date formats (calendar, ordinal, week dates), time formats (with fractional components), and timezone offsets, while rejecting invalid or ambiguous inputs.

The function accepts string input representing ISO-8601 dates and datetimes, and produces numeric output representing Unix epoch seconds in UTC. Output will be an integer for whole seconds, or a floating-point number when subsecond precision is present. All timestamps are normalized to UTC regardless of input timezone offsets. The function supports dates before 1970 (producing negative Unix epoch values) and does not rely on system local timezone settings or locale.

The function supports extended year ranges including negative years for BCE dates (e.g., -0001 for 1 BCE). The function applies proleptic Gregorian calendar rules for all dates, including those before the historical adoption of the Gregorian calendar (1582) and for negative years. All date-time calculations must be performed using UTC and cannot rely on system timezone settings. 

The function supports leap seconds (23:59:60) and correctly converts them to Unix epoch values. Fractional hour timezone offsets (e.g., +05.5, -03.25) are supported and correctly applied. The function also provides optional support for alternative calendar systems (Julian, Islamic, Buddhist, etc.) with normalization to UTC for Unix epoch calculation.

All error messages must be human-readable, include the invalid input value, and clearly indicate the cause of rejection. Leading zeros are required in date and time components where specified by the format (e.g., months must be 01-12, not 1-12 in YYYY-MM format; ordinal days must be 001-366, not 1-366).

## Glossary

- **ISO-8601**: International standard for date and time representation
- **Unix Epoch**: Number of seconds since January 1, 1970 00:00:00 UTC; can be negative for dates before 1970
- **Negative Unix Epoch**: Seconds before January 1, 1970 00:00:00 UTC, represented as negative numbers (e.g., 1969-12-31T23:59:59Z = -1)
- **UTC**: Coordinated Universal Time, the primary time standard
- **Calendar Date**: Standard YYYY-MM-DD format
- **Ordinal Date**: Year and day-of-year format (YYYY-DDD) where DDD ranges from 001-365 or 001-366 for leap years
- **Week Date**: ISO week-based date format (YYYY-Www-D)
- **Timezone Offset**: Hours and minutes difference from UTC (±hh:mm); fractional hour offsets (e.g., +05.5, -03.25) are supported
- **Fractional Precision**: Subsecond time components with 1-9 decimal places (e.g., .1 second = 0.1s, .1 hour = 360s, .5 minute = 30s)
- **Leap Second**: Additional second inserted at end of day (23:59:60); supported by this function
- **Extended Year**: Years beyond 0000-9999 range, including negative years for BCE dates (e.g., -0001 for 1 BCE)
- **Alternative Calendar**: Non-Gregorian calendar systems such as Julian, Islamic, Buddhist, Hebrew, etc.
- **jq**: Command-line JSON processor and functional programming language
- **Function**: The iso8601_to_epoch jq function being implemented
- **Gregorian Calendar**: The calendar system used for date calculations

## Requirements

### Requirement 1: Calendar Date Support

**User Story:** As a user, I want to convert calendar dates in various ISO-8601 formats to Unix epoch, so that I can work with standardized date representations.

#### Acceptance Criteria

1. WHEN the Function receives input "YYYY", THE Function SHALL return the Unix epoch for January 1 of that year at 00:00:00 UTC
2. WHEN the Function receives input "YYYY-MM", THE Function SHALL return the Unix epoch for the first day of that month at 00:00:00 UTC
3. WHEN the Function receives input "YYYY-MM-DD", THE Function SHALL return the Unix epoch for that specific date at 00:00:00 UTC
4. WHEN the Function receives input "YYYYMMDD", THE Function SHALL return the Unix epoch for that specific date at 00:00:00 UTC
5. WHEN the Function parses calendar dates, THE Function SHALL apply pattern matching precedence: first attempt YYYY-MM-DD, then YYYY-MM, then YYYY, then YYYYMMDD
6. IF the Function receives input "YYYYMM", THEN THE Function SHALL reject the input with error message "Ambiguous date format 'YYYYMM' in input 'YYYYMM'"
7. IF the Function receives input "2025-13-01", THEN THE Function SHALL reject the input with error message "Invalid month '13' in input '2025-13-01'"
8. IF the Function receives input "2025-11-32", THEN THE Function SHALL reject the input with error message "Invalid day '32' in input '2025-11-32'"
9. IF the Function receives input "2025-00-01", THEN THE Function SHALL reject the input with error message "Invalid month '00' in input '2025-00-01'"

### Requirement 2: Ordinal Date Support

**User Story:** As a user, I want to convert ordinal dates (day-of-year format) to Unix epoch, so that I can process dates expressed as year and day number.

#### Acceptance Criteria

1. WHEN the Function receives input "YYYY-DDD", THE Function SHALL convert the ordinal date to Gregorian Calendar format and return the Unix epoch for that date at 00:00:00 UTC
2. WHEN the Function receives input "YYYYDDD", THE Function SHALL convert the ordinal date to Gregorian Calendar format and return the Unix epoch for that date at 00:00:00 UTC
3. WHEN the Function receives input "2024-001", THE Function SHALL return the Unix epoch for January 1, 2024 at 00:00:00 UTC
4. WHEN the Function receives input "2024-060", THE Function SHALL return the Unix epoch for February 29, 2024 at 00:00:00 UTC
5. WHEN the Function receives input "2023-365" for non-leap year 2023, THE Function SHALL return the Unix epoch value 1704067200 for December 31, 2023 at 00:00:00 UTC
6. WHEN the Function receives input "2024-365" for leap year 2024, THE Function SHALL return the Unix epoch value 1735516800 for December 30, 2024 at 00:00:00 UTC
7. WHEN the Function receives input "2024-366" for leap year 2024, THE Function SHALL return the Unix epoch value 1735603200 for December 31, 2024 at 00:00:00 UTC
8. WHEN the Function receives input "-0004-366" for a BCE leap year (4 BCE), THE Function SHALL return the Unix epoch value -62293651200 for December 31, 4 BCE at 00:00:00 UTC
9. WHEN the Function receives input "2016-12-31T23:59:59.999999999Z", THE Function SHALL preserve all 9 digits of fractional precision in the output
10. IF the Function receives input "2024-000", THEN THE Function SHALL reject the input as invalid
11. IF the Function receives input "2023-366" for non-leap year 2023, THEN THE Function SHALL reject the input as invalid
12. IF the Function receives ordinal day greater than 366 for any year, THEN THE Function SHALL reject the input as invalid

### Requirement 3: Week Date Support

**User Story:** As a user, I want to convert ISO week dates to Unix epoch, so that I can work with week-based date representations.

#### Acceptance Criteria

1. WHEN the Function receives input "YYYY-Www", THE Function SHALL convert the week date to Gregorian Calendar format using ISO week rules and return the Unix epoch for the Monday of that week at 00:00:00 UTC
2. WHEN the Function receives input "YYYYWww", THE Function SHALL convert the week date to Gregorian Calendar format using ISO week rules and return the Unix epoch for the Monday of that week at 00:00:00 UTC
3. WHEN the Function receives input "YYYY-Www-D", THE Function SHALL convert the week date to Gregorian Calendar format using ISO week rules and return the Unix epoch for that specific weekday at 00:00:00 UTC
4. WHEN the Function receives input "YYYYWwwD", THE Function SHALL convert the week date to Gregorian Calendar format using ISO week rules and return the Unix epoch for that specific weekday at 00:00:00 UTC
5. WHEN the Function receives input "2020-W01-1", THE Function SHALL return the Unix epoch for December 30, 2019 at 00:00:00 UTC because ISO week 1 of 2020 starts in the previous Gregorian year
6. WHEN the Function receives input "2020-W53-7", THE Function SHALL return the Unix epoch for January 3, 2021 at 00:00:00 UTC because ISO week 53 of 2020 extends into the next Gregorian year
7. WHEN the Function receives input "-0004-W01-1" for a BCE leap year (4 BCE), THE Function SHALL apply ISO week rules and return the Unix epoch value -62325187200 for the Monday of ISO week 1 in 4 BCE at 00:00:00 UTC
8. WHEN the Function receives input "2024-W53-1" for a leap year with 53 weeks, THE Function SHALL accept it as valid and return the correct Unix epoch
9. IF the Function receives week number 00, THEN THE Function SHALL reject the input as invalid
10. IF the Function receives week number greater than 53, THEN THE Function SHALL reject the input as invalid
11. IF the Function receives weekday number 0, THEN THE Function SHALL reject the input as invalid because valid weekdays are 1-7
12. IF the Function receives weekday number greater than 7, THEN THE Function SHALL reject the input as invalid because valid weekdays are 1-7

### Requirement 4: Time Format Support

**User Story:** As a user, I want to specify time components in various ISO-8601 formats with fractional precision, so that I can represent precise moments within a day.

#### Acceptance Criteria

1. WHEN the Function receives time format "Thh", THE Function SHALL parse the hour component and add the corresponding seconds to the date's Unix epoch
2. WHEN the Function receives time format with fractional hours "Thh.hhh", THE Function SHALL parse the fractional hour component and convert it to seconds with subsecond precision
3. WHEN the Function receives input "1970-01-01T05.5Z", THE Function SHALL return floating-point value 19800.0 representing 5.5 hours in seconds
4. WHEN the Function receives time format "Thh:mm" or "Thhmm", THE Function SHALL parse hour and minute components and add the corresponding seconds to the date's Unix epoch
5. WHEN the Function receives time format with fractional minutes "Thh:mm.mmm" or "Thhmm.mmm", THE Function SHALL parse the fractional minute component and convert it to seconds with subsecond precision
6. WHEN the Function receives input "1970-01-01T05:30.5Z", THE Function SHALL return floating-point value 19830.0 representing 5 hours 30.5 minutes in seconds
7. WHEN the Function receives time format "Thh:mm:ss" or "Thhmmss", THE Function SHALL parse hour, minute, and second components and add the corresponding seconds to the date's Unix epoch
8. IF the Function receives time component without date component, THEN THE Function SHALL reject the input as invalid

### Requirement 5: Subsecond Precision Support

**User Story:** As a user, I want to preserve subsecond precision in timestamps with 1-9 digits of fractional precision, so that I can work with high-precision time measurements.

#### Acceptance Criteria

1. WHEN the Function receives time format with fractional seconds "Thh:mm:ss.sss" or "Thhmmss.sss", THE Function SHALL parse the fractional second component and preserve subsecond precision in the output
2. WHEN the Function receives time format with fractional minutes "Thh:mm.mmm" or "Thhmm.mmm", THE Function SHALL convert the fractional minute component to seconds and preserve subsecond precision in the output
3. WHEN the Function receives time format with fractional hours "Thh.hhh", THE Function SHALL convert the fractional hour component to seconds and preserve subsecond precision in the output
4. WHEN the Function receives fractional component with 1-9 digits, THE Function SHALL preserve all digits in the output
5. WHEN the Function receives fractional component with more than 9 digits, THE Function SHALL truncate to 9 digits without rounding
6. WHEN the Function receives input "1970-01-01T00:00:00.1Z", THE Function SHALL return floating-point value 0.1
7. WHEN the Function receives input "1970-01-01T00:00:00.123456789Z", THE Function SHALL return floating-point value 0.123456789
8. WHEN the Function receives input "1970-01-01T05.123456Z", THE Function SHALL return floating-point value representing 5.123456 hours converted to seconds with subsecond precision
9. WHEN the Function receives input "1970-01-01T05:30.123456Z", THE Function SHALL return floating-point value representing 5 hours 30.123456 minutes converted to seconds with subsecond precision
10. WHEN the Function output includes subsecond precision, THE Function SHALL return a floating-point number representing the Unix epoch with fractional seconds
11. WHEN the Function output has no subsecond component, THE Function SHALL return an integer representing the Unix epoch in whole seconds

### Requirement 6: Timezone Offset Support

**User Story:** As a user, I want timezone offsets including fractional hours to be correctly applied to timestamps, so that all results are normalized to UTC.

#### Acceptance Criteria

1. WHEN the Function receives timezone indicator "Z", THE Function SHALL treat the input time as UTC with zero offset
2. WHEN the Function receives timezone format "±hh", THE Function SHALL parse the hour offset and apply it using the formula UTC = local time - offset
3. WHEN the Function receives timezone format "±hhmm" or "±hh:mm", THE Function SHALL parse the hour and minute offset and apply it using the formula UTC = local time - offset
4. WHEN the Function receives timezone format with fractional hours "±hh.hhhh", THE Function SHALL parse the fractional hour offset with up to 4 decimal places and apply it using the formula UTC = local time - offset
5. WHEN the Function receives fractional hour offset with more than 4 decimal places, THE Function SHALL truncate to 4 decimal places without rounding
6. WHEN the Function receives input "2025-11-28T12:00+05.5", THE Function SHALL apply the offset of 5.5 hours (5 hours 30 minutes) to produce the correct Unix epoch
7. WHEN the Function receives input "2025-11-28T12:00+05:30", THE Function SHALL apply the offset using UTC = local time - offset to produce the correct Unix epoch
8. WHEN the Function receives input "2025-11-28T12:00-03.25", THE Function SHALL apply the offset of -3.25 hours (-3 hours 15 minutes) to produce the correct Unix epoch
9. WHEN the Function receives input "2025-11-28T12:00+05.3333", THE Function SHALL apply the offset of 5.3333 hours with subsecond precision
10. WHEN the Function receives a datetime without timezone indicator, THE Function SHALL assume UTC with zero offset
11. IF the Function receives timezone offset "+24:00" or "+24.0", THEN THE Function SHALL reject the input as invalid
12. IF the Function receives timezone offset "-25" or "-25.0", THEN THE Function SHALL reject the input as invalid
13. IF the Function receives timezone offset "+000", THEN THE Function SHALL reject the input as invalid
14. IF the Function receives timezone indicator without date or time component, THEN THE Function SHALL reject the input as invalid

### Requirement 7: Leap Year Handling

**User Story:** As a user, I want leap years to be correctly identified and handled, so that date calculations are accurate across all years.

#### Acceptance Criteria

1. WHEN the Function processes a year divisible by 4 and not divisible by 100, THE Function SHALL treat that year as a leap year with 366 days
2. WHEN the Function processes a year divisible by 400, THE Function SHALL treat that year as a leap year with 366 days
3. WHEN the Function processes a year divisible by 100 but not by 400, THE Function SHALL treat that year as a non-leap year with 365 days
4. WHEN the Function processes ordinal date 366 for a leap year, THE Function SHALL accept the input as valid
5. IF the Function receives ordinal date 366 for a non-leap year, THEN THE Function SHALL reject the input as invalid

### Requirement 8: Input Validation

**User Story:** As a user, I want invalid or ambiguous inputs to be rejected with clear failures, so that I can identify and correct data quality issues.

#### Acceptance Criteria

1. IF the Function receives a month value less than 01 or greater than 12 for Gregorian calendar, THEN THE Function SHALL reject the input as invalid
2. IF the Function receives a day value that exceeds the number of days in the specified month, THEN THE Function SHALL reject the input as invalid
3. IF the Function receives input "24:00:01", THEN THE Function SHALL reject the input as invalid
4. IF the Function receives input "12:60:00", THEN THE Function SHALL reject the input as invalid
5. IF the Function receives an hour value greater than 23, THEN THE Function SHALL reject the input as invalid
6. IF the Function receives a minute value greater than 59, THEN THE Function SHALL reject the input as invalid
7. IF the Function receives a second value greater than 60 (excluding valid leap second 60), THEN THE Function SHALL reject the input as invalid
8. IF the Function receives time-only input without date component such as "T12:00", THEN THE Function SHALL reject the input as invalid
9. IF the Function receives timezone-only input such as "Z" or "+05:00", THEN THE Function SHALL reject the input as invalid

### Requirement 9: ISO Week Calculation

**User Story:** As a user, I want ISO week dates to be converted according to ISO-8601 week rules, so that week-based dates align with the international standard.

#### Acceptance Criteria

1. WHEN the Function converts a week date, THE Function SHALL apply the rule that ISO week 1 is the first week of the Gregorian year that contains the first Thursday of that year
2. WHEN the Function converts a week date, THE Function SHALL treat Monday as day 1 and Sunday as day 7 of the week
3. WHEN the Function converts a week date that falls in the previous Gregorian year, THE Function SHALL return the Unix epoch for the correct Gregorian date
4. WHEN the Function converts a week date that falls in the next Gregorian year, THE Function SHALL return the Unix epoch for the correct Gregorian date
5. WHEN the Function determines the number of ISO weeks in a year, THE Function SHALL recognize that years have 53 weeks if January 1 falls on Thursday or if it is a leap year and January 1 falls on Wednesday
6. IF the Function receives input "2022-W53-1", THEN THE Function SHALL reject the input as invalid because 2022 has only 52 ISO weeks
7. IF the Function receives weekday number 0, THEN THE Function SHALL reject the input as invalid
8. IF the Function receives weekday number 8, THEN THE Function SHALL reject the input as invalid

### Requirement 10: Deterministic Output

**User Story:** As a user, I want the function to produce consistent results across different jq versions and environments, so that my data processing pipelines are reliable.

#### Acceptance Criteria

1. THE Function SHALL produce identical Unix epoch output for identical valid input across all supported jq versions
2. THE Function SHALL compute Unix epoch values using UTC consistently without relying on system local timezone
3. THE Function SHALL not use jq built-in date parsing functions such as `fromdate`, `todate`, or `strptime` for correctness validation or computation
4. WHEN the Function processes datetime values with timezone offsets, THE Function SHALL apply offsets correctly and not ignore them
5. WHEN the Function processes fractional seconds, week dates, ordinal dates, and timezone offsets, THE Function SHALL produce identical results independent of system environment
6. THE Function SHALL use explicit date and time calculation algorithms that produce deterministic results
7. THE Function SHALL avoid system-dependent behavior in all date and time calculations
8. THE Function SHALL ensure calculations are independent of system locale settings

### Requirement 11: Date-Time Combination Handling

**User Story:** As a user, I want to combine date and time components in various formats, so that I can represent complete timestamps flexibly.

#### Acceptance Criteria

1. WHEN the Function receives format "<date>T<time><zone>", THE Function SHALL parse the date component, time component, and timezone offset separately and combine them to produce the Unix epoch
2. WHEN the Function receives format "<date>T<time>" without timezone, THE Function SHALL assume UTC timezone with zero offset
3. WHEN the Function receives date-only input without time component, THE Function SHALL assume 00:00:00 UTC as the time
4. WHEN the Function receives input "2025-11-28T05:10Z" and input "2025-11-28T01:10-04:00", THE Function SHALL return identical Unix epoch values for both inputs
5. WHEN the Function receives input "2025332T23:59:59Z", THE Function SHALL parse the ordinal date, time, and timezone to produce the Unix epoch
6. WHEN the Function receives input "2025-W48-5T12:34:56.789+05:30", THE Function SHALL parse the week date, time with subsecond precision, and timezone offset to produce the Unix epoch
7. IF the Function receives time component without date component such as "T12:00Z", THEN THE Function SHALL reject the input as invalid
8. IF the Function receives timezone indicator without date or time component, THEN THE Function SHALL reject the input as invalid

### Requirement 12: Datetime Rollover Handling

**User Story:** As a user, I want datetime calculations to correctly handle rollovers across day, month, and year boundaries, so that timezone adjustments produce accurate results.

#### Acceptance Criteria

1. WHEN the Function applies a timezone offset that causes the time to exceed 23:59:59, THE Function SHALL roll over to the next day and adjust the date accordingly
2. WHEN the Function applies a timezone offset that causes the time to become negative, THE Function SHALL roll back to the previous day and adjust the date accordingly
3. WHEN the Function receives input "2025-01-01T01:00-03:00", THE Function SHALL apply the negative offset to roll back to the previous day December 31, 2024 at 22:00:00 UTC
4. WHEN the Function receives input "2020-W53-7T23:00:00Z" with a 2-hour positive offset applied, THE Function SHALL return the Unix epoch for January 1, 2021 at 01:00:00 UTC
5. WHEN the Function receives input "2024-366T23:59:59Z" with a 1-second positive offset applied, THE Function SHALL return the Unix epoch for January 1, 2025 at 00:00:00 UTC
6. WHEN the Function performs date rollover that crosses a month boundary, THE Function SHALL adjust the month and year accordingly using correct days-per-month values
7. WHEN the Function performs date rollover that crosses a year boundary, THE Function SHALL adjust the year accordingly
8. WHEN the Function performs rollover calculations with fractional seconds, THE Function SHALL ensure fractional components do not incorrectly affect day/month/year boundaries
9. WHEN the Function performs rollover calculations, THE Function SHALL maintain correct Unix epoch values in UTC


### Requirement 13: Leap Second Support

**User Story:** As a user, I want to convert timestamps containing leap seconds to Unix epoch, so that I can accurately represent all valid ISO-8601 times including leap seconds.

#### Acceptance Criteria

1. WHEN the Function receives input containing "23:59:60" for an officially announced leap second date, THE Function SHALL accept it as a valid leap second
2. WHEN the Function receives input containing "23:59:60" for a date that is not an officially announced leap second, THE Function SHALL accept it for compatibility but document that it represents a non-standard leap second
3. WHEN the Function converts a leap second to Unix epoch, THE Function SHALL maintain UTC consistency by treating 23:59:60 as equivalent to the following second (00:00:00 of the next day)
4. WHEN the Function receives input "2016-12-31T23:59:60Z", THE Function SHALL return the Unix epoch value 1483228800 (equivalent to 2017-01-01T00:00:00Z)
5. WHEN the Function receives fractional seconds with leap second notation such as "23:59:60.5", THE Function SHALL accept values where the total is less than 61 seconds
6. WHEN the Function receives input "23:59:60.999", THE Function SHALL accept it as valid and convert to Unix epoch with subsecond precision
7. WHEN the Function applies timezone offset to a leap second, THE Function SHALL correctly handle rollover to the next day
8. WHEN the Function receives leap second combined with fractional hour offset such as "2016-12-31T23:59:60.5+05.5", THE Function SHALL correctly apply both fractional second and fractional offset
9. IF the Function receives input "23:59:61", THEN THE Function SHALL reject it with error message "Invalid second '61' in input '<original_input>'"
10. THE Function SHALL support all officially announced leap seconds according to IERS announcements
11. THE Function SHALL document the list of dates with official leap seconds in the implementation
12. THE Function SHALL provide a mechanism to update the list of officially announced leap seconds as new ones are announced by IERS


### Requirement 14: Error Reporting

**User Story:** As a user, I want clear and descriptive error messages when invalid inputs are rejected, so that I can identify and correct input data issues.

#### Acceptance Criteria

1. WHEN the Function rejects an invalid input, THE Function SHALL produce a descriptive error message indicating the reason for rejection
2. WHEN the Function produces an error message, THE Function SHALL include the invalid input value in the message for debugging purposes
3. WHEN the Function produces an error message, THE Function SHALL follow the format "Invalid <component> '<value>' in input '<original_input>'"
4. THE Function SHALL not silently fail or produce incorrect results for invalid inputs
5. THE Function SHALL provide error messages that identify the specific validation rule that was violated
6. THE Function SHALL format error messages as jq error objects suitable for use in jq pipelines

## Summary of Valid Input Patterns

The function accepts the following input patterns:

**Date Formats:**
- Calendar: `YYYY`, `YYYY-MM`, `YYYY-MM-DD`, `YYYYMMDD`
- Ordinal: `YYYY-DDD`, `YYYYDDD` (where DDD is 001-365 or 001-366 for leap years)
- Week: `YYYY-Www`, `YYYYWww`, `YYYY-Www-D`, `YYYYWwwD` (where w is 01-53, D is 1-7)

**Time Formats (optional, prefixed with T):**
- `Thh`, `Thh.hhh` (fractional hours: 1-9 digits, truncated if >9)
- `Thh:mm`, `Thhmm`, `Thh:mm.mmm`, `Thhmm.mmm` (fractional minutes: 1-9 digits, truncated if >9)
- `Thh:mm:ss`, `Thhmmss`, `Thh:mm:ss.sss`, `Thhmmss.sss` (fractional seconds: 1-9 digits, truncated if >9)

**Timezone Formats (optional, follows time):**
- `Z` (UTC)
- `±hh`, `±hhmm`, `±hh:mm` (valid range: ±00:00 to ±23:59)
- `±hh.h` (fractional hours, e.g., +05.5 for +05:30, -03.25 for -03:15)

**Combined Patterns:**
- `<date>` (assumes 00:00:00 UTC)
- `<date>T<time>` (assumes UTC if no timezone specified)
- `<date>T<time><timezone>`

**Examples:**
- `"2025-11-28T12:34:56.789+05:30"` → `1732793066.789` (floating-point Unix epoch in UTC)
- `"2025-11-28T12:00+05.5"` → `1732773600` (fractional hour offset)
- `"2025-11-28T12:00-03.25"` → `1732805400` (negative fractional hour offset)
- `"2024-366"` → `1735603200` (December 31, 2024 for leap year)
- `"2020-W01-1"` → `1577664000` (December 30, 2019 - ISO week 1 starts in previous year)
- `"2020-W53-7"` → `1609632000` (January 3, 2021 - ISO week 53 extends into next year)
- `"2015-W53-1"` → `1451260800` (December 28, 2015 - year with 53 weeks)
- `"2024-W53-1"` → `1735516800` (December 30, 2024 - leap year with 53 weeks)
- `"-0004-W01-1"` → `-62325187200` (BCE leap year ISO week)
- `"1969-12-31T23:59:59Z"` → `-1` (negative Unix epoch for pre-1970 date)
- `"2016-12-31T23:59:60Z"` → `1483228800` (leap second)
- `"2016-12-31T23:59:60.5Z"` → `1483228800.5` (leap second with fractional seconds)
- `"2016-12-31T23:59:60.5+05.5"` → `1483208600.5` (leap second with fractional offset)
- `"2016-12-31T23:59:59.999999999Z"` → `1483228799.999999999` (maximum fractional precision)
- `"2024-12-31T23:59:59.5+01:00"` → `1735689599.5` (fractional second with timezone rollover)
- `"-0001-01-01T00:00:00Z"` → `-62167219200` (1 BCE)
- `"-0004-366T00:00:00Z"` → `-62293651200` (BCE leap year ordinal day 366)
- `"-999999-01-01T00:00:00Z"` → `-31557014135596800` (minimum supported year)
- `"+999999-12-31T23:59:59Z"` → `31556889832403199` (maximum supported year)
- `"-999999-01-01T00:00:00Z"` → negative Unix epoch for minimum supported year
- `"+999999-12-31T23:59:59Z"` → positive Unix epoch for maximum supported year
- `"julian:2025-11-15T12:00:00Z"` → Unix epoch for Julian calendar date converted to Gregorian
- `"buddhist:2568-11-28T12:00:00Z"` → `1732791600` (Buddhist calendar date, 2025 CE)
- `"islamic:1446-05-27T12:00:00Z"` → Unix epoch for Islamic calendar date converted to Gregorian

**Output:**
- Integer for whole seconds
- Floating-point for subsecond precision (up to 9 decimal places)
- Negative values for dates before January 1, 1970

**Rejected Inputs:**
- Ambiguous concatenated formats (e.g., `YYYYMM`)
- Invalid date/time components (e.g., month 00 or 13, day 32, hour 24, minute 60, second >60)
- Time-only or timezone-only inputs without date (e.g., `T12:00Z`, `+05:00`)
- Invalid week numbers (00 or >53 for years with only 52 weeks), weekdays (0 or 8), or ordinal days (000 or >366)
- Timezone offsets ≥±24:00 or with invalid formats (e.g., `+000`, `+24:00`, `-25`)
- Years outside supported range (-999999 to +999999)
- Unsupported calendar system indicators
- Invalid date components for specified calendar system

**Pattern Matching Precedence:**
1. Calendar dates: YYYY-MM-DD → YYYY-MM → YYYY → YYYYMMDD
2. Ordinal dates: YYYY-DDD → YYYYDDD
3. Week dates: YYYY-Www-D → YYYYWwwD → YYYY-Www → YYYYWww


### Requirement 15: Input Validation Order

**User Story:** As a user, I want input validation to follow a consistent order, so that error messages are predictable and meaningful.

#### Acceptance Criteria

1. WHEN the Function validates input, THE Function SHALL first validate the input format structure before validating component values
2. WHEN the Function validates input, THE Function SHALL validate component ranges after format validation
3. WHEN the Function validates input, THE Function SHALL validate leap year rules and ISO week rules after component range validation
4. WHEN the Function validates input, THE Function SHALL validate timezone offset values after date and time component validation
5. WHEN the Function validates input, THE Function SHALL validate subsecond precision after all other validations
6. THE Function SHALL report the first validation error encountered and stop further validation


### Requirement 16: Extended Year Range Support

**User Story:** As a user, I want to convert dates with extended year ranges including negative years for BCE dates, so that I can work with historical dates beyond the 0000-9999 range.

#### Acceptance Criteria

1. WHEN the Function receives input with year beyond 9999, THE Function SHALL accept it as a valid extended year
2. WHEN the Function receives input with negative year such as "-0001", THE Function SHALL interpret it as 1 BCE and apply proleptic Gregorian calendar rules
3. WHEN the Function receives input "-0001-01-01T00:00:00Z", THE Function SHALL return the correct negative Unix epoch value for January 1, 1 BCE
4. WHEN the Function receives input "-999999-01-01T00:00:00Z", THE Function SHALL return the correct negative Unix epoch value for the minimum supported year
5. WHEN the Function receives input "+999999-12-31T23:59:59Z", THE Function SHALL return the correct positive Unix epoch value for the maximum supported year
6. WHEN the Function processes negative years, THE Function SHALL apply leap year rules consistently (year -1 is a leap year, year -5 is a leap year, year -100 is not a leap year, year -400 is a leap year)
7. WHEN the Function receives input with year "+10000", THE Function SHALL accept it as year 10000 CE
8. WHEN the Function processes extended years, THE Function SHALL maintain deterministic output across all environments
9. THE Function SHALL support years in the range -999999 to +999999
10. IF the Function receives a year outside the supported range, THEN THE Function SHALL reject it with error message "Year '<year>' outside supported range (-999999 to +999999) in input '<original_input>'"

### Requirement 17: Alternative Calendar System Support

**User Story:** As a user, I want to convert dates from alternative calendar systems to Unix epoch, so that I can work with dates expressed in non-Gregorian calendars.

#### Acceptance Criteria

1. WHEN the Function receives input with calendar system indicator such as "julian:", THE Function SHALL parse the date according to the specified calendar system
2. WHEN the Function receives input "julian:2025-11-28T12:00:00Z", THE Function SHALL convert the Julian calendar date to Gregorian calendar and then to Unix epoch
3. WHEN the Function receives input "islamic:1446-05-27T12:00:00Z", THE Function SHALL convert the Islamic calendar date to Gregorian calendar and then to Unix epoch
4. WHEN the Function receives input "buddhist:2568-11-28T12:00:00Z", THE Function SHALL convert the Buddhist calendar date (543 years ahead of Gregorian) to Gregorian calendar and then to Unix epoch
5. WHEN the Function receives input "hebrew:5786-03-15T12:00:00Z", THE Function SHALL convert the Hebrew calendar date to Gregorian calendar and then to Unix epoch
6. WHEN the Function receives input "persian:1404-09-07T12:00:00Z", THE Function SHALL convert the Persian calendar date to Gregorian calendar and then to Unix epoch
7. WHEN the Function receives input "chinese:4723-10-15T12:00:00Z", THE Function SHALL convert the Chinese calendar date to Gregorian calendar and then to Unix epoch
8. WHEN the Function receives alternative calendar date without time component, THE Function SHALL assume 00:00:00 UTC as the time
9. WHEN the Function receives alternative calendar date without timezone indicator, THE Function SHALL assume UTC with zero offset
10. WHEN the Function converts from an alternative calendar system, THE Function SHALL normalize the result to UTC Unix epoch
11. THE Function SHALL support the following calendar systems: gregorian (default), julian, islamic, buddhist, hebrew, persian, chinese
12. IF the Function receives an unsupported calendar system indicator, THEN THE Function SHALL reject it with error message "Unsupported calendar system '<system>' in input '<original_input>'"
13. IF the Function receives invalid date components for the specified calendar system, THEN THE Function SHALL reject it with error message "Invalid <component> '<value>' for <calendar_system> calendar in input '<original_input>'"

### Requirement 18: Performance and Scalability

**User Story:** As a user, I want the function to perform efficiently when processing large datasets, so that I can use it in high-volume data processing pipelines.

#### Acceptance Criteria

1. WHEN the Function processes a single date conversion, THE Function SHALL complete the conversion in less than 10 milliseconds on standard hardware (2GHz CPU, 4GB RAM)
2. WHEN the Function processes 10,000 date conversions, THE Function SHALL complete in less than 100 seconds
3. WHEN the Function processes 100,000 date conversions, THE Function SHALL complete in less than 1000 seconds
4. WHEN the Function processes 1 million date conversions, THE Function SHALL maintain consistent performance without degradation
5. THE Function SHALL use memory efficiently and not accumulate memory leaks during batch processing
6. THE Function SHALL maintain deterministic output regardless of processing volume
7. THE Function SHALL support parallel execution without race conditions or non-deterministic behavior
8. THE Function SHALL document performance characteristics including typical CPU and memory usage for various input volumes (1k, 10k, 100k, 1M)
9. THE Function SHALL provide guidance on optimal batch sizes for high-volume processing
10. THE Function SHALL define maximum input length limits for extremely long year representations or fractional components


## Officially Recognized Leap Seconds

The function supports the following officially announced leap seconds according to IERS (International Earth Rotation and Reference Systems Service):

- 1972-06-30T23:59:60Z
- 1972-12-31T23:59:60Z
- 1973-12-31T23:59:60Z
- 1974-12-31T23:59:60Z
- 1975-12-31T23:59:60Z
- 1976-12-31T23:59:60Z
- 1977-12-31T23:59:60Z
- 1978-12-31T23:59:60Z
- 1979-12-31T23:59:60Z
- 1981-06-30T23:59:60Z
- 1982-06-30T23:59:60Z
- 1983-06-30T23:59:60Z
- 1985-06-30T23:59:60Z
- 1987-12-31T23:59:60Z
- 1989-12-31T23:59:60Z
- 1990-12-31T23:59:60Z
- 1992-06-30T23:59:60Z
- 1993-06-30T23:59:60Z
- 1994-06-30T23:59:60Z
- 1995-12-31T23:59:60Z
- 1997-06-30T23:59:60Z
- 1998-12-31T23:59:60Z
- 2005-12-31T23:59:60Z
- 2008-12-31T23:59:60Z
- 2012-06-30T23:59:60Z
- 2015-06-30T23:59:60Z
- 2016-12-31T23:59:60Z

Note: The function accepts 23:59:60 for any date, but the above list represents officially announced leap seconds. Future leap seconds will be added as announced by IERS.

## Alternative Calendar System Conversion Rules

### Julian Calendar
- Julian calendar uses a simpler leap year rule: every year divisible by 4 is a leap year
- Conversion to Gregorian accounts for the 13-day difference (as of 2025)
- The difference increases by 3 days every 400 years

### Islamic Calendar (Hijri)
- Lunar calendar with 12 months of 29 or 30 days
- Year length is approximately 354 or 355 days
- Conversion requires complex astronomical calculations
- Month names: Muharram, Safar, Rabi' al-awwal, Rabi' al-thani, Jumada al-awwal, Jumada al-thani, Rajab, Sha'ban, Ramadan, Shawwal, Dhu al-Qi'dah, Dhu al-Hijjah

### Buddhist Calendar
- Solar calendar offset by 543 years from Gregorian
- Buddhist year 2568 = Gregorian year 2025
- Otherwise follows Gregorian calendar rules

### Hebrew Calendar
- Lunisolar calendar with complex leap month rules
- 19-year cycle with 7 leap years
- Months: Nisan, Iyar, Sivan, Tammuz, Av, Elul, Tishrei, Cheshvan, Kislev, Tevet, Shevat, Adar (Adar I and Adar II in leap years)

### Persian Calendar (Solar Hijri)
- Solar calendar with precise astronomical calculations
- Year begins at vernal equinox
- First 6 months have 31 days, next 5 have 30 days, last month has 29 or 30 days

### Chinese Calendar
- Lunisolar calendar with complex intercalation rules
- 60-year cycle combining 10 heavenly stems and 12 earthly branches
- Conversion requires astronomical calculations for new moons and solar terms

### Calendar Conversion Methods

For deterministic and consistent output, the function SHALL use:

1. **Algorithmic conversion** for calendars with well-defined mathematical rules (Julian, Buddhist, Persian)
2. **Lookup tables with algorithmic interpolation** for calendars requiring astronomical calculations (Islamic, Hebrew, Chinese)
3. **Standard astronomical algorithms** (e.g., Meeus algorithms) for precise calendar conversions
4. **Precision expectations**: Calendar conversions shall be accurate to within 1 day for all supported calendars
5. **No external library dependencies**: All calendar conversion logic shall be implemented within the function to ensure deterministic output across environments

## Maximum Input Length Limits

To ensure deterministic performance and prevent resource exhaustion:

- **Year component**: Maximum 7 digits (including sign for negative years)
- **Fractional seconds**: Maximum 9 digits after decimal point
- **Fractional timezone offset**: Maximum 4 digits after decimal point
- **Total input string**: Maximum 100 characters
- **Calendar system indicator**: Maximum 20 characters

Inputs exceeding these limits will be rejected with appropriate error messages.


## Truncation and Rounding Rules

To ensure deterministic output across all implementations:

1. **Fractional Seconds**: When fractional seconds exceed 9 digits, truncate to 9 digits without rounding
   - Example: `23:59:59.1234567890` → `23:59:59.123456789`

2. **Fractional Minutes**: Convert to seconds, then truncate fractional seconds to 9 digits
   - Example: `23:59.99999999999` → `23:59:59.999999994` (truncated to 9 digits)

3. **Fractional Hours**: Convert to seconds, then truncate fractional seconds to 9 digits
   - Example: `23.999999999999` → `23:59:59.999999964` (truncated to 9 digits)

4. **Fractional Timezone Offsets**: Truncate to 4 decimal places without rounding
   - Example: `+05.123456` → `+05.1234`

5. **No Rounding**: All truncation operations use floor/truncation, never rounding, to ensure deterministic behavior

## Error Message Format

All error messages SHALL follow this standardized format:

```
"Invalid <component> '<value>' in input '<original_input>'"
```

**Examples:**
- `"Invalid month '13' in input '2025-13-01'"`
- `"Invalid second '61' in input '2025-11-28T12:00:61Z'"`
- `"Invalid weekday '8' in input '2025-W48-8'"`
- `"Invalid ordinal day '367' in input '2025-367'"`
- `"Year '-1000000' outside supported range (-999999 to +999999) in input '-1000000-01-01'"`
- `"Unsupported calendar system 'mayan' in input 'mayan:2025-11-28'"`
- `"Invalid month '13' for gregorian calendar in input 'gregorian:2025-13-01'"`
- `"Ambiguous date format 'YYYYMM' in input '202511'"`
- `"Input exceeds maximum length of 100 characters: '<truncated_input>...'"`

## Alternative Calendar Conversion Accuracy

For deterministic and consistent output across all implementations:

1. **Algorithmic Calendars** (Julian, Buddhist, Persian): Exact conversion with no tolerance
   - Julian: Exact day-for-day conversion accounting for calendar drift
   - Buddhist: Exact 543-year offset
   - Persian: Algorithmic conversion using vernal equinox calculations

2. **Astronomical Calendars** (Islamic, Hebrew, Chinese): Conversion accurate to within 1 day
   - Islamic: Lunar month calculations may vary by ±1 day depending on observation vs calculation method
   - Hebrew: Lunisolar calculations accurate to ±1 day
   - Chinese: Complex intercalation accurate to ±1 day

3. **Deterministic Method**: All implementations SHALL use the same conversion algorithms to ensure identical results for identical inputs

4. **Conversion Examples with Expected Outputs:**
   - `"julian:2025-11-15T12:00:00Z"` → `1731672000` (Gregorian: 2025-11-28T12:00:00Z)
   - `"buddhist:2568-11-28T12:00:00Z"` → `1732791600` (Gregorian: 2025-11-28T12:00:00Z)
   - `"islamic:1446-05-27T12:00:00Z"` → `1732791600` ±86400 (Gregorian: 2025-11-28T12:00:00Z ±1 day)
   - `"hebrew:5786-03-15T12:00:00Z"` → `1732791600` ±86400 (Gregorian: 2025-11-28T12:00:00Z ±1 day)
   - `"persian:1404-09-07T12:00:00Z"` → `1732791600` (Gregorian: 2025-11-28T12:00:00Z)
   - `"chinese:4723-10-15T12:00:00Z"` → `1732791600` ±86400 (Gregorian: 2025-11-28T12:00:00Z ±1 day)

## Validation Order and Error Precedence

When validating input, the function SHALL apply checks in this exact order and report only the first error encountered:

1. **Input Length**: Check if input exceeds maximum length (100 characters)
2. **Format Structure**: Validate ISO-8601 pattern (calendar, ordinal, week, time, timezone)
3. **Calendar System**: Validate calendar system indicator if present
4. **Year Range**: Validate year is within -999999 to +999999
5. **Component Ranges**: Validate month (01-12), day, hour (00-23), minute (00-59), second (00-60)
6. **Leap Year Rules**: Validate ordinal day 366 only for leap years
7. **ISO Week Rules**: Validate week number (01-53) and weekday (1-7)
8. **Timezone Offset**: Validate offset is within ±23:59 or ±23.9833
9. **Subsecond Precision**: Validate fractional component format

**Example Validation Sequence:**
- Input: `"-1000000-13-32T25:61:62.12345678901+25:00"`
- First error: `"Year '-1000000' outside supported range (-999999 to +999999) in input '-1000000-13-32T25:61:62.12345678901+25:00'"`
- (Subsequent errors for month, day, hour, minute, second, fractional digits, and timezone are not reported)

## Combined Extreme Edge Cases

To verify correctness across all features, the following combined edge cases SHALL produce deterministic outputs:

1. **Extended Year + Leap Second + Fractional Offset:**
   - Input: `"-100000-12-31T23:59:60.999+05.5"`
   - Expected: Negative Unix epoch with fractional seconds, accounting for leap second and fractional offset

2. **Maximum Year + Week 53 + Fractional Seconds:**
   - Input: `"+999999-W53-7T23:59:59.999999999Z"`
   - Expected: Maximum positive Unix epoch with 9-digit fractional precision

3. **BCE Leap Year + Ordinal 366 + Fractional Minute:**
   - Input: `"-0004-366T23:59.999999999Z"`
   - Expected: Negative Unix epoch for December 31, 4 BCE with fractional seconds from fractional minutes

4. **Alternative Calendar + Fractional Hour Offset:**
   - Input: `"julian:-0100-12-31T23.999999999+05.5"`
   - Expected: Negative Unix epoch for Julian calendar BCE date with fractional hour offset

5. **Maximum Input Length:**
   - Input: `"gregorian:+999999-12-31T23:59:59.999999999+23:59"` (58 characters)
   - Expected: Valid conversion to maximum Unix epoch with all features combined

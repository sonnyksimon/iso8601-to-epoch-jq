# Quick Reference Guide

## Basic Command

```bash
echo '"<ISO-8601-DATE>"' | jq -L lib -f lib/iso8601_to_epoch.jq 'iso8601_to_epoch'
```

## Date Format Quick Reference

| Format | Example | Description |
|--------|---------|-------------|
| `YYYY` | `"2025"` | Year only (Jan 1, 00:00:00 UTC) |
| `YYYY-MM` | `"2025-11"` | Year-month (1st day, 00:00:00 UTC) |
| `YYYY-MM-DD` | `"2025-11-28"` | Calendar date |
| `YYYYMMDD` | `"20251128"` | Compact calendar date |
| `YYYY-DDD` | `"2024-060"` | Ordinal date (day 60 = Feb 29) |
| `YYYYDDD` | `"2024060"` | Compact ordinal date |
| `YYYY-Www-D` | `"2020-W01-1"` | ISO week date |
| `YYYYWwwD` | `"2020W011"` | Compact ISO week date |

## Time Format Quick Reference

| Format | Example | Description |
|--------|---------|-------------|
| `Thh` | `"T12"` | Hour only |
| `Thh.hhh` | `"T05.5"` | Fractional hour (5.5 hours = 5h 30m) |
| `Thh:mm` | `"T12:34"` | Hour and minute |
| `Thhmm` | `"T1234"` | Compact hour and minute |
| `Thh:mm.mmm` | `"T05:30.5"` | Fractional minute |
| `Thh:mm:ss` | `"T12:34:56"` | Full time |
| `Thhmmss` | `"T123456"` | Compact full time |
| `Thh:mm:ss.sss` | `"T12:34:56.789"` | With fractional seconds (up to 9 digits) |

## Timezone Format Quick Reference

| Format | Example | Description |
|--------|---------|-------------|
| `Z` | `"Z"` | UTC |
| `±hh` | `"+05"` | Hour offset |
| `±hh:mm` | `"+05:30"` | Hour and minute offset |
| `±hhmm` | `"+0530"` | Compact offset |
| `±hh.hhhh` | `"+05.5"` | Fractional hour offset (up to 4 digits) |

## Calendar System Quick Reference

| Prefix | Example | Description |
|--------|---------|-------------|
| `gregorian:` | `"gregorian:2025-11-28"` | Gregorian (default) |
| `julian:` | `"julian:2025-11-15"` | Julian calendar |
| `buddhist:` | `"buddhist:2568-11-28"` | Buddhist calendar (+543 years) |
| `islamic:` | `"islamic:1446-05-27"` | Islamic/Hijri calendar (±1 day) |
| `hebrew:` | `"hebrew:5786-03-15"` | Hebrew calendar (±1 day) |
| `persian:` | `"persian:1404-09-07"` | Persian/Solar Hijri calendar |
| `chinese:` | `"chinese:4723-10-15"` | Chinese calendar (±1 day) |

## Common Examples

### Simple Dates
```bash
echo '"2025-11-28"' | jq -L lib -f lib/iso8601_to_epoch.jq 'iso8601_to_epoch'
# output: 1732752000
```

### With Time
```bash
echo '"2025-11-28T12:34:56Z"' | jq -L lib -f lib/iso8601_to_epoch.jq 'iso8601_to_epoch'
# output: 1732797296
```

### With Timezone
```bash
echo '"2025-11-28T12:00+05:30"' | jq -L lib -f lib/iso8601_to_epoch.jq 'iso8601_to_epoch'
# output: 1732777200
```

### With Subsecond Precision
```bash
echo '"2025-11-28T12:34:56.789Z"' | jq -L lib -f lib/iso8601_to_epoch.jq 'iso8601_to_epoch'
# output: 1732797296.789
```

### BCE Date
```bash
echo '"-0001-01-01T00:00:00Z"' | jq -L lib -f lib/iso8601_to_epoch.jq 'iso8601_to_epoch'
# output: -62167219200
```

### Leap Second
```bash
echo '"2016-12-31T23:59:60Z"' | jq -L lib -f lib/iso8601_to_epoch.jq 'iso8601_to_epoch'
# output: 1483228800
```

### Alternative Calendar
```bash
echo '"buddhist:2568-11-28T12:00:00Z"' | jq -L lib -f lib/iso8601_to_epoch.jq 'iso8601_to_epoch'
# output: 1732791600
```

## Batch Processing

### From Array
```bash
echo '["2025-11-28", "2025-11-29", "2025-11-30"]' | \
  jq -L lib 'include "lib/iso8601_to_epoch"; map(iso8601_to_epoch)'
# output: [1732752000, 1732838400, 1732924800]
```

### From JSON Objects
```bash
echo '[{"date": "2025-11-28"}, {"date": "2025-11-29"}]' | \
  jq -L lib 'include "lib/iso8601_to_epoch"; map(.date | iso8601_to_epoch)'
# output: [1732752000, 1732838400]
```

### From File
```bash
cat dates.json | jq -L lib 'include "lib/iso8601_to_epoch"; .[] | iso8601_to_epoch'
```

## Error Messages

| Error | Example Input | Error Message |
|-------|---------------|---------------|
| Invalid month | `"2025-13-01"` | `Invalid month '13' in input '2025-13-01'` |
| Invalid day | `"2025-11-32"` | `Invalid day '32' in input '2025-11-32'` |
| Invalid hour | `"2025-11-28T25:00Z"` | `Invalid hour '25' in input '2025-11-28T25:00Z'` |
| Ambiguous format | `"202511"` | `Ambiguous date format 'YYYYMM' in input '202511'` |
| Year out of range | `"-1000000-01-01"` | `Year '-1000000' outside supported range (-999999 to +999999) in input '-1000000-01-01'` |
| Unsupported calendar | `"mayan:2025-11-28"` | `Unsupported calendar system 'mayan' in input 'mayan:2025-11-28'` |

## Input Limits

| Component | Limit | Example |
|-----------|-------|---------|
| Total input | 100 characters | - |
| Year digits | 7 (including sign) | `"+999999"` or `"-999999"` |
| Fractional seconds | 9 digits | `.123456789` |
| Fractional timezone | 4 digits | `+05.1234` |
| Calendar indicator | 20 characters | `"gregorian:"` |

## Validation Order

Errors are reported in this order (first error only):

1. Input length
2. Format structure
3. Calendar system
4. Year range
5. Component ranges (month, day, hour, minute, second)
6. Leap year rules
7. ISO week rules
8. Timezone offset
9. Subsecond precision

## Truncation Rules

All fractional components use **truncation** (floor), never rounding:

- Fractional seconds: truncate to 9 digits
- Fractional minutes: convert to seconds, truncate to 9 digits
- Fractional hours: convert to seconds, truncate to 9 digits
- Fractional timezone: truncate to 4 digits

## Performance

- Single conversion: <10ms
- 10,000 conversions: <100s
- 100,000 conversions: <1000s
- 1M conversions: consistent performance

## Supported Year Range

- Minimum: `-999999` (999,999 BCE)
- Maximum: `+999999` (999,999 CE)
- Dates before 1970 produce negative Unix epoch values

## Special Cases

### Leap Seconds
- Accepted: `23:59:60` (treated as `00:00:00` of next day)
- Fractional leap seconds: `23:59:60.5` → `00:00:00.5` of next day

### ISO Week Dates
- Week 1: First week containing first Thursday
- Week 53: Only valid for certain years
- Weekday: 1=Monday, 7=Sunday

### BCE Dates
- Year `-1` = 1 BCE
- Year `-4` = 4 BCE (leap year)
- No year 0 in ISO 8601

### Incomplete Dates
- Year only: assumes January 1, 00:00:00 UTC
- Year-month: assumes first day of month, 00:00:00 UTC
- No timezone: assumes UTC (Z)

## Testing

```bash
# run all tests
make test

# run specific test
bash test/test_input_validation.sh
```

## Examples

```bash
# run comprehensive examples
bash examples/comprehensive_examples.sh

# run basic usage examples
bash examples/basic_usage.sh

# run validation examples
bash examples/validation_examples.sh
```

## Documentation

- **README.md**: User guide with usage examples
- **IMPLEMENTATION.md**: Technical documentation with algorithms
- **QUICK_REFERENCE.md**: This quick reference guide

## Getting Help

1. Check error message for specific issue
2. Verify input format matches ISO-8601
3. Check supported formats in this guide
4. Review examples in `examples/` directory
5. See full documentation in `README.md`

# input parser module
# input classification and parsing

include "lib/core/error";
include "lib/core/utils";

# supported calendar systems
def supported_calendar_systems:
  ["gregorian", "julian", "islamic", "buddhist", "hebrew", "persian", "chinese"];

# parse calendar system indicator from input
# returns: {calendar_system: string, remaining_input: string}
def parse_calendar_system:
  . as $input |
  
  # check if input has calendar system prefix (e.g., "julian:2025-11-28")
  if test("^[a-z]+:") then
    # extract calendar system and remaining input
    (match("^([a-z]+):(.+)$")) as $m |
    ($m.captures[0].string) as $cal_system |
    ($m.captures[1].string) as $remaining |
    
    # validate calendar system against supported list
    if (supported_calendar_systems | contains_element($cal_system)) then
      {
        calendar_system: $cal_system,
        remaining_input: $remaining
      }
    else
      # unsupported calendar system - throw error
      format_unsupported_calendar_error($cal_system; $input) | throw_error(.)
    end
  else
    # no calendar system prefix - default to gregorian
    {
      calendar_system: "gregorian",
      remaining_input: $input
    }
  end;

# split date/time/timezone components from input
# returns: {date_part: string, time_part: string|null, timezone_part: string|null}
def split_datetime_components:
  . as $input |
  
  # check for time-only input (starts with T)
  if test("^T") then
    format_error("date component"; "missing"; $input) | throw_error(.)
  # check for timezone-only input (just Z or timezone offset)
  elif test("^(Z|[+-][0-9]{2}(:[0-9]{2}|[0-9]{2}|\\.[0-9]{1,4})?)$") then
    format_error("date component"; "missing"; $input) | throw_error(.)
  # check if there's a time component (contains T)
  elif test("T") then
    # split on T to separate date and time+timezone
    (match("^([^T]+)T(.+)$")) as $m |
    ($m.captures[0].string) as $date_part |
    ($m.captures[1].string) as $time_tz_part |
    
    # now split time and timezone
    # timezone can be: Z, +hh, +hhmm, +hh:mm, +hh.hhhh, -hh, -hhmm, -hh:mm, -hh.hhhh
    if ($time_tz_part | test("Z$")) then
      # ends with Z
      {
        date_part: $date_part,
        time_part: ($time_tz_part | sub("Z$"; "")),
        timezone_part: "Z"
      }
    elif ($time_tz_part | test("[+-][0-9]{2}(:[0-9]{2}|[0-9]{2}|\\.[0-9]{1,4})?$")) then
      # has numeric timezone offset
      ($time_tz_part | match("^(.+?)([+-][0-9]{2}(:[0-9]{2}|[0-9]{2}|\\.[0-9]{1,4})?)$")) as $tz_m |
      {
        date_part: $date_part,
        time_part: ($tz_m.captures[0].string),
        timezone_part: ($tz_m.captures[1].string)
      }
    else
      # no timezone
      {
        date_part: $date_part,
        time_part: $time_tz_part,
        timezone_part: null
      }
    end
  else
    # no time component, check for timezone on date only (invalid but we'll catch it)
    {
      date_part: $input,
      time_part: null,
      timezone_part: null
    }
  end;

# parse calendar date format with pattern matching precedence
# precedence: YYYY-MM-DD → YYYY-MM → YYYY → YYYYMMDD
# returns: {format: "calendar", year: int, month: int|null, day: int|null} or null
def parse_calendar_date:
  . as $date_str |
  
  # try YYYY-MM-DD (extended format with full date)
  if test("^[+-]?[0-9]{1,6}-[0-9]{2}-[0-9]{2}$") then
    (match("^([+-]?[0-9]{1,6})-([0-9]{2})-([0-9]{2})$")) as $m |
    {
      format: "calendar",
      year: ($m.captures[0].string | to_int),
      month: ($m.captures[1].string | to_int),
      day: ($m.captures[2].string | to_int)
    }
  # try YYYY-MM (extended format with year and month)
  elif test("^[+-]?[0-9]{1,6}-[0-9]{2}$") then
    (match("^([+-]?[0-9]{1,6})-([0-9]{2})$")) as $m |
    {
      format: "calendar",
      year: ($m.captures[0].string | to_int),
      month: ($m.captures[1].string | to_int),
      day: null
    }
  # check for ambiguous YYYYMM format (6 digits without separators) BEFORE trying YYYY
  # this must come before YYYY pattern to catch ambiguous 6-digit inputs
  elif test("^[0-9]{6}$") then
    # this is ambiguous - could be YYYYMM or YYMMDD
    . as $input_full |
    format_ambiguous_format_error("YYYYMM"; $input_full) | throw_error(.)
  # try YYYY (year only) - but exclude 6-digit numbers (caught above)
  elif test("^[+-]?[0-9]{1,6}$") then
    {
      format: "calendar",
      year: (. | to_int),
      month: null,
      day: null
    }
  # try YYYYMMDD (basic format)
  elif test("^[+-]?[0-9]{8}$") then
    (match("^([+-]?[0-9]{4})([0-9]{2})([0-9]{2})$")) as $m |
    {
      format: "calendar",
      year: ($m.captures[0].string | to_int),
      month: ($m.captures[1].string | to_int),
      day: ($m.captures[2].string | to_int)
    }
  else
    null
  end;

# parse ordinal date format
# precedence: YYYY-DDD → YYYYDDD
# returns: {format: "ordinal", year: int, ordinal_day: int} or null
def parse_ordinal_date:
  . as $date_str |
  
  # Try YYYY-DDD (extended format)
  if test("^[+-]?[0-9]{1,6}-[0-9]{3}$") then
    (match("^([+-]?[0-9]{1,6})-([0-9]{3})$")) as $m |
    {
      format: "ordinal",
      year: ($m.captures[0].string | to_int),
      ordinal_day: ($m.captures[1].string | to_int)
    }
  # Try YYYYDDD (basic format)
  elif test("^[+-]?[0-9]{7}$") then
    (match("^([+-]?[0-9]{4})([0-9]{3})$")) as $m |
    {
      format: "ordinal",
      year: ($m.captures[0].string | to_int),
      ordinal_day: ($m.captures[1].string | to_int)
    }
  else
    null
  end;

# parse week date format
# precedence: YYYY-Www-D → YYYYWwwD → YYYY-Www → YYYYWww
# returns: {format: "week", year: int, week: int, weekday: int|null} or null
def parse_week_date:
  . as $date_str |
  
  # Try YYYY-Www-D (extended format with weekday)
  if test("^[+-]?[0-9]{1,6}-W[0-9]{2}-[0-9]$") then
    (match("^([+-]?[0-9]{1,6})-W([0-9]{2})-([0-9])$")) as $m |
    {
      format: "week",
      year: ($m.captures[0].string | to_int),
      week: ($m.captures[1].string | to_int),
      weekday: ($m.captures[2].string | to_int)
    }
  # Try YYYYWwwD (basic format with weekday)
  elif test("^[+-]?[0-9]{4}W[0-9]{2}[0-9]$") then
    (match("^([+-]?[0-9]{4})W([0-9]{2})([0-9])$")) as $m |
    {
      format: "week",
      year: ($m.captures[0].string | to_int),
      week: ($m.captures[1].string | to_int),
      weekday: ($m.captures[2].string | to_int)
    }
  # Try YYYY-Www (extended format without weekday)
  elif test("^[+-]?[0-9]{1,6}-W[0-9]{2}$") then
    (match("^([+-]?[0-9]{1,6})-W([0-9]{2})$")) as $m |
    {
      format: "week",
      year: ($m.captures[0].string | to_int),
      week: ($m.captures[1].string | to_int),
      weekday: null
    }
  # Try YYYYWww (basic format without weekday)
  elif test("^[+-]?[0-9]{4}W[0-9]{2}$") then
    (match("^([+-]?[0-9]{4})W([0-9]{2})$")) as $m |
    {
      format: "week",
      year: ($m.captures[0].string | to_int),
      week: ($m.captures[1].string | to_int),
      weekday: null
    }
  else
    null
  end;

# detect and parse date format with precedence
# returns: {format: string, ...date_parts}
def detect_and_parse_date:
  . as $date_str |
  . as $original_input |
  
  # Try calendar date first (highest precedence)
  ($date_str | parse_calendar_date) as $calendar_result |
  if $calendar_result != null then
    $calendar_result
  else
    # Try ordinal date
    ($date_str | parse_ordinal_date) as $ordinal_result |
    if $ordinal_result != null then
      $ordinal_result
    else
      # Try week date
      ($date_str | parse_week_date) as $week_result |
      if $week_result != null then
        $week_result
      else
        # No valid date format found
        format_error("date format"; $date_str; $original_input) | throw_error(.)
      end
    end
  end;

# parse time component
# formats: hh, hh.hhh, hh:mm, hhmm, hh:mm.mmm, hhmm.mmm, hh:mm:ss, hhmmss, hh:mm:ss.sss, hhmmss.sss
# returns: {hour: int, minute: int|null, second: int|null, fractional: string|null, fractional_unit: string}
def parse_time_component:
  . as $time_str |
  . as $original_input |
  
  if $time_str == null or $time_str == "" then
    null
  # Try hh:mm:ss.sss (extended format with fractional seconds)
  elif test("^[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{1,9}$") then
    (match("^([0-9]{2}):([0-9]{2}):([0-9]{2})\\.([0-9]{1,9})$")) as $m |
    {
      hour: ($m.captures[0].string | to_int),
      minute: ($m.captures[1].string | to_int),
      second: ($m.captures[2].string | to_int),
      fractional: $m.captures[3].string,
      fractional_unit: "second"
    }
  # Try hhmmss.sss (basic format with fractional seconds)
  elif test("^[0-9]{6}\\.[0-9]{1,9}$") then
    (match("^([0-9]{2})([0-9]{2})([0-9]{2})\\.([0-9]{1,9})$")) as $m |
    {
      hour: ($m.captures[0].string | to_int),
      minute: ($m.captures[1].string | to_int),
      second: ($m.captures[2].string | to_int),
      fractional: $m.captures[3].string,
      fractional_unit: "second"
    }
  # Try hh:mm:ss (extended format)
  elif test("^[0-9]{2}:[0-9]{2}:[0-9]{2}$") then
    (match("^([0-9]{2}):([0-9]{2}):([0-9]{2})$")) as $m |
    {
      hour: ($m.captures[0].string | to_int),
      minute: ($m.captures[1].string | to_int),
      second: ($m.captures[2].string | to_int),
      fractional: null,
      fractional_unit: "second"
    }
  # Try hhmmss (basic format)
  elif test("^[0-9]{6}$") then
    (match("^([0-9]{2})([0-9]{2})([0-9]{2})$")) as $m |
    {
      hour: ($m.captures[0].string | to_int),
      minute: ($m.captures[1].string | to_int),
      second: ($m.captures[2].string | to_int),
      fractional: null,
      fractional_unit: "second"
    }
  # Try hh:mm.mmm (extended format with fractional minutes)
  elif test("^[0-9]{2}:[0-9]{2}\\.[0-9]{1,9}$") then
    (match("^([0-9]{2}):([0-9]{2})\\.([0-9]{1,9})$")) as $m |
    {
      hour: ($m.captures[0].string | to_int),
      minute: ($m.captures[1].string | to_int),
      second: null,
      fractional: $m.captures[2].string,
      fractional_unit: "minute"
    }
  # Try hhmm.mmm (basic format with fractional minutes)
  elif test("^[0-9]{4}\\.[0-9]{1,9}$") then
    (match("^([0-9]{2})([0-9]{2})\\.([0-9]{1,9})$")) as $m |
    {
      hour: ($m.captures[0].string | to_int),
      minute: ($m.captures[1].string | to_int),
      second: null,
      fractional: $m.captures[2].string,
      fractional_unit: "minute"
    }
  # Try hh:mm (extended format)
  elif test("^[0-9]{2}:[0-9]{2}$") then
    (match("^([0-9]{2}):([0-9]{2})$")) as $m |
    {
      hour: ($m.captures[0].string | to_int),
      minute: ($m.captures[1].string | to_int),
      second: null,
      fractional: null,
      fractional_unit: "minute"
    }
  # Try hhmm (basic format)
  elif test("^[0-9]{4}$") then
    (match("^([0-9]{2})([0-9]{2})$")) as $m |
    {
      hour: ($m.captures[0].string | to_int),
      minute: ($m.captures[1].string | to_int),
      second: null,
      fractional: null,
      fractional_unit: "minute"
    }
  # Try hh.hhh (fractional hours)
  elif test("^[0-9]{2}\\.[0-9]{1,9}$") then
    (match("^([0-9]{2})\\.([0-9]{1,9})$")) as $m |
    {
      hour: ($m.captures[0].string | to_int),
      minute: null,
      second: null,
      fractional: $m.captures[1].string,
      fractional_unit: "hour"
    }
  # Try hh (hour only)
  elif test("^[0-9]{2}$") then
    {
      hour: (. | to_int),
      minute: null,
      second: null,
      fractional: null,
      fractional_unit: "hour"
    }
  else
    # Invalid time format
    format_error("time format"; $time_str; $original_input) | throw_error(.)
  end;

# detect leap second (second == 60)
def detect_leap_second:
  if .time_parts != null and .time_parts.second != null and .time_parts.second == 60 then
    . + {has_leap_second: true}
  else
    .
  end;

# parse timezone offset component
# formats: Z, ±hh, ±hhmm, ±hh:mm, ±hh.hhhh
# returns: {indicator: "Z"|"offset", sign: "+"|"-"|null, offset_hours: int|null, offset_minutes: int|null, offset_fractional: string|null}
def parse_timezone_component:
  . as $tz_str |
  . as $original_input |
  
  if $tz_str == null or $tz_str == "" then
    null
  # Try Z (UTC)
  elif $tz_str == "Z" then
    {
      indicator: "Z",
      sign: null,
      offset_hours: null,
      offset_minutes: null,
      offset_fractional: null
    }
  # Try ±hh.hhhh (fractional hour offset)
  elif test("^[+-][0-9]{2}\\.[0-9]{1,4}$") then
    (match("^([+-])([0-9]{2})\\.([0-9]{1,4})$")) as $m |
    {
      indicator: "offset",
      sign: $m.captures[0].string,
      offset_hours: ($m.captures[1].string | to_int),
      offset_minutes: null,
      offset_fractional: $m.captures[2].string
    }
  # Try ±hh:mm (extended format)
  elif test("^[+-][0-9]{2}:[0-9]{2}$") then
    (match("^([+-])([0-9]{2}):([0-9]{2})$")) as $m |
    {
      indicator: "offset",
      sign: $m.captures[0].string,
      offset_hours: ($m.captures[1].string | to_int),
      offset_minutes: ($m.captures[2].string | to_int),
      offset_fractional: null
    }
  # Try ±hhmm (basic format)
  elif test("^[+-][0-9]{4}$") then
    (match("^([+-])([0-9]{2})([0-9]{2})$")) as $m |
    {
      indicator: "offset",
      sign: $m.captures[0].string,
      offset_hours: ($m.captures[1].string | to_int),
      offset_minutes: ($m.captures[2].string | to_int),
      offset_fractional: null
    }
  # Try ±hh (hour only)
  elif test("^[+-][0-9]{2}$") then
    (match("^([+-])([0-9]{2})$")) as $m |
    {
      indicator: "offset",
      sign: $m.captures[0].string,
      offset_hours: ($m.captures[1].string | to_int),
      offset_minutes: null,
      offset_fractional: null
    }
  else
    # Invalid timezone format
    format_error("timezone format"; $tz_str; $original_input) | throw_error(.)
  end;

# parse and classify input string
# returns object with parsed components
def classify_and_parse:
  . as $input |
  
  # Parse calendar system first
  parse_calendar_system as $cal_result |
  
  # Split date, time, and timezone components
  ($cal_result.remaining_input | split_datetime_components) as $components |
  
  # Parse date format
  ($components.date_part | detect_and_parse_date) as $date_result |
  
  # Parse time component
  ($components.time_part | parse_time_component) as $time_result |
  
  # Parse timezone component
  ($components.timezone_part | parse_timezone_component) as $tz_result |
  
  {
    original_input: $input,
    calendar_system: $cal_result.calendar_system,
    date_format: $date_result.format,
    date_parts: ($date_result | del(.format)),
    time_parts: $time_result,
    timezone: $tz_result,
    has_leap_second: false
  } | detect_leap_second;

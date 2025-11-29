# input validation module
# input validation and length checking

include "lib/core/error";
include "lib/core/utils";

# validate component length for year (max 7 digits including sign)
def validate_year_length($input):
  . as $year_str |
  ($year_str | length) as $len |
  if $len > MAX_YEAR_DIGITS then
    "Year component exceeds maximum length of \(MAX_YEAR_DIGITS) digits: '\($year_str)' in input '\($input)'" | throw_error(.)
  else
    .
  end;

# validate component length for fractional seconds (max 9 digits)
def validate_fractional_seconds_length($input):
  . as $frac_str |
  ($frac_str | length) as $len |
  if $len > MAX_FRACTIONAL_SECONDS_DIGITS then
    "Fractional seconds component exceeds maximum length of \(MAX_FRACTIONAL_SECONDS_DIGITS) digits: '\($frac_str)' in input '\($input)'" | throw_error(.)
  else
    .
  end;

# validate component length for fractional timezone (max 4 digits)
def validate_fractional_timezone_length($input):
  . as $frac_str |
  ($frac_str | length) as $len |
  if $len > MAX_FRACTIONAL_TIMEZONE_DIGITS then
    "Fractional timezone component exceeds maximum length of \(MAX_FRACTIONAL_TIMEZONE_DIGITS) digits: '\($frac_str)' in input '\($input)'" | throw_error(.)
  else
    .
  end;

# validate component length for calendar indicator (max 20 characters)
def validate_calendar_indicator_length($input):
  . as $cal_str |
  ($cal_str | length) as $len |
  if $len > MAX_CALENDAR_INDICATOR_LENGTH then
    "Calendar indicator exceeds maximum length of \(MAX_CALENDAR_INDICATOR_LENGTH) characters: '\($cal_str)' in input '\($input)'" | throw_error(.)
  else
    .
  end;

# extract and validate year component length
def check_year_component_length:
  . as $input |
  # match year patterns: calendar (YYYY-MM-DD, YYYY-MM, YYYY, YYYYMMDD), ordinal (YYYY-DDD, YYYYDDD), week (YYYY-Www-D, YYYYWwwD)
  # also handle calendar system prefix (e.g., "gregorian:YYYY-MM-DD")
  
  # first, strip calendar system prefix if present
  (if test("^[a-z]+:") then
    (match("^([a-z]+):(.+)$") | .captures[0].string) as $cal_system |
    $cal_system | validate_calendar_indicator_length($input) |
    $input | sub("^[a-z]+:"; "")
  else
    $input
  end) as $date_part |
  
  # extract year from various ISO-8601 date formats
  # only check if it looks like a valid ISO-8601 date format
  if $date_part | test("^[+-]?[0-9]+[-W]") then
    # has date separator, extract year before separator
    ($date_part | match("^([+-]?[0-9]+)[-W]") | .captures[0].string) as $year |
    $year | validate_year_length($input)
  elif $date_part | test("^[+-]?[0-9]+T") then
    # has time separator, extract year before T
    ($date_part | match("^([+-]?[0-9]+)T") | .captures[0].string) as $year |
    $year | validate_year_length($input)
  elif $date_part | test("^[+-]?[0-9]+[Z+-]") then
    # has timezone, extract year before timezone
    ($date_part | match("^([+-]?[0-9]+)[Z+-]") | .captures[0].string) as $year |
    $year | validate_year_length($input)
  elif $date_part | test("^[+-]?[0-9]+$") then
    # just a year or compact format (YYYYMMDD, YYYYDDD, YYYYWww, YYYYWwwD)
    # for compact formats, year is first 4-7 digits
    if ($date_part | length) <= 7 then
      # could be just a year
      $date_part | validate_year_length($input)
    elif ($date_part | length) == 8 then
      # YYYYMMDD format - year is first 4 digits
      ($date_part[0:4]) | validate_year_length($input)
    elif ($date_part | length) == 7 then
      # YYYYDDD or YYYYWww format - year is first 4 digits
      ($date_part[0:4]) | validate_year_length($input)
    else
      # longer than expected, extract first part as year
      ($date_part | match("^([+-]?[0-9]{1,7})") | .captures[0].string) as $year |
      $year | validate_year_length($input)
    end
  else
    .
  end |
  $input;

# extract and validate fractional seconds component length
def check_fractional_seconds_length:
  . as $input |
  # match fractional seconds pattern: .sss after time component
  if test("T[0-9]{2}(:[0-9]{2})?(:[0-9]{2})?\\.[0-9]+") then
    ($input | match("T[0-9]{2}(:[0-9]{2})?(:[0-9]{2})?\\.([0-9]+)") | .captures[2].string) as $frac |
    $frac | validate_fractional_seconds_length($input)
  # also check fractional minutes: .mmm after minutes
  elif test("T[0-9]{2}:[0-9]{2}\\.[0-9]+") then
    ($input | match("T[0-9]{2}:[0-9]{2}\\.([0-9]+)") | .captures[0].string) as $frac |
    $frac | validate_fractional_seconds_length($input)
  # also check fractional hours: .hhh after hours
  elif test("T[0-9]{2}\\.[0-9]+") then
    ($input | match("T[0-9]{2}\\.([0-9]+)") | .captures[0].string) as $frac |
    $frac | validate_fractional_seconds_length($input)
  else
    .
  end |
  $input;

# extract and validate fractional timezone component length
def check_fractional_timezone_length:
  . as $input |
  # match fractional timezone pattern: ±hh.hhhh
  if test("[+-][0-9]{2}\\.[0-9]+$") then
    ($input | match("[+-][0-9]{2}\\.([0-9]+)$") | .captures[0].string) as $frac |
    $frac | validate_fractional_timezone_length($input)
  else
    .
  end |
  $input;

# validate input length constraints
# this is the main validation function called first in the pipeline
def validate_input_length:
  . as $input |
  
  # first check: total input length
  if ($input | length) > MAX_INPUT_LENGTH then
    format_length_error($input) | throw_error(.)
  else
    $input
  end |
  
  # second check: component lengths
  check_year_component_length |
  check_fractional_seconds_length |
  check_fractional_timezone_length |
  
  # return original input if all validations pass
  $input;

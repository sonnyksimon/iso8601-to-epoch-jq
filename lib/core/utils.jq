# core utility functions
# string manipulation, math helpers, and common operations

# string utilities

# check if string matches pattern
def matches_pattern(pattern):
  test(pattern);

# extract matched groups from regex
def extract_groups(pattern):
  match(pattern) | .captures | map(.string);

# truncate string to specified length
def truncate_string(max_length):
  if length > max_length then
    .[0:max_length]
  else
    .
  end;

# math utilities

# absolute value
def abs:
  if . < 0 then -. else . end;

# floor function (truncate to integer)
def floor:
  if . >= 0 then
    . | trunc
  else
    (. | trunc) - (if . != (. | trunc) then 1 else 0 end)
  end;

# truncate to specified decimal places (no rounding)
def truncate_decimal(places):
  if places == 0 then
    floor
  else
    . * (pow(10; places)) | floor | . / pow(10; places)
  end;

# modulo operation (handles negative numbers correctly)
def mod(n):
  . - (n * ((. / n) | floor));

# check if number is integer
def is_integer:
  . == (. | floor);

# convert string to integer
def to_int:
  tonumber | floor;

# convert string to float
def to_float:
  tonumber;

# power function (for integer exponents)
def pow(n):
  if n == 0 then 1
  elif n == 1 then .
  elif n < 0 then 1 / (. | pow(-n))
  else
    . as $base |
    reduce range(1; n) as $i (
      $base;
      . * $base
    )
  end;

# array utilities

# check if array contains element
def contains_element(elem):
  any(.[]; . == elem);

# sum array elements
def sum_array:
  reduce .[] as $item (0; . + $item);

# date/time utilities

# days in each month (non-leap year)
def days_in_month_array:
  [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

# check if year is leap year (handles negative years for BCE)
def is_leap_year(year):
  if year >= 0 then
    ((year | mod(4)) == 0 and (year | mod(100)) != 0) or ((year | mod(400)) == 0)
  else
    # for negative years (BCE), check if the absolute value is a leap year
    # BUT with special handling: year -N is leap if (N-1) is divisible by 4
    # this accounts for astronomical year numbering where year -1 = year 0 (astronomical)
    # year -1 = 1 BCE = year 0 (astro) → leap
    # year -4 = 4 BCE = year -3 (astro), but we want 4 BCE to be leap
    # year -5 = 5 BCE = year -4 (astro) → leap
    # 
    # simpler rule: year -N is leap if (N-1) % 4 == 0 and standard leap year rules
    (year | abs) as $n |
    (($n - 1) as $adjusted |
    (($adjusted | mod(4)) == 0 and ($adjusted | mod(100)) != 0) or (($adjusted | mod(400)) == 0))
  end;

# Get days in specific month for given year
def days_in_month(year; month):
  if month == 2 then
    if is_leap_year(year) then 29 else 28 end
  elif [1, 3, 5, 7, 8, 10, 12] | contains_element(month) then
    31
  else
    30
  end;

# Validation utilities

# Check if string is numeric
def is_numeric:
  test("^[+-]?[0-9]+$");

# Check if string is numeric with optional decimal
def is_numeric_decimal:
  test("^[+-]?[0-9]+(\\.[0-9]+)?$");

# Validate range (inclusive)
def in_range(min; max):
  . >= min and . <= max;

# Constants

# Seconds per day
def SECONDS_PER_DAY:
  86400;

# Unix epoch reference date (1970-01-01)
def EPOCH_YEAR:
  1970;

def EPOCH_MONTH:
  1;

def EPOCH_DAY:
  1;

# Supported year range
def MIN_YEAR:
  -999999;

def MAX_YEAR:
  999999;

# Maximum input length
def MAX_INPUT_LENGTH:
  100;

# Maximum component lengths
def MAX_YEAR_DIGITS:
  7;  # Including sign

def MAX_FRACTIONAL_SECONDS_DIGITS:
  9;

def MAX_FRACTIONAL_TIMEZONE_DIGITS:
  4;

def MAX_CALENDAR_INDICATOR_LENGTH:
  20;

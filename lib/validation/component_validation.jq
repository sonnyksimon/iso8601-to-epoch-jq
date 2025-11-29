# component validation module
# validates date, time, and timezone component values

include "lib/core/error";
include "lib/core/utils";

# validate year is within supported range (-999999 to +999999)
def validate_year_range($year; $input):
  if $year < MIN_YEAR or $year > MAX_YEAR then
    format_year_range_error($year; $input) | throw_error(.)
  else
    .
  end;

# validate month is in range 01-12
def validate_month($month; $input):
  if $month < 1 or $month > 12 then
    format_error("month"; $month | tostring; $input) | throw_error(.)
  else
    .
  end;

# validate day is valid for given month and year
def validate_day($year; $month; $day; $input):
  days_in_month($year; $month) as $max_days |
  if $day < 1 or $day > $max_days then
    format_error("day"; $day | tostring; $input) | throw_error(.)
  else
    .
  end;

# validate calendar date (year, month, day)
def validate_calendar_date($year; $month; $day; $input):
  . | validate_year_range($year; $input) |
  validate_month($month; $input) |
  validate_day($year; $month; $day; $input);

# validate ordinal day for given year
def validate_ordinal_day($year; $ordinal_day; $input):
  (if is_leap_year($year) then 366 else 365 end) as $max_day |
  if $ordinal_day < 1 or $ordinal_day > $max_day then
    format_error("ordinal day"; $ordinal_day | tostring; $input) | throw_error(.)
  else
    .
  end;

# validate ordinal date (year and ordinal day)
def validate_ordinal_date($year; $ordinal_day; $input):
  . | validate_year_range($year; $input) |
  validate_ordinal_day($year; $ordinal_day; $input);

# check if year has 53 ISO weeks
# years have 53 weeks if:
# - January 1 falls on Thursday, OR
# - it's a leap year AND January 1 falls on Wednesday
def year_has_53_weeks($year):
  # calculate day of week for January 1 of the year
  # using Zeller's congruence or similar algorithm
  # for now, use a simplified check based on ISO week rules
  
  # ISO week 1 is the week containing the first Thursday
  # a year has 53 weeks if December 31 is in week 53
  # this happens when Jan 1 is Thursday (day 4) or
  # when it's a leap year and Jan 1 is Wednesday (day 3)
  
  # calculate day of week for Jan 1 using Sakamoto's algorithm
  ($year - (if 1 < 3 then 1 else 0 end)) as $y |
  ([0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4][0]) as $t |
  (($y + ($y / 4 | floor) - ($y / 100 | floor) + ($y / 400 | floor) + $t + 1) | mod(7)) as $dow |
  
  # Monday = 1, Sunday = 0 in this calculation
  # convert to ISO: Monday = 1, Sunday = 7
  (if $dow == 0 then 7 else $dow end) as $iso_dow |
  
  # year has 53 weeks if Jan 1 is Thursday (4) or
  # if it's a leap year and Jan 1 is Wednesday (3)
  ($iso_dow == 4) or (is_leap_year($year) and $iso_dow == 3);

# validate week number for given year
def validate_week_number($year; $week; $input):
  (if year_has_53_weeks($year) then 53 else 52 end) as $max_week |
  if $week < 1 or $week > $max_week then
    format_error("week number"; $week | tostring; $input) | throw_error(.)
  else
    .
  end;

# validate weekday (1-7, Monday to Sunday)
def validate_weekday($weekday; $input):
  if $weekday < 1 or $weekday > 7 then
    format_error("weekday"; $weekday | tostring; $input) | throw_error(.)
  else
    .
  end;

# validate week date (year, week, weekday)
def validate_week_date($year; $week; $weekday; $input):
  . | validate_year_range($year; $input) |
  validate_week_number($year; $week; $input) |
  validate_weekday($weekday; $input);

# validate hour (00-23)
def validate_hour($hour; $input):
  if $hour < 0 or $hour > 23 then
    format_error("hour"; $hour | tostring; $input) | throw_error(.)
  else
    .
  end;

# validate minute (00-59)
def validate_minute($minute; $input):
  if $minute < 0 or $minute > 59 then
    format_error("minute"; $minute | tostring; $input) | throw_error(.)
  else
    .
  end;

# validate second (00-60, allowing leap seconds)
def validate_second($second; $input):
  if $second < 0 or $second > 60 then
    format_error("second"; $second | tostring; $input) | throw_error(.)
  else
    .
  end;

# validate time components (hour, minute, second)
def validate_time($hour; $minute; $second; $input):
  . | validate_hour($hour; $input) |
  validate_minute($minute; $input) |
  validate_second($second; $input);

# validate timezone offset is within ±24 hours
# offset is in seconds
def validate_timezone_offset($offset_seconds; $input):
  ($offset_seconds | abs) as $abs_offset |
  # ±24 hours = ±86400 seconds
  if $abs_offset >= SECONDS_PER_DAY then
    # format offset back to hours for error message
    ($offset_seconds / 3600) as $offset_hours |
    (if $offset_hours >= 0 then "+" else "" end) as $sign |
    format_error("timezone offset"; "\($sign)\($offset_hours | floor)"; $input) | throw_error(.)
  else
    .
  end;

# date normalizer module
# date normalization to gregorian calendar date

include "lib/core/error";
include "lib/core/utils";

# validate year range (-999999 to +999999)
def validate_year_range:
  .date_parts.year as $year |
  .original_input as $input |
  
  if $year < MIN_YEAR or $year > MAX_YEAR then
    format_year_range_error($year; $input) | throw_error(.)
  else
    .
  end;

# normalize calendar date (YYYY-MM-DD format)
# handles incomplete dates: year-only → jan 1, year-month → day 1
# validates month (01-12) and day ranges
def normalize_calendar_date:
  .date_parts as $parts |
  .original_input as $input |
  
  # extract components with defaults
  $parts.year as $year |
  ($parts.month // 1) as $month |
  ($parts.day // 1) as $day |
  
  # validate month range (01-12)
  if $month < 1 or $month > 12 then
    format_error("month"; ($month | tostring); $input) | throw_error(.)
  else
    # validate day range based on month and leap year
    (days_in_month($year; $month)) as $max_day |
    if $day < 1 or $day > $max_day then
      format_error("day"; ($day | tostring); $input) | throw_error(.)
    else
      # return normalized date
      . + {
        normalized_date: {
          year: $year,
          month: $month,
          day: $day
        }
      }
    end
  end;

# convert ordinal date (YYYY-DDD) to calendar date (YYYY-MM-DD)
# validates ordinal day range (001-365 or 001-366 for leap years)
def ordinal_to_calendar:
  .date_parts as $parts |
  .original_input as $input |
  
  $parts.year as $year |
  $parts.ordinal_day as $ordinal_day |
  
  # validate ordinal day range
  (if is_leap_year($year) then 366 else 365 end) as $max_ordinal |
  
  if $ordinal_day < 1 or $ordinal_day > $max_ordinal then
    format_error("ordinal day"; ($ordinal_day | tostring); $input) | throw_error(.)
  else
    # convert ordinal day to month and day
    # accumulate days per month until we reach the ordinal day
    (days_in_month_array) as $days_per_month |
    
    # adjust february for leap year
    (if is_leap_year($year) then
      $days_per_month | .[1] = 29
    else
      $days_per_month
    end) as $adjusted_days |
    
    # find the month and day
    ($ordinal_day) as $remaining_days |
    
    # iterate through months to find the target month
    (reduce range(0; 12) as $month_idx (
      {remaining: $remaining_days, month: 0, day: 0, found: false};
      if .found then
        .
      else
        ($adjusted_days[$month_idx]) as $days_in_this_month |
        if .remaining <= $days_in_this_month then
          {
            remaining: .remaining,
            month: ($month_idx + 1),
            day: .remaining,
            found: true
          }
        else
          {
            remaining: (.remaining - $days_in_this_month),
            month: .month,
            day: .day,
            found: false
          }
        end
      end
    )) as $result |
    
    # return normalized date
    . + {
      normalized_date: {
        year: $year,
        month: $result.month,
        day: $result.day
      }
    }
  end;

# helper: calculate day of week for a given date (monday=1, sunday=7)
# uses zeller's congruence algorithm adapted for ISO week dates
def day_of_week(year; month; day):
  # adjust for zeller's congruence (january and february are months 13 and 14 of previous year)
  (if month < 3 then
    {y: (year - 1), m: (month + 12)}
  else
    {y: year, m: month}
  end) as $adjusted |
  
  $adjusted.y as $y |
  $adjusted.m as $m |
  
  # zeller's congruence formula
  # h = (q + floor(13*(m+1)/5) + K + floor(K/4) + floor(J/4) - 2*J) mod 7
  # where q = day, m = month, K = year % 100, J = year / 100
  
  ($y | mod(100)) as $K |
  (($y / 100) | floor) as $J |
  
  (day + ((13 * ($m + 1) / 5) | floor) + $K + (($K / 4) | floor) + (($J / 4) | floor) - (2 * $J)) as $h |
  
  # convert zeller's result (0=saturday) to ISO (1=monday, 7=sunday)
  (($h | mod(7)) + 6) | mod(7) | if . == 0 then 7 else . end;

# helper: add days to a date
def add_days_to_date(year; month; day; days_to_add):
  if days_to_add == 0 then
    {year: year, month: month, day: day}
  elif days_to_add > 0 then
    # add days forward
    (days_in_month(year; month)) as $days_in_current_month |
    
    if day + days_to_add <= $days_in_current_month then
      # stays in same month
      {year: year, month: month, day: (day + days_to_add)}
    else
      # move to next month
      (days_to_add - ($days_in_current_month - day + 1)) as $remaining_days |
      (if month == 12 then
        {year: (year + 1), month: 1}
      else
        {year: year, month: (month + 1)}
      end) as $next_month |
      
      add_days_to_date($next_month.year; $next_month.month; 1; $remaining_days)
    end
  else
    # subtract days backward
    (days_to_add | abs) as $days_to_subtract |
    
    if day > $days_to_subtract then
      # stays in same month
      {year: year, month: month, day: (day - $days_to_subtract)}
    else
      # move to previous month
      (if month == 1 then
        {year: (year - 1), month: 12}
      else
        {year: year, month: (month - 1)}
      end) as $prev_month |
      
      (days_in_month($prev_month.year; $prev_month.month)) as $days_in_prev_month |
      ($days_to_subtract - day) as $remaining_days |
      
      add_days_to_date($prev_month.year; $prev_month.month; $days_in_prev_month; -$remaining_days)
    end
  end;

# helper: check if year has 53 ISO weeks
# a year has 53 weeks if:
# - january 1 falls on thursday, OR
# - it's a leap year and january 1 falls on wednesday
def has_53_weeks(year):
  (day_of_week(year; 1; 1)) as $jan1_dow |
  
  ($jan1_dow == 4) or (is_leap_year(year) and $jan1_dow == 3);

# convert ISO week date to calendar date (YYYY-MM-DD)
# ISO week 1 is the first week containing the first thursday
def week_to_calendar:
  .date_parts as $parts |
  .original_input as $input |
  
  $parts.year as $year |
  $parts.week as $week |
  ($parts.weekday // 1) as $weekday |
  
  # validate week number (01-53)
  if $week < 1 or $week > 53 then
    format_error("week"; ($week | tostring); $input) | throw_error(.)
  else
    # check if week 53 is valid for this year
    if $week == 53 and (has_53_weeks($year) | not) then
      format_error("week"; ($week | tostring); $input) | throw_error(.)
    else
      # validate weekday (1-7)
      if $weekday < 1 or $weekday > 7 then
        format_error("weekday"; ($weekday | tostring); $input) | throw_error(.)
      else
        # calculate the date
        # ISO week 1 contains the first thursday of the year
        # find january 4 (always in week 1)
        (day_of_week($year; 1; 4)) as $jan4_dow |
        
        # find the monday of week 1 (go back from jan 4)
        (add_days_to_date($year; 1; 4; -(($jan4_dow - 1)))) as $week1_monday |
        
        # add weeks and weekdays
        (($week - 1) * 7 + ($weekday - 1)) as $days_to_add |
        
        (add_days_to_date($week1_monday.year; $week1_monday.month; $week1_monday.day; $days_to_add)) as $target_date |
        
        # return normalized date
        . + {
          normalized_date: {
            year: $target_date.year,
            month: $target_date.month,
            day: $target_date.day
          }
        }
      end
    end
  end;

# normalize date to calendar format (YYYY-MM-DD)
def normalize_date:
  # validation order 15:
  # 1. year range (done here)
  # 2. component ranges (done in format-specific functions)
  # 3. leap year rules (done in format-specific functions)
  # 4. ISO week rules (done in week_to_calendar)
  
  # first validate year range
  validate_year_range |
  
  # then normalize based on date format
  if .date_format == "calendar" then
    normalize_calendar_date
  elif .date_format == "ordinal" then
    ordinal_to_calendar
  elif .date_format == "week" then
    week_to_calendar
  else
    # unknown format - should not happen if parser is correct
    .original_input as $input |
    format_error("date format"; .date_format; $input) | throw_error(.)
  end;

# epoch calculator module
# unix epoch computation

include "lib/core/error";
include "lib/core/utils";
include "lib/normalization/date_normalizer";

# helper function to count leap years from year 1 to year N
# uses mathematical formula for efficiency
def count_leap_years_from_1($n):
  if $n >= 1 then
    (($n / 4) | floor) - (($n / 100) | floor) + (($n / 400) | floor)
  elif $n == 0 then
    0
  else
    # for negative years, count backwards from year -1
    ($n | abs) as $abs_n |
    # year -1 to year -N: count leap years in this range
    # year -1 is leap, -5 is leap, etc.
    ((($abs_n + 3) / 4) | floor) - ((($abs_n + 99) / 100) | floor) + ((($abs_n + 399) / 400) | floor)
  end;

# count leap years in range [from_year, to_year)
# handles negative years correctly
# note: there is no year 0 in ISO 8601
# optimized using mathematical formula instead of iteration
def count_leap_years($from_year; $to_year):
  if $from_year >= $to_year then
    0
  else
    # optimized: use mathematical formula to count leap years
    # leap years: divisible by 4, except centuries not divisible by 400
    # formula: (years/4) - (years/100) + (years/400)
    
    # adjust for year 0 not existing
    ($from_year) as $start |
    ($to_year - 1) as $end |
    
    # count leap years in range
    if $start >= 1 and $end >= 1 then
      # both positive: simple subtraction
      count_leap_years_from_1($end) - count_leap_years_from_1($start - 1)
    elif $start <= -1 and $end <= -1 then
      # both negative: count in negative range
      count_leap_years_from_1($start) - count_leap_years_from_1($end + 1)
    else
      # range spans year 0 (which doesn't exist)
      # count from start to -1, then from 1 to end
      (if $start <= -1 then count_leap_years_from_1($start) - count_leap_years_from_1(0) else 0 end) +
      (if $end >= 1 then count_leap_years_from_1($end) - count_leap_years_from_1(0) else 0 end)
    end
  end;

# calculate days from 1970-01-01 to target date
# handles positive years (≥1970) and negative years (<1970)
# handles BCE dates correctly
# optimized to reduce redundant calculations
def days_since_epoch($year; $month; $day):
  # epoch reference: 1970-01-01
  EPOCH_YEAR as $epoch_year |
  
  # pre-calculate month days once
  (if is_leap_year($year) then
    [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  else
    [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  end) as $days_per_month |
  
  # calculate days for complete months (optimized)
  (if $month == 1 then 0
   elif $month == 2 then 31
   elif $month == 3 then ($days_per_month[0] + $days_per_month[1])
   elif $month == 4 then ($days_per_month[0] + $days_per_month[1] + $days_per_month[2])
   elif $month == 5 then ($days_per_month[0] + $days_per_month[1] + $days_per_month[2] + $days_per_month[3])
   elif $month == 6 then ($days_per_month[0] + $days_per_month[1] + $days_per_month[2] + $days_per_month[3] + $days_per_month[4])
   elif $month == 7 then ($days_per_month[0] + $days_per_month[1] + $days_per_month[2] + $days_per_month[3] + $days_per_month[4] + $days_per_month[5])
   elif $month == 8 then ($days_per_month[0] + $days_per_month[1] + $days_per_month[2] + $days_per_month[3] + $days_per_month[4] + $days_per_month[5] + $days_per_month[6])
   elif $month == 9 then ($days_per_month[0] + $days_per_month[1] + $days_per_month[2] + $days_per_month[3] + $days_per_month[4] + $days_per_month[5] + $days_per_month[6] + $days_per_month[7])
   elif $month == 10 then ($days_per_month[0] + $days_per_month[1] + $days_per_month[2] + $days_per_month[3] + $days_per_month[4] + $days_per_month[5] + $days_per_month[6] + $days_per_month[7] + $days_per_month[8])
   elif $month == 11 then ($days_per_month[0] + $days_per_month[1] + $days_per_month[2] + $days_per_month[3] + $days_per_month[4] + $days_per_month[5] + $days_per_month[6] + $days_per_month[7] + $days_per_month[8] + $days_per_month[9])
   else ($days_per_month[0] + $days_per_month[1] + $days_per_month[2] + $days_per_month[3] + $days_per_month[4] + $days_per_month[5] + $days_per_month[6] + $days_per_month[7] + $days_per_month[8] + $days_per_month[9] + $days_per_month[10])
   end) as $month_days |
  
  if $year >= $epoch_year then
    # forward calculation from 1970
    (($year - $epoch_year) * 365) as $year_days |
    (count_leap_years($epoch_year; $year)) as $leap_days |
    ($year_days + $leap_days + $month_days + $day - 1)
  elif $year >= 0 then
    # backward calculation for positive years < 1970
    (($year - $epoch_year) * 365) as $year_days |
    (count_leap_years($year; $epoch_year)) as $leap_days |
    ($year_days + $leap_days + $month_days + $day - 1)
  else
    # backward calculation for negative years (BCE)
    # days from year 1 to year 1970 (not including 1970)
    ((1970 - 1) * 365 + count_leap_years(1; 1970)) as $total_1_to_1970 |
    
    # days from target year to year 1 (not including year 1)
    ((1 - $year - 1) * 365 + count_leap_years($year; 1)) as $total_target_to_1 |
    
    # total days from target year to 1970
    (-$total_target_to_1 - $total_1_to_1970 + $month_days + $day - 1)
  end;

# handle leap second adjustment
# leap second 23:59:60 is treated as 00:00:00 of next day
# maintains fractional precision
def handle_leap_second:
  .has_leap_second as $has_leap |
  .time_seconds as $time_sec |
  
  if $has_leap then
    # if we have a leap second (second == 60), the time_seconds already includes it
    # we need to check if second was 60 and adjust
    # leap second 23:59:60 should be treated as next day 00:00:00
    # this means we need to add 1 day and reset time to 0 (plus any fractional part)
    
    # check if time is in the leap second range (>= 86400)
    if $time_sec >= SECONDS_PER_DAY then
      # extract fractional part if any
      ($time_sec - SECONDS_PER_DAY) as $fractional_part |
      
      # add one day to the date
      (add_days_to_date(.normalized_date.year; .normalized_date.month; .normalized_date.day; 1)) as $next_day |
      
      . + {
        normalized_date: $next_day,
        time_seconds: $fractional_part
      }
    else
      .
    end
  else
    .
  end;

# calculate final unix epoch
# converts days to seconds, adds time, subtracts offset
# returns integer if no fractional component, float otherwise
def compute_epoch:
  # first handle leap second if present
  handle_leap_second |
  
  .normalized_date as $date |
  .time_seconds as $time_sec |
  .has_fractional as $has_frac |
  
  # calculate days since epoch
  (days_since_epoch($date.year; $date.month; $date.day)) as $days |
  
  # convert days to seconds
  ($days * SECONDS_PER_DAY) as $day_seconds |
  
  # add time seconds (offset already applied in time normalization)
  ($day_seconds + $time_sec) as $total_seconds |
  
  # return integer if no fractional component, float otherwise
  if $has_frac then
    $total_seconds
  else
    $total_seconds | floor
  end;

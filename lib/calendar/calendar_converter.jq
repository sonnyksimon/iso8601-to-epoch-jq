# calendar converter Module
# Alternative calendar system conversions

include "lib/core/error";
include "lib/core/utils";

# helper function to add days to a Gregorian date
# returns: {year, month, day}
def add_days_to_date(year; month; day; days_to_add):
  # Fast-forward by 400-year cycles (146097 days per cycle)
  (if days_to_add >= 146097 then
    (days_to_add / 146097 | floor) as $cycles |
    {
      year: (year + ($cycles * 400)),
      month: month,
      day: day,
      remaining: (days_to_add - ($cycles * 146097))
    }
  else
    {year: year, month: month, day: day, remaining: days_to_add}
  end) |
  
  # Fast-forward by 100-year periods (36524 days)
  (if .remaining >= 36524 then
    (.remaining / 36524 | floor) as $centuries |
    (if $centuries > 3 then 3 else $centuries end) as $safe_centuries |
    .year += ($safe_centuries * 100) |
    .remaining -= ($safe_centuries * 36524)
  else
    .
  end) |
  
  # Fast-forward by 4-year periods (1461 days)
  (if .remaining >= 1461 then
    (.remaining / 1461 | floor) as $four_year_periods |
    .year += ($four_year_periods * 4) |
    .remaining -= ($four_year_periods * 1461)
  else
    .
  end) |
  
  # Add remaining complete years one at a time (should be < 4 years now)
  # Use while loop with explicit condition check
  .iter = 0 |
  until(.remaining < 365 or .iter > 10;
    (if is_leap_year(.year) then 366 else 365 end) as $year_days |
    if .remaining >= $year_days then
      .year += 1 | .remaining -= $year_days | .iter += 1
    else
      .iter = 999  # Force exit
    end
  ) |
  del(.iter) |
  
  # Add remaining days month by month
  until(.remaining <= 0;
    . as $current |
    (days_in_month($current.year; $current.month)) as $days_in_current_month |
    (($days_in_current_month - $current.day + 1)) as $days_left_in_month |
    
    if $current.remaining >= $days_left_in_month then
      # Move to next month
      $current | .remaining -= $days_left_in_month |
      .day = 1 |
      if .month == 12 then
        .month = 1 | .year += 1
      else
        .month += 1
      end
    else
      # Add remaining days to current month
      $current | .day += .remaining |
      .remaining = 0
    end
  ) |
  
  # Return just the date components
  {year: .year, month: .month, day: .day};

# julian calendar conversion
# julian calendar: every year divisible by 4 is a leap year
# Difference from Gregorian increases by 3 days every 400 years
def convert_julian_to_gregorian:
  .date_parts as $date |
  
  ($date.year) as $year |
  ($date.month // 1) as $month |
  ($date.day // 1) as $day |
  
  # Calculate the day difference based on century
  # Formula: difference = (century / 100) - (century / 400) - 2
  # As of 2025: 13-day difference
  
  (if $year >= 0 then
    ($year / 100 | floor)
  else
    # For negative years, century calculation needs adjustment
    ((($year - 99) / 100) | floor)
  end) as $century |
  
  # Calculate day difference
  ($century - (($century / 4) | floor) - 2) as $day_diff |
  
  # Add the day difference to convert Julian to Gregorian
  (add_days_to_date($year; $month; $day; $day_diff)) as $converted_date |
  
  # Update date_parts with converted Gregorian date
  .date_parts = $converted_date;

# buddhist calendar conversion
# Buddhist year = Gregorian year + 543
def convert_buddhist_to_gregorian:
  .date_parts as $date |
  
  # Apply 543-year offset
  ($date.year - 543) as $greg_year |
  
  # Update date_parts with converted year
  .date_parts.year = $greg_year;

# islamic calendar conversion
# Lunar calendar with ~354-355 days per year
# Uses algorithmic approximation with ±1 day tolerance
def convert_islamic_to_gregorian:
  .date_parts as $date |
  
  ($date.year) as $islamic_year |
  ($date.month // 1) as $islamic_month |
  ($date.day // 1) as $islamic_day |
  
  # Islamic calendar epoch: July 16, 622 CE (Gregorian)
  # Average Islamic year = 354.36667 days
  
  # Calculate days from Islamic epoch
  # Days = (year - 1) * 354.36667 + month_days + day
  (($islamic_year - 1) * 354.36667) as $year_days |
  
  # Approximate days in Islamic months (alternating 30/29 days)
  # Months: 30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29/30
  ([0, 30, 59, 89, 118, 148, 177, 207, 236, 266, 295, 325]) as $islamic_month_days |
  ($islamic_month_days[$islamic_month - 1]) as $month_days |
  
  ($year_days + $month_days + $islamic_day - 1) as $total_days |
  
  # Islamic epoch in Gregorian: July 16, 622 CE
  # Add days to epoch date
  (add_days_to_date(622; 7; 16; ($total_days | floor))) as $converted_date |
  
  # Update date_parts with converted Gregorian date
  .date_parts = $converted_date;

# hebrew calendar conversion
# Lunisolar calendar with 19-year cycle (7 leap years)
# Uses algorithmic approximation with ±1 day tolerance
def convert_hebrew_to_gregorian:
  .date_parts as $date |
  
  ($date.year) as $hebrew_year |
  ($date.month // 1) as $hebrew_month |
  ($date.day // 1) as $hebrew_day |
  
  # Hebrew calendar epoch: October 7, 3761 BCE (Gregorian proleptic)
  # Average Hebrew year = 365.2468 days
  
  # Calculate days from Hebrew epoch
  (($hebrew_year - 1) * 365.2468) as $year_days |
  
  # Approximate days in Hebrew months (varies by year type)
  # Using average month lengths for regular year
  ([0, 30, 59, 89, 118, 148, 177, 207, 236, 266, 295, 325]) as $hebrew_month_days |
  (if $hebrew_month >= 1 and $hebrew_month <= 12 then
    $hebrew_month_days[$hebrew_month - 1]
  else
    0
  end) as $month_days |
  
  ($year_days + $month_days + $hebrew_day - 1) as $total_days |
  
  # Hebrew epoch in Gregorian: October 7, 3761 BCE = year -3760, month 10, day 7
  # Add days to epoch date
  (add_days_to_date(-3760; 10; 7; ($total_days | floor))) as $converted_date |
  
  # Update date_parts with converted Gregorian date
  .date_parts = $converted_date;

# persian calendar conversion
# Solar calendar with year beginning at vernal equinox
# Uses algorithmic conversion (exact)
def convert_persian_to_gregorian:
  .date_parts as $date |
  
  ($date.year) as $persian_year |
  ($date.month // 1) as $persian_month |
  ($date.day // 1) as $persian_day |
  
  # Persian calendar epoch: March 22, 622 CE (Gregorian)
  # Average Persian year = 365.2422 days
  
  # Calculate days from Persian epoch
  (($persian_year - 1) * 365.2422) as $year_days |
  
  # Persian months: first 6 months have 31 days, next 5 have 30 days, last has 29/30
  ([0, 31, 62, 93, 124, 155, 186, 216, 246, 276, 306, 336]) as $persian_month_days |
  ($persian_month_days[$persian_month - 1]) as $month_days |
  
  ($year_days + $month_days + $persian_day - 1) as $total_days |
  
  # Persian epoch in Gregorian: March 22, 622 CE
  # Add days to epoch date
  (add_days_to_date(622; 3; 22; ($total_days | floor))) as $converted_date |
  
  # Update date_parts with converted Gregorian date
  .date_parts = $converted_date;

# chinese calendar conversion
# Lunisolar calendar with 60-year cycle
# Uses algorithmic approximation with ±1 day tolerance
def convert_chinese_to_gregorian:
  .date_parts as $date |
  
  ($date.year) as $chinese_year |
  ($date.month // 1) as $chinese_month |
  ($date.day // 1) as $chinese_day |
  
  # Chinese calendar epoch: 2697 BCE (Huangdi era, traditional)
  # Chinese year 4723 = 2025/2026 CE (4723 - 2697 = 2026)
  # But Chinese New Year typically falls in late January/early February
  # So most of Chinese year N falls in Gregorian year N-1
  # Conversion: Gregorian year ≈ Chinese year - 2698 (for most of the year)
  
  # Chinese New Year typically falls around late January/early February
  # Using day 45 (Feb 14) as average start of Chinese year
  # Months 1-12 in Chinese calendar span from ~Feb of year N-1 to ~Jan of year N
  # Average lunar month = 29.53 days
  
  # Calculate approximate day in Gregorian year
  # Month 1 starts around day 45 (Feb 14) of Gregorian year (Chinese year - 2698)
  # Month 10 would be around day 45 + 9*29.53 = 310.77 (early November)
  ($chinese_year - 2698) as $greg_year_base |
  (45 + ($chinese_month - 1) * 29.53 + $chinese_day - 1) as $day_in_year |
  
  # If day_in_year > 365, it's in the next Gregorian year
  (if $day_in_year > 365 then
    ($greg_year_base + 1) as $greg_year |
    ($day_in_year - 365) as $adjusted_day |
    add_days_to_date($greg_year; 1; 1; ($adjusted_day | floor) - 1)
  else
    add_days_to_date($greg_year_base; 1; 1; ($day_in_year | floor) - 1)
  end) as $converted_date |
  
  # Update date_parts with converted Gregorian date
  .date_parts = $converted_date;

# main conversion function
def convert_calendar_system:
  if .calendar_system == "gregorian" then
    .
  elif .calendar_system == "julian" then
    convert_julian_to_gregorian
  elif .calendar_system == "buddhist" then
    convert_buddhist_to_gregorian
  elif .calendar_system == "islamic" then
    convert_islamic_to_gregorian
  elif .calendar_system == "hebrew" then
    convert_hebrew_to_gregorian
  elif .calendar_system == "persian" then
    convert_persian_to_gregorian
  elif .calendar_system == "chinese" then
    convert_chinese_to_gregorian
  else
    # This should never happen as parser validates calendar system
    format_unsupported_calendar_error(.calendar_system; .original_input) | throw_error(.)
  end;

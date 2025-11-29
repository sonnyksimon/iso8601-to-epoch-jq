# time normalizer module
# time and timezone normalization

include "lib/core/error";
include "lib/core/utils";
include "lib/normalization/date_normalizer";

# validate time component ranges
# hour (00-23), minute (00-59), second (00-60 for leap seconds)
def validate_time_components:
  .time_parts as $time |
  .original_input as $input |
  
  if $time == null then
    .
  else
    # validate hour (00-23)
    if $time.hour < 0 or $time.hour > 23 then
      format_error("hour"; ($time.hour | tostring); $input) | throw_error(.)
    else
      # validate minute (00-59) if present
      if $time.minute != null and ($time.minute < 0 or $time.minute > 59) then
        format_error("minute"; ($time.minute | tostring); $input) | throw_error(.)
      else
        # validate second (00-60, allowing leap seconds) if present
        if $time.second != null and ($time.second < 0 or $time.second > 60) then
          format_error("second"; ($time.second | tostring); $input) | throw_error(.)
        else
          .
        end
      end
    end
  end;

# normalize time components to total seconds since midnight
# handles fractional hours, minutes, and seconds
# truncates to 9 digits of fractional precision
def normalize_time:
  .time_parts as $time |
  
  if $time == null then
    # no time component - default to 00:00:00
    . + {
      time_seconds: 0,
      has_fractional: false
    }
  else
    # convert time components to seconds
    ($time.hour * 3600) as $hour_seconds |
    (($time.minute // 0) * 60) as $minute_seconds |
    ($time.second // 0) as $second_seconds |
    
    # handle fractional component based on unit
    if $time.fractional != null then
      # convert fractional string to decimal number
      ("0." + $time.fractional | to_float) as $frac_value |
      
      if $time.fractional_unit == "hour" then
        # fractional hours: convert to seconds and truncate to 9 digits
        ($frac_value * 3600 | truncate_decimal(9)) as $frac_seconds |
        ($hour_seconds + $frac_seconds) as $total_seconds |
        
        . + {
          time_seconds: $total_seconds,
          has_fractional: ($frac_seconds != ($frac_seconds | floor))
        }
      elif $time.fractional_unit == "minute" then
        # fractional minutes: convert to seconds and truncate to 9 digits
        ($frac_value * 60 | truncate_decimal(9)) as $frac_seconds |
        ($hour_seconds + $minute_seconds + $frac_seconds) as $total_seconds |
        
        . + {
          time_seconds: $total_seconds,
          has_fractional: ($frac_seconds != ($frac_seconds | floor))
        }
      else  # fractional_unit == "second"
        # fractional seconds: preserve up to 9 digits, truncate beyond
        # truncate fractional string to 9 digits if longer
        ($time.fractional | if length > 9 then .[0:9] else . end) as $truncated_frac |
        ("0." + $truncated_frac | to_float) as $frac_seconds |
        ($hour_seconds + $minute_seconds + $second_seconds + $frac_seconds) as $total_seconds |
        
        . + {
          time_seconds: $total_seconds,
          has_fractional: true
        }
      end
    else
      # no fractional component
      ($hour_seconds + $minute_seconds + $second_seconds) as $total_seconds |
      
      . + {
        time_seconds: $total_seconds,
        has_fractional: false
      }
    end
  end;

# validate timezone offset
# offset must be < ±24 hours
def validate_timezone_offset:
  .timezone as $tz |
  .original_input as $input |
  
  if $tz == null or $tz.indicator == "Z" then
    .
  else
    # calculate total offset in hours
    ($tz.offset_hours) as $hours |
    (($tz.offset_minutes // 0) / 60.0) as $minutes_as_hours |
    
    # handle fractional offset
    (if $tz.offset_fractional != null then
      ("0." + $tz.offset_fractional | to_float)
    else
      0
    end) as $frac_hours |
    
    ($hours + $minutes_as_hours + $frac_hours) as $total_hours |
    
    # validate offset < ±24 hours
    if $total_hours >= 24 then
      format_error("timezone offset"; ($tz.sign + ($hours | tostring) + (if $tz.offset_minutes != null then ":" + ($tz.offset_minutes | tostring) else "" end) + (if $tz.offset_fractional != null then "." + $tz.offset_fractional else "" end)); $input) | throw_error(.)
    else
      .
    end
  end;

# normalize timezone offset to seconds
# converts Z, ±hh, ±hhmm, ±hh:mm, ±hh.hhhh to offset in seconds
# default to 0 (UTC) if no timezone specified
def normalize_timezone:
  .timezone as $tz |
  
  if $tz == null then
    # no timezone specified - default to UTC (0 offset)
    . + {
      offset_seconds: 0
    }
  elif $tz.indicator == "Z" then
    # Z indicator - UTC (0 offset)
    . + {
      offset_seconds: 0
    }
  else
    # numeric offset
    ($tz.offset_hours * 3600) as $hour_seconds |
    (($tz.offset_minutes // 0) * 60) as $minute_seconds |
    
    # handle fractional hour offset
    (if $tz.offset_fractional != null then
      # truncate to 4 digits if longer
      ($tz.offset_fractional | if length > 4 then .[0:4] else . end) as $truncated_frac |
      ("0." + $truncated_frac | to_float) as $frac_value |
      ($frac_value * 3600 | truncate_decimal(9)) as $frac_seconds |
      $frac_seconds
    else
      0
    end) as $fractional_seconds |
    
    ($hour_seconds + $minute_seconds + $fractional_seconds) as $total_offset |
    
    # apply sign
    (if $tz.sign == "-" then -$total_offset else $total_offset end) as $signed_offset |
    
    . + {
      offset_seconds: $signed_offset
    }
  end;

# apply timezone offset and handle rollover
# UTC = local time - offset
# handles day/month/year boundary crossings
def apply_timezone_rollover:
  .normalized_date as $date |
  .time_seconds as $time_sec |
  .offset_seconds as $offset_sec |
  .has_fractional as $has_frac |
  
  # apply formula: UTC = local time - offset
  ($time_sec - $offset_sec) as $utc_time |
  
  # check if we need to roll over to previous or next day
  if $utc_time < 0 then
    # negative time - roll back to previous day
    ($utc_time + SECONDS_PER_DAY) as $adjusted_time |
    
    # go back one day
    (add_days_to_date($date.year; $date.month; $date.day; -1)) as $new_date |
    
    . + {
      normalized_date: $new_date,
      time_seconds: $adjusted_time
    }
  elif $utc_time >= SECONDS_PER_DAY then
    # time exceeds 24 hours - roll forward to next day
    ($utc_time - SECONDS_PER_DAY) as $adjusted_time |
    
    # go forward one day
    (add_days_to_date($date.year; $date.month; $date.day; 1)) as $new_date |
    
    . + {
      normalized_date: $new_date,
      time_seconds: $adjusted_time
    }
  else
    # no rollover needed, but still update time_seconds to UTC
    . + {
      time_seconds: $utc_time
    }
  end;

# normalize time and timezone to seconds
def normalize_time_and_timezone:
  # first validate time components
  validate_time_components |
  
  # then normalize time to seconds
  normalize_time |
  
  # validate timezone offset
  validate_timezone_offset |
  
  # normalize timezone to seconds
  normalize_timezone |
  
  # apply timezone offset and handle rollover
  apply_timezone_rollover;

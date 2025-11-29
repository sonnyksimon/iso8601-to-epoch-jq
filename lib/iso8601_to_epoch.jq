# ISO-8601 to unix epoch converter
# main entry point for the conversion function

include "lib/core/error";
include "lib/core/utils";
include "lib/validation/input_validation";
include "lib/parsing/input_parser";
include "lib/calendar/calendar_converter";
include "lib/normalization/date_normalizer";
include "lib/normalization/time_normalizer";
include "lib/epoch/epoch_calculator";

# main function: converts ISO-8601 string to unix epoch
def iso8601_to_epoch:
  validate_input_length
  | classify_and_parse
  | convert_calendar_system
  | normalize_date
  | normalize_time_and_timezone
  | compute_epoch;

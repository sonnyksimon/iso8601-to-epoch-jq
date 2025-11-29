# Error Handling Framework
# Provides standardized error formatting and reporting

# Format error message
# Usage: format_error(component; value; original_input)
def format_error(component; value; original_input):
  "Invalid \(component) '\(value)' in input '\(original_input)'";

# Format year range error
def format_year_range_error(year; original_input):
  "Year '\(year)' outside supported range (-999999 to +999999) in input '\(original_input)'";

# Format unsupported calendar system error
def format_unsupported_calendar_error(system; original_input):
  "Unsupported calendar system '\(system)' in input '\(original_input)'";

# Format ambiguous format error
def format_ambiguous_format_error(format; original_input):
  "Ambiguous date format '\(format)' in input '\(original_input)'";

# Format input length error
def format_length_error(original_input):
  if (original_input | length) > 50 then
    "Input exceeds maximum length of 100 characters: '\(original_input[0:50])...'"
  else
    "Input exceeds maximum length of 100 characters: '\(original_input)'"
  end;

# Format calendar-specific error
def format_calendar_specific_error(component; value; calendar_system; original_input):
  "Invalid \(component) '\(value)' for \(calendar_system) calendar in input '\(original_input)'";

# Throw error with formatted message
def throw_error(message):
  error(message);

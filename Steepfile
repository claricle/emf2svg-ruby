# Steep configuration for RBS type checking

target :lib do
  signature "sig"

  check "lib"

  # Libraries with RBS
  library "pathname"
  library "stringio"

  # Configure for gems (lenient mode for now since we use dynamic features)
  # configure_code_diagnostics would require Steep::Diagnostic constant
end

# Skip test target since RSpec types are not available
# target :test do
#   signature "sig"
#   check "spec"
#   library "pathname"
#   library "stringio"
# end

# frozen_string_literal: true

module Emf2svg
  # Gem version follows the pattern:
  #
  #   {LIBEMF2SVG_VERSION}.{LIBEMF2SVG_RUBY_ITERATION}
  #
  # where LIBEMF2SVG_VERSION is the upstream libemf2svg release this gem
  # is built against, and LIBEMF2SVG_RUBY_ITERATION is a counter for
  # Ruby-side changes (recipe bug fixes, CI changes, docs) that bump
  # without a new libemf2svg release. The iteration resets to 0 each
  # time LIBEMF2SVG_VERSION bumps.
  #
  # See README.adoc -> "Versioning" for the rationale and examples.
  LIBEMF2SVG_VERSION = "1.8.2"
  LIBEMF2SVG_RUBY_ITERATION = 1
  VERSION = "#{LIBEMF2SVG_VERSION}.#{LIBEMF2SVG_RUBY_ITERATION}"
end

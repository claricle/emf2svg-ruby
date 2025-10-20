# frozen_string_literal: true

require_relative "lib/emf2svg/version"

Gem::Specification.new do |spec|
  spec.name          = "emf2svg"
  spec.version       = Emf2svg::VERSION
  spec.authors       = ["Ribose"]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "Pure Ruby EMF to SVG converter with optional C extension fallback."
  spec.homepage      = "https://github.com/metanorma/emf2svg-ruby"
  spec.license       = "BSD-2-Clause"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/metanorma/emf2svg-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/metanorma/emf2svg-ruby"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(?:test|spec|features)/})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Pure Ruby implementation dependencies
  spec.add_dependency "bindata"
  spec.add_dependency "chunky_png"
  spec.add_dependency "moxml"
  spec.add_dependency "nokogiri"

  # Optional C extension fallback (will be removed in future version)
  spec.add_dependency "ffi"
  spec.add_dependency "mini_portile2"

  spec.extensions = ["ext/extconf.rb"]
end

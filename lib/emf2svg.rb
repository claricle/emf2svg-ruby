# frozen_string_literal: true

require_relative "emf2svg/version"

module Emf2svg
  class Error < StandardError; end
  class ParseError < Error; end
  class ValidationError < Error; end

  # Try to load FFI-based C extension (optional, for backwards compatibility)
  begin
    require "ffi"

    class GeneratorOptions < FFI::Struct
      layout :nameSpace, :string,
             :verbose, :bool,
             :emfplus, :bool,
             :svgDelimiter, :bool,
             :imgHeight, :double,
             :imgWidth, :double
    end

    extend FFI::Library

    lib_filename = if FFI::Platform.windows?
                     "emf2svg.dll"
                   elsif FFI::Platform.mac?
                     "libemf2svg.dylib"
                   else
                     "libemf2svg.so"
                   end

    ffi_lib File.expand_path("emf2svg/#{lib_filename}", __dir__)
      .gsub("/", File::ALT_SEPARATOR || File::SEPARATOR)

    attach_function :emf2svg,
                    [
                      :pointer,
                      :size_t,
                      :pointer,
                      :pointer,
                      GeneratorOptions.by_ref,
                    ],
                    :int

    @ffi_available = true
  rescue LoadError, FFI::NotFoundError
    # FFI or C library not available, will use pure Ruby implementation
    @ffi_available = false
  end

  class << self
    def from_file(path, options = {})
      content = File.read(path, mode: "rb")
      from_binary_string(content, options)
    end

    def from_binary_string(content, options = {})
      if use_pure_ruby?
        # Pure Ruby implementation
        require_relative "emf2svg/converter"
        converter = Converter.new(content)
        converter.convert
      else
        # FFI implementation (legacy)
        from_binary_string_ffi(content, options)
      end
    end

    def emfplus?(_content)
      # TODO: Implement EMF+ detection
      false
    end

    def use_pure_ruby?
      ENV["EMF2SVG_PURE_RUBY"] == "1" || !@ffi_available
    end

    def c_extension_available?
      @ffi_available
    end

    private

    def from_binary_string_ffi(content, _options = {})
      svg_out = FFI::MemoryPointer.new(:pointer)
      svg_out_len = FFI::MemoryPointer.new(:pointer)
      content_ptr = FFI::MemoryPointer.from_string(content)

      ret = emf2svg(content_ptr, content.size, svg_out, svg_out_len,
                    ffi_options)
      raise Error, "emf2svg failed with error code: #{ret}" unless ret == 1

      svg_out.read_pointer.read_bytes(svg_out_len.read_int)
    end

    def ffi_options
      GeneratorOptions.new.tap do |opts|
        opts[:verbose] = false
        opts[:emfplus] = true
        opts[:svgDelimiter] = true
        opts[:imgHeight] = 0
        opts[:imgWidth] = 0
      end
    end
  end
end

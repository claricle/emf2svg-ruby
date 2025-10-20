# frozen_string_literal: true

require_relative "parser"
require_relative "gdi_context"
require_relative "svg_builder"
require_relative "records/drawing"
require_relative "records/state"
require_relative "records/path"
require_relative "records/object"
require_relative "records/text"
require_relative "records/clipping"
require_relative "records/bitmap"

module Emf2svg
  # Main converter class that orchestrates EMF to SVG conversion
  class Converter
    attr_reader :parser, :context, :svg_builder, :handlers

    def initialize(binary_data)
      if binary_data.nil? || binary_data.empty?
        raise ArgumentError,
              "EMF binary data cannot be empty"
      end

      @parser = Parser.new(binary_data)
      @context = nil
      @svg_builder = nil
      @handlers = {}
    end

    # Convert EMF to SVG
    # @param options [Hash] Conversion options
    # @option options [Boolean] :verbose Print progress messages
    # @return [String] SVG XML string
    def convert(options = {})
      options[:verbose] || false
      # Parse EMF file
      @parser.parse

      # Get header info for SVG dimensions
      header_info = @parser.header_info
      width = header_info[:width]
      height = header_info[:height]

      # Initialize GDI context and SVG builder
      @context = GdiContext.new
      @svg_builder = SvgBuilder.new(width, height)

      # Build SVG document
      @svg_builder.build do
        # Initialize record handlers
        initialize_handlers

        # Initialize viewport/window from header
        initialize_viewport(header_info)

        # Process all records
        @parser.records.each do |record|
          process_record(record)
        end
      end

      # Return SVG XML
      @svg_builder.to_xml
    end

    private

    def initialize_handlers
      @handlers = {
        drawing: Records::Drawing.new(@context, @svg_builder),
        state: Records::State.new(@context, @svg_builder),
        path: Records::Path.new(@context, @svg_builder),
        object: Records::Object.new(@context, @svg_builder),
        text: Records::Text.new(@context, @svg_builder),
        clipping: Records::Clipping.new(@context, @svg_builder),
        bitmap: Records::Bitmap.new(@context, @svg_builder),
      }
    end

    def initialize_viewport(header_info)
      # Set up initial viewport and window from header
      bounds = header_info[:bounds]
      header_info[:frame]

      # Set window (logical coordinates)
      @context.set_window_org(bounds[:left], bounds[:top])
      @context.set_window_ext(
        bounds[:right] - bounds[:left],
        bounds[:bottom] - bounds[:top],
      )

      # Set viewport (device coordinates)
      @context.set_viewport_org(0, 0)
      @context.set_viewport_ext(
        header_info[:width],
        header_info[:height],
      )
    end

    def process_record(record)
      case record[:type]
      # Drawing records
      when :EMR_POLYGON, :EMR_POLYGON16,
           :EMR_POLYLINE, :EMR_POLYLINE16,
           :EMR_POLYBEZIER, :EMR_POLYBEZIER16,
           :EMR_POLYPOLYLINE, :EMR_POLYPOLYLINE16,
           :EMR_POLYPOLYGON, :EMR_POLYPOLYGON16,
           :EMR_RECTANGLE, :EMR_ELLIPSE, :EMR_ROUNDRECT,
           :EMR_MOVETOEX, :EMR_LINETO,
           :EMR_ARC, :EMR_CHORD, :EMR_PIE, :EMR_ARCTO, :EMR_ANGLEARC
        @handlers[:drawing].process(record)

      # State records
      when :EMR_SAVEDC, :EMR_RESTOREDC,
           :EMR_SETMAPMODE, :EMR_SETBKMODE, :EMR_SETPOLYFILLMODE,
           :EMR_SETTEXTCOLOR, :EMR_SETBKCOLOR,
           :EMR_SETWINDOWORGEX, :EMR_SETWINDOWEXTEX,
           :EMR_SETVIEWPORTORGEX, :EMR_SETVIEWPORTEXTEX,
           :EMR_SETWORLDTRANSFORM, :EMR_MODIFYWORLDTRANSFORM
        @handlers[:state].process(record)

      # Path records
      when :EMR_BEGINPATH, :EMR_ENDPATH, :EMR_CLOSEFIGURE,
           :EMR_FILLPATH, :EMR_STROKEPATH, :EMR_STROKEANDFILLPATH
        @handlers[:path].process(record)

      # Object records
      when :EMR_SELECTOBJECT, :EMR_DELETEOBJECT,
           :EMR_CREATEPEN, :EMR_CREATEBRUSHINDIRECT,
           :EMR_EXTCREATEFONTINDIRECTW
        @handlers[:object].process(record)

      # Text records
      when :EMR_EXTTEXTOUTW, :EMR_EXTTEXTOUTA,
           :EMR_SETTEXTALIGN, :EMR_SETTEXTJUSTIFICATION
        @handlers[:text].process(record)

      # Clipping records
      when :EMR_SELECTCLIPPATH, :EMR_INTERSECTCLIPRECT,
           :EMR_EXCLUDECLIPRECT, :EMR_OFFSETCLIPRGN, :EMR_SETMETARGN
        @handlers[:clipping].process(record)

      # Bitmap records
      when :EMR_BITBLT, :EMR_STRETCHBLT, :EMR_STRETCHDIBITS
        @handlers[:bitmap].process(record)

      # EOF record - do nothing
      when :EMR_EOF
        # End of file marker
        nil

      else
        # Unknown record type - skip
        warn "Unhandled record type: #{record[:type]}" if ENV["EMF2SVG_DEBUG"]
      end
    end
  end
end

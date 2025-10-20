# frozen_string_literal: true

require "stringio"
require_relative "constants"
require_relative "binary_structures"

module Emf2svg
  # Define ParseError locally if not already defined
  unless defined?(Emf2svg::ParseError)
    class ParseError < StandardError; end
  end
  class Parser
    attr_reader :header, :records

    def initialize(binary_data)
      @data = binary_data
      @io = StringIO.new(binary_data)
      @io.set_encoding(Encoding::BINARY)
      @records = []
      @header = nil
    end

    def parse
      parse_header
      parse_records
      @records
    rescue BinData::ValidityError, EOFError => e
      raise Emf2svg::ParseError.new("Failed to parse EMF file: #{e.message}")
    end

    def header_info
      return nil unless @header

      {
        width: @header.bounds.right - @header.bounds.left,
        height: @header.bounds.bottom - @header.bounds.top,
        dpi_x: calculate_dpi_x,
        dpi_y: calculate_dpi_y,
        bounds: {
          left: @header.bounds.left,
          top: @header.bounds.top,
          right: @header.bounds.right,
          bottom: @header.bounds.bottom,
        },
        frame: {
          left: @header.frame.left,
          top: @header.frame.top,
          right: @header.frame.right,
          bottom: @header.frame.bottom,
        },
        version: @header.version,
        records: @header.records,
        handles: @header.handles,
      }
    end

    private

    def parse_header
      @io.rewind

      # Check minimum header size
      if @data.bytesize < 88
        raise Emf2svg::ParseError.new("EMF file too small: #{@data.bytesize} bytes (minimum 88 bytes required)")
      end

      @header = BinaryStructures::EmfHeader.read(@io)
      validate_header!

      # Validate file size matches header specification
      if @data.bytesize < @header.bytes
        raise Emf2svg::ParseError.new("EMF file truncated: expected #{@header.bytes} bytes but got #{@data.bytesize} bytes")
      end
    rescue BinData::ValidityError, EOFError => e
      raise Emf2svg::ParseError.new("Failed to parse EMF header: #{e.message}")
    end

    def validate_header!
      unless @header.record_type == 0x00000001
        raise Emf2svg::ParseError.new("Invalid EMF header type: 0x#{@header.record_type.to_i.to_s(16)}")
      end

      unless @header.signature == EMF_SIGNATURE
        raise Emf2svg::ParseError.new("Invalid EMF signature: 0x#{@header.signature.to_i.to_s(16)}")
      end

      true
    end

    def parse_records
      @io.rewind
      @io.read(@header.record_size) # Skip header

      record_count = 0
      while @io.pos < @data.bytesize
        record_count += 1
        puts "DEBUG: Parsing record ##{record_count} at position #{@io.pos}" if ENV["EMF_DEBUG"]

        record = parse_next_record
        break if record.nil?

        puts "DEBUG: Parsed record ##{record_count}: #{record[:type]}" if ENV["EMF_DEBUG"]
        @records << record
        break if record[:type] == :EMR_EOF
      end
    end

    def parse_next_record
      return nil if @io.eof?

      start_pos = @io.pos

      # Peek at type and size
      type_num = read_uint32
      size = read_uint32

      return nil if type_num.nil? || size.nil?

      # Rewind to read full record
      @io.seek(start_pos)

      # Get record type symbol
      record_type = EMF_RECORD_TYPES[type_num]

      # Parse specific record structure
      record_data = parse_record_by_type(type_num, size)

      {
        type: record_type || :UNKNOWN,
        type_num: type_num,
        size: size,
        data: record_data,
      }
    rescue StandardError => e
      warn "Error parsing record at position #{start_pos}: #{e.message}"
      # Skip this record
      @io.seek(start_pos + size) if size&.positive?
      nil
    end

    def parse_record_by_type(type_num, size)
      record_type = EMF_RECORD_TYPES[type_num]

      case record_type
      when :EMR_POLYGON, :EMR_POLYLINE, :EMR_POLYBEZIER
        parse_poly_record
      when :EMR_POLYGON16, :EMR_POLYLINE16, :EMR_POLYBEZIER16
        parse_poly16_record
      when :EMR_POLYPOLYGON
        parse_polypolygon_record
      when :EMR_POLYPOLYGON16
        parse_polypolygon16_record
      when :EMR_RECTANGLE
        parse_rectangle_record
      when :EMR_ROUNDRECT
        parse_roundrect_record
      when :EMR_ELLIPSE
        parse_ellipse_record
      when :EMR_SAVEDC
        parse_simple_record
      when :EMR_RESTOREDC
        parse_restore_dc_record
      when :EMR_SELECTOBJECT
        parse_select_object_record
      when :EMR_DELETEOBJECT
        parse_delete_object_record
      when :EMR_CREATEPEN
        parse_create_pen_record
      when :EMR_CREATEBRUSHINDIRECT
        parse_create_brush_record
      when :EMR_SETTEXTCOLOR, :EMR_SETBKCOLOR
        parse_set_color_record
      when :EMR_SETBKMODE
        parse_set_mode_record(:bk_mode)
      when :EMR_SETPOLYFILLMODE
        parse_set_mode_record(:poly_fill_mode)
      when :EMR_SETMAPMODE
        parse_set_mode_record(:map_mode)
      when :EMR_SETWORLDTRANSFORM
        parse_set_world_transform_record
      when :EMR_MODIFYWORLDTRANSFORM
        parse_modify_world_transform_record
      when :EMR_SETWINDOWEXTEX, :EMR_SETVIEWPORTEXTEX
        parse_set_ext_record
      when :EMR_SETWINDOWORGEX, :EMR_SETVIEWPORTORGEX
        parse_set_org_record
      when :EMR_MOVETOEX
        parse_move_to_record
      when :EMR_LINETO
        parse_line_to_record
      when :EMR_BEGINPATH, :EMR_ENDPATH, :EMR_CLOSEFIGURE
        parse_simple_record
      when :EMR_FILLPATH, :EMR_STROKEPATH, :EMR_STROKEANDFILLPATH
        parse_path_record
      when :EMR_SELECTCLIPPATH
        parse_select_clip_path_record
      when :EMR_EXTCREATEFONTINDIRECTW
        parse_ext_create_font_record
      when :EMR_EXTTEXTOUTW
        parse_ext_text_out_w_record
      when :EMR_EXTTEXTOUTA
        parse_ext_text_out_a_record
      when :EMR_EOF
        parse_eof_record
      else
        parse_generic_record(size)
      end
    end

    def parse_poly_record
      # Manual parsing for EMR_POLYGON/POLYLINE/POLYBEZIER
      start_pos = @io.pos
      read_uint32
      size = read_uint32

      # Validate minimum size (type + size + bounds + num_points = 28 bytes)
      if size < 28
        warn "Invalid polygon record size #{size} at position #{start_pos}, skipping"
        @io.seek(start_pos + size)
        return { bounds: { left: 0, top: 0, right: 0, bottom: 0 }, points: [] }
      end

      # Read bounds
      bounds = {
        left: read_int32,
        top: read_int32,
        right: read_int32,
        bottom: read_int32,
      }

      # Read number of points
      num_points = read_uint32

      # Validate we have enough data for the points
      points_size = num_points * 8 # Each point is 8 bytes (2 x int32)
      expected_size = 28 + points_size
      if size < expected_size
        warn "Polygon record size #{size} too small for #{num_points} points, skipping"
        @io.seek(start_pos + size)
        return { bounds: bounds, points: [] }
      end

      # Read points
      points = []
      num_points.times do
        points << { x: read_int32, y: read_int32 }
      end

      { bounds: bounds, points: points }
    rescue StandardError => e
      warn "Error parsing polygon record: #{e.message}"
      @io.seek(start_pos + size) if size&.positive?
      { bounds: { left: 0, top: 0, right: 0, bottom: 0 }, points: [] }
    end

    def parse_poly16_record
      record = BinaryStructures::EmrPoly16.read(@io)
      {
        bounds: rect_to_hash(record.bounds),
        points: record.points.map { |p| { x: p.x, y: p.y } },
      }
    end

    def parse_polypolygon_record
      record = BinaryStructures::EmrPolyPolygon.read(@io)
      {
        bounds: rect_to_hash(record.bounds),
        poly_counts: record.poly_counts.to_ary,
        points: record.points.map { |p| { x: p.x, y: p.y } },
      }
    rescue BinData::ValidityError, EOFError => e
      raise Emf2svg::ParseError.new("Failed to parse polypolygon record: #{e.message}")
    end

    def parse_polypolygon16_record
      record = BinaryStructures::EmrPolyPolygon16.read(@io)
      {
        bounds: rect_to_hash(record.bounds),
        poly_counts: record.poly_counts.to_ary,
        points: record.points.map { |p| { x: p.x, y: p.y } },
      }
    rescue BinData::ValidityError, EOFError => e
      raise Emf2svg::ParseError.new("Failed to parse polypolygon16 record: #{e.message}")
    end

    def parse_rectangle_record
      record = BinaryStructures::EmrRectangle.read(@io)
      { box: rect_to_hash(record.box) }
    end

    def parse_roundrect_record
      # Manual parsing for EMR_ROUNDRECT
      read_uint32
      read_uint32

      # Read box (16 bytes)
      box = {
        left: read_int32,
        top: read_int32,
        right: read_int32,
        bottom: read_int32,
      }

      # Read corner (8 bytes)
      corner = {
        x: read_int32,
        y: read_int32,
      }

      { box: box, corner: corner }
    end

    def parse_ellipse_record
      record = BinaryStructures::EmrEllipse.read(@io)
      { box: rect_to_hash(record.box) }
    end

    def parse_simple_record
      BinaryStructures::EmfRecord.read(@io)
      {}
    end

    def parse_restore_dc_record
      record = BinaryStructures::EmrRestoreDc.read(@io)
      { saved_dc: record.saved_dc }
    end

    def parse_select_object_record
      record = BinaryStructures::EmrSelectObject.read(@io)
      { ih_object: record.ih_object }
    end

    def parse_delete_object_record
      record = BinaryStructures::EmrDeleteObject.read(@io)
      { ih_object: record.ih_object }
    end

    def parse_create_pen_record
      record = BinaryStructures::EmrCreatePen.read(@io)
      {
        ih_pen: record.ih_pen,
        style: record.style,
        width: { x: record.width.x, y: record.width.y },
        color: color_to_hash(record.color),
      }
    end

    def parse_create_brush_record
      record = BinaryStructures::EmrCreateBrushIndirect.read(@io)
      {
        ih_brush: record.ih_brush,
        style: record.style,
        color: color_to_hash(record.color),
        hatch: record.hatch,
      }
    end

    def parse_set_color_record
      record = BinaryStructures::EmrSetTextColor.read(@io)
      { color: color_to_hash(record.color) }
    end

    def parse_set_mode_record(mode_field)
      read_uint32
      read_uint32
      mode = read_uint32
      { mode_field => mode }
    end

    def parse_set_world_transform_record
      record = BinaryStructures::EmrSetWorldTransform.read(@io)
      { xform: xform_to_hash(record.xform) }
    end

    def parse_modify_world_transform_record
      record = BinaryStructures::EmrModifyWorldTransform.read(@io)
      {
        xform: xform_to_hash(record.xform),
        mode: record.mode,
      }
    end

    def parse_set_ext_record
      record = BinaryStructures::EmrSetExtEx.read(@io)
      { extent: { cx: record.extent.cx, cy: record.extent.cy } }
    end

    def parse_set_org_record
      record = BinaryStructures::EmrSetOrgEx.read(@io)
      { origin: { x: record.origin.x, y: record.origin.y } }
    end

    def parse_move_to_record
      record = BinaryStructures::EmrMoveToEx.read(@io)
      { offset: { x: record.offset.x, y: record.offset.y } }
    end

    def parse_line_to_record
      record = BinaryStructures::EmrLineTo.read(@io)
      { point: { x: record.point.x, y: record.point.y } }
    end

    def parse_path_record
      record = BinaryStructures::EmrFillPath.read(@io)
      { bounds: rect_to_hash(record.bounds) }
    end

    def parse_select_clip_path_record
      record = BinaryStructures::EmrSelectClipPath.read(@io)
      { rgn_mode: record.rgn_mode }
    end

    def parse_ext_create_font_record
      # Manual parsing for EMR_EXTCREATEFONTINDIRECTW
      read_uint32
      size = read_uint32
      ih_font = read_uint32

      # LOGFONTEXW structure (320 bytes)
      height = read_int32
      width = read_int32
      escapement = read_int32
      orientation = read_int32
      weight = read_int32
      italic = read_uint8
      underline = read_uint8
      strike_out = read_uint8
      char_set = read_uint8
      out_precision = read_uint8
      clip_precision = read_uint8
      quality = read_uint8
      pitch_and_family = read_uint8

      # Face name is 64 bytes (32 UTF-16LE characters)
      face_name_bytes = @io.read(64)
      face_name = begin
        face_name_bytes.force_encoding("UTF-16LE").encode("UTF-8",
                                                          invalid: :replace, undef: :replace).strip.delete("\u0000")
      rescue StandardError
        "Arial"
      end

      # Skip remaining LOGFONTEXW fields (FullName, Style, Script, etc.)
      remaining = size - 8 - 4 - 64 - 4 * 4 - 8
      @io.read(remaining) if remaining.positive?

      {
        ih_font: ih_font,
        log_font: {
          height: height,
          width: width,
          escapement: escapement,
          orientation: orientation,
          weight: weight,
          italic: italic,
          underline: underline,
          strike_out: strike_out,
          char_set: char_set,
          out_precision: out_precision,
          clip_precision: clip_precision,
          quality: quality,
          pitch_and_family: pitch_and_family,
          face_name: face_name,
        },
      }
    rescue StandardError => e
      raise Emf2svg::ParseError.new("Failed to parse font creation record: #{e.message}")
    end

    def parse_ext_text_out_w_record
      # Manual parsing for EMR_EXTTEXTOUTW
      read_uint32
      size = read_uint32

      # Bounds rectangle
      bounds = {
        left: read_int32,
        top: read_int32,
        right: read_int32,
        bottom: read_int32,
      }

      i_graphics_mode = read_uint32
      ex_scale = read_float
      ey_scale = read_float

      # EmrText structure
      reference_x = read_int32
      reference_y = read_int32
      chars = read_uint32
      read_uint32
      options = read_uint32

      rectangle = {
        left: read_int32,
        top: read_int32,
        right: read_int32,
        bottom: read_int32,
      }

      read_uint32

      # Skip variable-length string and dx array data
      remaining = size - (8 + 16 + 4 + 8 + 20 + 16 + 4)
      @io.read(remaining) if remaining.positive?

      {
        bounds: bounds,
        i_graphics_mode: i_graphics_mode,
        ex_scale: ex_scale,
        ey_scale: ey_scale,
        reference: { x: reference_x, y: reference_y },
        chars: chars,
        options: options,
        rectangle: rectangle,
      }
    rescue StandardError => e
      raise Emf2svg::ParseError.new("Failed to parse text output record: #{e.message}")
    end

    def parse_ext_text_out_a_record
      # EMR_EXTTEXTOUTA has same structure as W version
      parse_ext_text_out_w_record
    end

    def parse_eof_record
      record = BinaryStructures::EmrEof.read(@io)
      {
        n_pal_entries: record.n_pal_entries,
        off_pal_entries: record.off_pal_entries,
        size_last: record.size_last,
      }
    end

    def parse_generic_record(size)
      # Read type and size we already know
      read_uint32 # type
      read_uint32 # size
      # Read remaining data
      data = @io.read(size - 8)
      { raw_data: data }
    end

    # Helper methods

    def rect_to_hash(rect)
      {
        left: rect.left,
        top: rect.top,
        right: rect.right,
        bottom: rect.bottom,
      }
    end

    def color_to_hash(color)
      {
        r: color.red,
        g: color.green,
        b: color.blue,
      }
    end

    def xform_to_hash(xform)
      {
        m11: xform.m11,
        m12: xform.m12,
        m21: xform.m21,
        m22: xform.m22,
        dx: xform.dx,
        dy: xform.dy,
      }
    end

    def read_uint32
      bytes = @io.read(4)
      return nil unless bytes && bytes.length == 4

      bytes.unpack1("L<")
    end

    def read_int32
      bytes = @io.read(4)
      return nil unless bytes && bytes.length == 4

      bytes.unpack1("l<")
    end

    def read_uint8
      bytes = @io.read(1)
      return nil unless bytes && bytes.length == 1

      bytes.unpack1("C")
    end

    def read_float
      bytes = @io.read(4)
      return nil unless bytes && bytes.length == 4

      bytes.unpack1("e")
    end

    def calculate_dpi_x
      return 96.0 if @header.millimeters.cx.zero?

      (@header.device.cx * 25.4) / @header.millimeters.cx
    end

    def calculate_dpi_y
      return 96.0 if @header.millimeters.cy.zero?

      (@header.device.cy * 25.4) / @header.millimeters.cy
    end
  end
end

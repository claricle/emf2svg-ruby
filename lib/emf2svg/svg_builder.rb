# frozen_string_literal: true

require "moxml"

module Emf2svg
  # SVG builder creates SVG document from EMF records using Moxml
  class SvgBuilder
    attr_reader :width, :height, :moxml

    def initialize(width, height, view_box: nil)
      @width = width
      @height = height
      @view_box = view_box || "0 0 #{width} #{height}"
      @moxml = Moxml.new
      @doc = nil
      @svg_root = nil
      @defs = nil
      @current_group = nil
      @clip_paths = {}
      @patterns = {}
    end

    # Build SVG document
    def build
      @doc = @moxml.create_document

      # Create SVG root element
      @svg_root = @doc.create_element("svg")
      @svg_root.add_namespace(nil, "http://www.w3.org/2000/svg")
      @svg_root["width"] = @width.to_s
      @svg_root["height"] = @height.to_s
      @svg_root["viewBox"] = @view_box
      @doc.add_child(@svg_root)

      yield self if block_given?

      self
    end

    # Get the root element for adding children
    def root
      @svg_root
    end

    # Add defs section
    def add_defs
      @defs ||= @doc.create_element("defs")
      @svg_root.add_child(@defs) unless @svg_root.children.include?(@defs)
      @defs
    end

    # Add a path element
    def add_path(d, pen: nil, brush: nil, transform: nil)
      path = @doc.create_element("path")
      path["d"] = d
      apply_pen(path, pen) if pen
      apply_brush(path, brush) if brush
      path["transform"] = transform if transform

      add_to_current_container(path)
      path
    end

    # Add a polygon
    def add_polygon(points, pen: nil, brush: nil, transform: nil)
      polygon = @doc.create_element("polygon")
      polygon["points"] = points_to_string(points)
      apply_pen(polygon, pen) if pen
      apply_brush(polygon, brush) if brush
      polygon["transform"] = transform if transform

      add_to_current_container(polygon)
      polygon
    end

    # Add a polyline
    def add_polyline(points, pen: nil, transform: nil)
      polyline = @doc.create_element("polyline")
      polyline["points"] = points_to_string(points)
      apply_pen(polyline, pen) if pen
      polyline["fill"] = "none"
      polyline["transform"] = transform if transform

      add_to_current_container(polyline)
      polyline
    end

    # Add a rectangle
    def add_rectangle(x, y, width, height, pen: nil, brush: nil,
transform: nil, rx: nil, ry: nil)
      rect = @doc.create_element("rect")
      rect["x"] = x.to_s
      rect["y"] = y.to_s
      rect["width"] = width.to_s
      rect["height"] = height.to_s
      rect["rx"] = rx.to_s if rx&.positive?
      rect["ry"] = ry.to_s if ry&.positive?
      apply_pen(rect, pen) if pen
      apply_brush(rect, brush) if brush
      rect["transform"] = transform if transform

      add_to_current_container(rect)
      rect
    end

    # Add an ellipse
    def add_ellipse(cx, cy, rx, ry, pen: nil, brush: nil, transform: nil)
      ellipse = @doc.create_element("ellipse")
      ellipse["cx"] = cx.to_s
      ellipse["cy"] = cy.to_s
      ellipse["rx"] = rx.to_s
      ellipse["ry"] = ry.to_s
      apply_pen(ellipse, pen) if pen
      apply_brush(ellipse, brush) if brush
      ellipse["transform"] = transform if transform

      add_to_current_container(ellipse)
      ellipse
    end

    # Add a line
    def add_line(x1, y1, x2, y2, pen: nil, transform: nil)
      line = @doc.create_element("line")
      line["x1"] = x1.to_s
      line["y1"] = y1.to_s
      line["x2"] = x2.to_s
      line["y2"] = y2.to_s
      apply_pen(line, pen) if pen
      line["fill"] = "none"
      line["transform"] = transform if transform

      add_to_current_container(line)
      line
    end

    # Add text
    def add_text(x, y, text, fill: nil, font_family: nil, font_size: nil,
font_weight: nil, font_style: nil, text_anchor: nil, transform: nil)
      text_elem = @doc.create_element("text")
      text_elem["x"] = x.to_s
      text_elem["y"] = y.to_s
      text_elem["fill"] = color_to_hex(fill) if fill
      text_elem["font-family"] = font_family if font_family
      text_elem["font-size"] = "#{font_size}px" if font_size
      text_elem["font-weight"] = font_weight if font_weight
      text_elem["font-style"] = font_style if font_style
      text_elem["text-anchor"] = text_anchor if text_anchor
      text_elem["transform"] = transform if transform
      text_elem.text = text

      add_to_current_container(text_elem)
      text_elem
    end

    # Add image
    def add_image(x, y, width, height, href, transform: nil)
      image = @doc.create_element("image")
      image["x"] = x.to_s
      image["y"] = y.to_s
      image["width"] = width.to_s
      image["height"] = height.to_s
      image["href"] = href
      image["transform"] = transform if transform

      add_to_current_container(image)
      image
    end

    # Start a group
    def start_group(transform: nil, id: nil)
      group = @doc.create_element("g")
      group["transform"] = transform if transform
      group["id"] = id if id

      add_to_current_container(group)
      @current_group = group
      group
    end

    # End current group
    def end_group
      @current_group = @current_group&.parent if @current_group != @svg_root
    end

    # Add a clip path definition
    def add_clip_path(id, path_data)
      ensure_defs_section
      return if @clip_paths.key?(id)

      clip_path = @doc.create_element("clipPath")
      clip_path["id"] = id

      path = @doc.create_element("path")
      path["d"] = path_data

      clip_path.add_child(path)
      @defs.add_child(clip_path)
      @clip_paths[id] = clip_path

      clip_path
    end

    # Apply clip path to an element
    def apply_clip_path(element, clip_id)
      element["clip-path"] = "url(##{clip_id})" if clip_id
    end

    # Convert to XML string
    def to_xml(indent: 2)
      @doc.to_xml(indent: indent)
    end

    alias to_s to_xml

    private

    def add_to_current_container(element)
      container = @current_group || @svg_root
      container.add_child(element)
    end

    def points_to_string(points)
      points.map { |p| "#{p[:x]},#{p[:y]}" }.join(" ")
    end

    def apply_pen(element, pen)
      return if pen[:style] == PEN_STYLES[:PS_NULL]

      element["stroke"] = color_to_hex(pen[:color])
      element["stroke-width"] = pen[:width].to_s

      case pen[:style]
      when PEN_STYLES[:PS_DASH]
        element["stroke-dasharray"] = "5,2"
      when PEN_STYLES[:PS_DOT]
        element["stroke-dasharray"] = "1,2"
      when PEN_STYLES[:PS_DASHDOT]
        element["stroke-dasharray"] = "5,2,1,2"
      when PEN_STYLES[:PS_DASHDOTDOT]
        element["stroke-dasharray"] = "5,2,1,2,1,2"
      end
    end

    def apply_brush(element, brush)
      if brush[:style] == BRUSH_STYLES[:BS_NULL]
        element["fill"] = "none"
      elsif brush[:style] == BRUSH_STYLES[:BS_HATCHED] && brush[:hatch]
        # Use hatch pattern
        pattern_id = add_hatch_pattern(brush[:hatch], brush[:color])
        element["fill"] = "url(##{pattern_id})"
      elsif brush[:style] == BRUSH_STYLES[:BS_PATTERN] && brush[:pattern_id]
        # Use custom pattern
        element["fill"] = "url(##{brush[:pattern_id]})"
      else
        # Solid fill
        element["fill"] = color_to_hex(brush[:color])
      end
    end

    def apply_font(element, font)
      element["font-family"] = font[:facename] if font[:facename]
      element["font-size"] = "#{font[:height]}px" if font[:height]
      element["font-weight"] = font[:weight].to_s if font[:weight]
      element["font-style"] = "italic" if font[:italic]
      element["text-decoration"] = "underline" if font[:underline]
      element["text-decoration"] = "line-through" if font[:strikeout]
    end

    def color_to_hex(color)
      format("#%02x%02x%02x", color[:r], color[:g], color[:b])
    end

    def ensure_defs_section
      add_defs unless @defs
    end

    # Add a pattern definition for hatch styles
    def add_hatch_pattern(hatch_style, color)
      pattern_id = "hatch_#{hatch_style}_#{color_to_hex(color).tr('#', '')}"
      return pattern_id if @patterns.key?(pattern_id)

      ensure_defs_section

      pattern = @doc.create_element("pattern")
      pattern["id"] = pattern_id
      pattern["width"] = "8"
      pattern["height"] = "8"
      pattern["patternUnits"] = "userSpaceOnUse"

      # Background rectangle
      bg = @doc.create_element("rect")
      bg["width"] = "8"
      bg["height"] = "8"
      bg["fill"] = "none"
      pattern.add_child(bg)

      # Add hatch lines based on style
      create_hatch_lines(pattern, hatch_style, color)

      @defs.add_child(pattern)
      @patterns[pattern_id] = pattern

      pattern_id
    end

    # Create hatch line elements for pattern
    def create_hatch_lines(pattern, hatch_style, color)
      stroke_color = color_to_hex(color)

      case hatch_style
      when HATCH_STYLES[:HS_HORIZONTAL]
        # Horizontal lines
        line = @doc.create_element("line")
        line["x1"] = "0"
        line["y1"] = "4"
        line["x2"] = "8"
        line["y2"] = "4"
        line["stroke"] = stroke_color
        line["stroke-width"] = "1"
        pattern.add_child(line)

      when HATCH_STYLES[:HS_VERTICAL]
        # Vertical lines
        line = @doc.create_element("line")
        line["x1"] = "4"
        line["y1"] = "0"
        line["x2"] = "4"
        line["y2"] = "8"
        line["stroke"] = stroke_color
        line["stroke-width"] = "1"
        pattern.add_child(line)

      when HATCH_STYLES[:HS_FDIAGONAL]
        # Forward diagonal (/)
        line = @doc.create_element("line")
        line["x1"] = "0"
        line["y1"] = "8"
        line["x2"] = "8"
        line["y2"] = "0"
        line["stroke"] = stroke_color
        line["stroke-width"] = "1"
        pattern.add_child(line)

      when HATCH_STYLES[:HS_BDIAGONAL]
        # Backward diagonal (\)
        line = @doc.create_element("line")
        line["x1"] = "0"
        line["y1"] = "0"
        line["x2"] = "8"
        line["y2"] = "8"
        line["stroke"] = stroke_color
        line["stroke-width"] = "1"
        pattern.add_child(line)

      when HATCH_STYLES[:HS_CROSS]
        # Cross (+ pattern)
        h_line = @doc.create_element("line")
        h_line["x1"] = "0"
        h_line["y1"] = "4"
        h_line["x2"] = "8"
        h_line["y2"] = "4"
        h_line["stroke"] = stroke_color
        h_line["stroke-width"] = "1"
        pattern.add_child(h_line)

        v_line = @doc.create_element("line")
        v_line["x1"] = "4"
        v_line["y1"] = "0"
        v_line["x2"] = "4"
        v_line["y2"] = "8"
        v_line["stroke"] = stroke_color
        v_line["stroke-width"] = "1"
        pattern.add_child(v_line)

      when HATCH_STYLES[:HS_DIAGCROSS]
        # Diagonal cross (X pattern)
        fd_line = @doc.create_element("line")
        fd_line["x1"] = "0"
        fd_line["y1"] = "8"
        fd_line["x2"] = "8"
        fd_line["y2"] = "0"
        fd_line["stroke"] = stroke_color
        fd_line["stroke-width"] = "1"
        pattern.add_child(fd_line)

        bd_line = @doc.create_element("line")
        bd_line["x1"] = "0"
        bd_line["y1"] = "0"
        bd_line["x2"] = "8"
        bd_line["y2"] = "8"
        bd_line["stroke"] = stroke_color
        bd_line["stroke-width"] = "1"
        pattern.add_child(bd_line)
      end
    end
  end
end

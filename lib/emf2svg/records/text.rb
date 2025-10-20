# frozen_string_literal: true

require_relative "base"

module Emf2svg
  module Records
    # Handler for text-related EMF records
    class Text < Base
      # Process text records
      def process(record)
        case record[:type]
        when :EMR_EXTTEXTOUTW
          handle_exttextoutw(record)
        when :EMR_EXTTEXTOUTA
          handle_exttextouta(record)
        when :EMR_SETTEXTALIGN
          handle_settextalign(record)
        when :EMR_SETTEXTJUSTIFICATION
          handle_settextjustification(record)
        end
      end

      private

      def handle_exttextoutw(record)
        # Get text parameters
        text = record[:text] || ""
        x = record[:x] || 0
        y = record[:y] || 0

        # Transform point
        point = map_coordinates(x, y)

        # Get current text color
        text_color = @context.text_color

        # Get current font (if available)
        font = @context.current_font

        # Build font style
        font_family = font ? (font[:face_name] || "Arial") : "Arial"
        font_size = font ? (font[:height].abs || 12) : 12
        font_weight = font && font[:weight] && font[:weight] >= 700 ? "bold" : "normal"
        font_style = font && font[:italic] && font[:italic] != 0 ? "italic" : "normal"

        # Get text alignment
        text_anchor = get_text_anchor

        # Add text element to SVG
        @svg_builder.add_text(
          point[:x],
          point[:y],
          text,
          fill: text_color,
          font_family: font_family,
          font_size: font_size,
          font_weight: font_weight,
          font_style: font_style,
          text_anchor: text_anchor,
        )
      end

      def handle_exttextouta(record)
        # ANSI version - convert to Unicode and handle as ExtTextOutW
        # For now, treat the same as ExtTextOutW
        handle_exttextoutw(record)
      end

      def handle_settextalign(record)
        align = record[:align]
        @context.set_text_align(align) if align
      end

      def handle_settextjustification(record)
        # Handle text justification settings
        # This affects character spacing in justified text
        extra = record[:extra] || 0
        break_count = record[:break_count] || 0
        @context.set_text_justification(extra, break_count)
      end

      def get_text_anchor
        # Convert EMF text alignment to SVG text-anchor
        align = @context.text_align

        # TA_LEFT (0x00), TA_RIGHT (0x02), TA_CENTER (0x06)
        horizontal = align & 0x06

        case horizontal
        when 0x02 # TA_RIGHT
          "end"
        when 0x06 # TA_CENTER
          "middle"
        else # TA_LEFT or default
          "start"
        end
      end
    end
  end
end

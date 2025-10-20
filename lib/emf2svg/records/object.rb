# frozen_string_literal: true

require_relative "base"
require_relative "../constants"

module Emf2svg
  module Records
    # Handler for EMF object creation and manipulation records
    class Object < Base
      # Process object record
      def process(record)
        case record[:type]
        when :EMR_SELECTOBJECT
          process_select_object(record)
        when :EMR_DELETEOBJECT
          process_delete_object(record)
        when :EMR_CREATEPEN
          process_create_pen(record)
        when :EMR_CREATEBRUSHINDIRECT
          process_create_brush(record)
        when :EMR_EXTCREATEFONTINDIRECTW
          process_create_font(record)
        end
      end

      private

      def process_select_object(record)
        ih_object = record[:data][:ih_object]
        @context.select_object(ih_object)
      end

      def process_delete_object(record)
        ih_object = record[:data][:ih_object]
        @context.delete_object(ih_object)
      end

      def process_create_pen(record)
        data = record[:data]
        pen = {
          type: :pen,
          style: data[:style],
          width: data[:width][:x], # Use x-width
          color: data[:color],
        }

        @context.create_object(data[:ih_pen], pen)
      end

      def process_create_brush(record)
        data = record[:data]
        brush = {
          type: :brush,
          style: data[:style],
          color: data[:color],
          hatch: data[:hatch],
        }

        @context.create_object(data[:ih_brush], brush)
      end

      def process_create_font(record)
        data = record[:data]
        log_font = data[:log_font]

        return unless log_font

        # Extract font properties from LOGFONT structure
        font = {
          type: :font,
          height: log_font[:height] ? log_font[:height].abs : 12,
          width: log_font[:width] || 0,
          escapement: log_font[:escapement] || 0,
          orientation: log_font[:orientation] || 0,
          weight: log_font[:weight] || 400,
          italic: log_font[:italic] && log_font[:italic] != 0,
          underline: log_font[:underline] && log_font[:underline] != 0,
          strikeout: log_font[:strike_out] && log_font[:strike_out] != 0,
          charset: log_font[:char_set] || 0,
          out_precision: log_font[:out_precision] || 0,
          clip_precision: log_font[:clip_precision] || 0,
          quality: log_font[:quality] || 0,
          pitch_and_family: log_font[:pitch_and_family] || 0,
          face_name: log_font[:face_name] || "Arial",
        }

        @context.create_object(data[:ih_font], font)
      end
    end
  end
end

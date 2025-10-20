# frozen_string_literal: true

require_relative "../gdi_context"
require_relative "../svg_builder"

module Emf2svg
  module Records
    # Base class for EMF record handlers
    class Base
      attr_reader :context, :svg_builder

      def initialize(context, svg_builder)
        @context = context
        @svg_builder = svg_builder
      end

      # Process a record - override in subclasses
      # @param record [Hash] The parsed EMF record
      # @return [void]
      def process(record)
        raise NotImplementedError, "#{self.class} must implement #process"
      end

      protected

      # Apply current transform to points
      def transform_points(points)
        @context.transform.transform_points(points)
      end

      # Apply current transform to a single point
      def transform_point(x, y)
        @context.transform.transform_point(x, y)
      end

      # Get current transform as SVG matrix string
      def current_transform
        @context.transform.to_svg
      end

      # Convert EMF color to hex
      def color_to_hex(color)
        format("#%02x%02x%02x", color[:r], color[:g], color[:b])
      end

      # Get current pen for stroking
      def current_pen
        @context.selected_pen
      end

      # Get current brush for filling
      def current_brush
        @context.selected_brush
      end

      # Get current font
      def current_font
        @context.selected_font
      end

      # Check if pen should be used for stroking
      def use_stroke?
        pen = current_pen
        return false unless pen
        return false if pen[:style] == PEN_STYLES[:PS_NULL]

        true
      end

      # Check if brush should be used for filling
      def use_fill?
        brush = current_brush
        return false unless brush
        return false if brush[:style] == BRUSH_STYLES[:BS_NULL]

        true
      end

      # Calculate bounding box from points
      def calculate_bounds(points)
        return { left: 0, top: 0, right: 0, bottom: 0 } if points.empty?

        xs = points.map { |p| p[:x] }
        ys = points.map { |p| p[:y] }

        {
          left: xs.min,
          top: ys.min,
          right: xs.max,
          bottom: ys.max,
        }
      end

      # Create SVG path data from points
      def points_to_path_data(points, close: false)
        return "" if points.empty?

        path = "M #{points[0][:x]},#{points[0][:y]}"
        points[1..].each do |point|
          path << " L #{point[:x]},#{point[:y]}"
        end
        path << " Z" if close

        path
      end

      # Map EMF coordinates to device coordinates
      def map_coordinates(x, y)
        # Apply viewport/window mapping if needed
        if @context.window_ext[:cx] != 0 && @context.window_ext[:cy] != 0
          # Convert from logical to device coordinates
          x_scale = @context.viewport_ext[:cx].to_f / @context.window_ext[:cx]
          y_scale = @context.viewport_ext[:cy].to_f / @context.window_ext[:cy]

          x = ((x - @context.window_org[:x]) * x_scale) + @context.viewport_org[:x]
          y = ((y - @context.window_org[:y]) * y_scale) + @context.viewport_org[:y]
        end

        { x: x, y: y }
      end

      # Map rectangle coordinates
      def map_rect(rect)
        top_left = map_coordinates(rect[:left], rect[:top])
        bottom_right = map_coordinates(rect[:right], rect[:bottom])

        {
          left: top_left[:x],
          top: top_left[:y],
          right: bottom_right[:x],
          bottom: bottom_right[:y],
        }
      end
    end
  end
end

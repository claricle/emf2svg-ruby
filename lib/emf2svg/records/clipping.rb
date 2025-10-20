# frozen_string_literal: true

module Emf2svg
  module Records
    # Handler for clipping-related EMF records
    class Clipping < Base
      # Process clipping record
      def process(record)
        case record[:type]
        when :EMR_SELECTCLIPPATH
          handle_selectclippath(record)
        when :EMR_INTERSECTCLIPRECT
          handle_intersectcliprect(record)
        when :EMR_EXCLUDECLIPRECT
          handle_excludecliprect(record)
        when :EMR_OFFSETCLIPRGN
          handle_offsetcliprgn(record)
        when :EMR_SETMETARGN
          handle_setmetargn(record)
        end
      end

      # Handle EMR_SELECTCLIPPATH
      # Selects the current path as a clipping region
      def handle_selectclippath(_record)
        return unless @context.in_path?

        # Get current path and use it as clipping region
        path_data = @context.current_path
        return if path_data.nil? || path_data.empty?

        # Convert path to SVG clip path
        clip_id = "clip_#{@context.object_table.length}"

        # Create clip path definition
        @svg_builder.add_clip_path(clip_id, path_data)

        # Set clipping region in context
        @context.set_clip_region(clip_id)
      end

      # Handle EMR_INTERSECTCLIPRECT
      # Creates a new clipping region from the intersection of the current
      # clipping region and the specified rectangle
      def handle_intersectcliprect(record)
        rect = record[:rect]
        return unless rect

        # Transform rectangle points
        points = [
          transform_point(rect[:left], rect[:top]),
          transform_point(rect[:right], rect[:bottom]),
        ]

        # Create clip path for rectangle
        clip_id = "clip_rect_#{@context.object_table.length}"
        path_data = rectangle_to_path(points[0], points[1])

        @svg_builder.add_clip_path(clip_id, path_data)

        # Intersect with existing clip region
        @context.intersect_clip_region(clip_id)
      end

      # Handle EMR_EXCLUDECLIPRECT
      # Creates a new clipping region that excludes the specified rectangle
      def handle_excludecliprect(record)
        rect = record[:rect]
        return unless rect

        # Transform rectangle points
        points = [
          transform_point(rect[:left], rect[:top]),
          transform_point(rect[:right], rect[:bottom]),
        ]

        # Create exclusion clip path
        clip_id = "clip_exclude_#{@context.object_table.length}"
        path_data = rectangle_to_path(points[0], points[1])

        @svg_builder.add_clip_path(clip_id, path_data)

        # Exclude from clip region
        @context.exclude_clip_region(clip_id)
      end

      # Handle EMR_OFFSETCLIPRGN
      # Moves the clipping region by the specified offset
      def handle_offsetcliprgn(record)
        offset = record[:offset]
        return unless offset

        dx = offset[:x] || 0
        dy = offset[:y] || 0

        @context.offset_clip_region(dx, dy)
      end

      # Handle EMR_SETMETARGN
      # Sets the current meta region (not commonly used)
      def handle_setmetargn(_record)
        # Meta region is typically not rendered in SVG
        # This is more for internal GDI state
      end

      private

      # Convert rectangle corners to SVG path data
      def rectangle_to_path(top_left, bottom_right)
        x1 = top_left[:x]
        y1 = top_left[:y]
        x2 = bottom_right[:x]
        y2 = bottom_right[:y]

        "M #{x1} #{y1} L #{x2} #{y1} L #{x2} #{y2} L #{x1} #{y2} Z"
      end
    end
  end
end

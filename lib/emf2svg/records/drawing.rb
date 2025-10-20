# frozen_string_literal: true

require_relative "base"
require_relative "../constants"

module Emf2svg
  module Records
    # Handler for EMF drawing records (polygons, lines, rectangles, ellipses)
    class Drawing < Base
      # Process drawing record
      def process(record)
        case record[:type]
        when :EMR_POLYGON, :EMR_POLYGON16
          process_polygon(record)
        when :EMR_POLYLINE, :EMR_POLYLINE16
          process_polyline(record)
        when :EMR_POLYBEZIER, :EMR_POLYBEZIER16
          process_polybezier(record)
        when :EMR_RECTANGLE
          process_rectangle(record)
        when :EMR_ELLIPSE
          process_ellipse(record)
        when :EMR_ROUNDRECT
          process_roundrect(record)
        when :EMR_MOVETOEX
          process_move_to(record)
        when :EMR_LINETO
          process_line_to(record)
        when :EMR_ARC
          process_arc(record)
        when :EMR_CHORD
          process_chord(record)
        when :EMR_PIE
          process_pie(record)
        when :EMR_ARCTO
          process_arcto(record)
        when :EMR_ANGLEARC
          process_anglearc(record)
        when :EMR_POLYPOLYLINE, :EMR_POLYPOLYLINE16
          process_polypolyline(record)
        when :EMR_POLYPOLYGON, :EMR_POLYPOLYGON16
          process_polypolygon(record)
        end
      end

      private

      def process_polygon(record)
        points = record[:data][:points]
        return if points.empty?

        # Transform points
        transformed_points = transform_points(points)

        # Add polygon to SVG
        @svg_builder.add_polygon(
          transformed_points,
          pen: use_stroke? ? current_pen : nil,
          brush: use_fill? ? current_brush : nil,
          transform: current_transform,
        )
      end

      def process_polyline(record)
        points = record[:data][:points]
        return if points.empty?

        # Transform points
        transformed_points = transform_points(points)

        # Add polyline to SVG
        @svg_builder.add_polyline(
          transformed_points,
          pen: use_stroke? ? current_pen : nil,
          transform: current_transform,
        )
      end

      def process_polybezier(record)
        points = record[:data][:points]
        return if points.empty?

        # Transform points
        transformed_points = transform_points(points)

        # Create Bezier path
        path_data = create_bezier_path(transformed_points)

        # Add path to SVG
        @svg_builder.add_path(
          path_data,
          pen: use_stroke? ? current_pen : nil,
          brush: use_fill? ? current_brush : nil,
          transform: current_transform,
        )
      end

      def process_rectangle(record)
        box = record[:data][:box]
        mapped_box = map_rect(box)

        width = mapped_box[:right] - mapped_box[:left]
        height = mapped_box[:bottom] - mapped_box[:top]

        # Add rectangle to SVG
        @svg_builder.add_rectangle(
          mapped_box[:left],
          mapped_box[:top],
          width,
          height,
          pen: use_stroke? ? current_pen : nil,
          brush: use_fill? ? current_brush : nil,
          transform: current_transform,
        )
      end

      def process_ellipse(record)
        box = record[:data][:box]
        mapped_box = map_rect(box)

        # Calculate center and radii
        cx = (mapped_box[:left] + mapped_box[:right]) / 2.0
        cy = (mapped_box[:top] + mapped_box[:bottom]) / 2.0
        rx = (mapped_box[:right] - mapped_box[:left]) / 2.0
        ry = (mapped_box[:bottom] - mapped_box[:top]) / 2.0

        # Add ellipse to SVG
        @svg_builder.add_ellipse(
          cx, cy, rx, ry,
          pen: use_stroke? ? current_pen : nil,
          brush: use_fill? ? current_brush : nil,
          transform: current_transform
        )
      end

      def process_roundrect(record)
        box = record[:data][:box]
        corner = record[:data][:corner]
        mapped_box = map_rect(box)

        width = mapped_box[:right] - mapped_box[:left]
        height = mapped_box[:bottom] - mapped_box[:top]

        # Calculate corner radii (EMF uses width/height, SVG uses radius)
        rx = corner[:x].abs / 2.0
        ry = corner[:y].abs / 2.0

        # Add rounded rectangle to SVG
        @svg_builder.add_rectangle(
          mapped_box[:left],
          mapped_box[:top],
          width,
          height,
          pen: use_stroke? ? current_pen : nil,
          brush: use_fill? ? current_brush : nil,
          transform: current_transform,
          rx: rx,
          ry: ry,
        )
      end

      def process_move_to(record)
        offset = record[:data][:offset]
        mapped_point = map_coordinates(offset[:x], offset[:y])
        @context.move_to(mapped_point[:x], mapped_point[:y])
      end

      def process_line_to(record)
        point = record[:data][:point]
        mapped_point = map_coordinates(point[:x], point[:y])

        # Get current position
        current_pos = @context.current_position

        # Add line to SVG
        @svg_builder.add_line(
          current_pos[:x],
          current_pos[:y],
          mapped_point[:x],
          mapped_point[:y],
          pen: use_stroke? ? current_pen : nil,
          transform: current_transform,
        )

        # Update current position
        @context.move_to(mapped_point[:x], mapped_point[:y])
      end

      def process_arc(record)
        box = record[:data][:box]
        start_point = record[:data][:start]
        end_point = record[:data][:end]

        path_data = create_arc_path(box, start_point, end_point, closed: false,
                                                                 pie: false)

        @svg_builder.add_path(
          path_data,
          pen: use_stroke? ? current_pen : nil,
          brush: nil,
          transform: current_transform,
        )
      end

      def process_chord(record)
        box = record[:data][:box]
        start_point = record[:data][:start]
        end_point = record[:data][:end]

        path_data = create_arc_path(box, start_point, end_point, closed: true,
                                                                 pie: false)

        @svg_builder.add_path(
          path_data,
          pen: use_stroke? ? current_pen : nil,
          brush: use_fill? ? current_brush : nil,
          transform: current_transform,
        )
      end

      def process_pie(record)
        box = record[:data][:box]
        start_point = record[:data][:start]
        end_point = record[:data][:end]

        path_data = create_arc_path(box, start_point, end_point, closed: true,
                                                                 pie: true)

        @svg_builder.add_path(
          path_data,
          pen: use_stroke? ? current_pen : nil,
          brush: use_fill? ? current_brush : nil,
          transform: current_transform,
        )
      end

      def process_arcto(record)
        box = record[:data][:box]
        start_point = record[:data][:start]
        end_point = record[:data][:end]

        # ArcTo draws from current position to arc
        current_pos = @context.current_position
        path_data = create_arc_path(box, start_point, end_point, closed: false,
                                                                 pie: false, from: current_pos)

        @svg_builder.add_path(
          path_data,
          pen: use_stroke? ? current_pen : nil,
          brush: nil,
          transform: current_transform,
        )

        # Update current position to arc end
        mapped_end = map_coordinates(end_point[:x], end_point[:y])
        @context.move_to(mapped_end[:x], mapped_end[:y])
      end

      def process_anglearc(record)
        # AngleArc draws arc from current position using angle and sweep
        center = record[:data][:center]
        radius = record[:data][:radius]
        start_angle = record[:data][:start_angle]
        sweep_angle = record[:data][:sweep_angle]

        mapped_center = map_coordinates(center[:x], center[:y])

        # Convert angles from degrees to radians
        start_rad = start_angle * Math::PI / 180.0
        sweep_rad = sweep_angle * Math::PI / 180.0

        # Calculate start and end points on circle
        start_x = mapped_center[:x] + radius * Math.cos(start_rad)
        start_y = mapped_center[:y] + radius * Math.sin(start_rad)
        end_rad = start_rad + sweep_rad
        end_x = mapped_center[:x] + radius * Math.cos(end_rad)
        end_y = mapped_center[:y] + radius * Math.sin(end_rad)

        # Get current position
        current_pos = @context.current_position

        # Determine arc flags
        large_arc = sweep_rad.abs > Math::PI ? 1 : 0
        sweep = sweep_rad >= 0 ? 1 : 0

        # Build path: line from current position to arc start, then arc
        path_data = "M #{current_pos[:x]},#{current_pos[:y]}"
        path_data << " L #{start_x},#{start_y}"
        path_data << " A #{radius},#{radius} 0 #{large_arc},#{sweep} #{end_x},#{end_y}"

        @svg_builder.add_path(
          path_data,
          pen: use_stroke? ? current_pen : nil,
          brush: nil,
          transform: current_transform,
        )

        # Update current position to arc end
        @context.move_to(end_x, end_y)
      end

      def process_polypolyline(record)
        poly_counts = record[:data][:poly_counts]
        points = record[:data][:points]

        return unless poly_counts && points

        # Transform all points
        transformed_points = transform_points(points)

        # Draw each polyline
        start_index = 0
        poly_counts.each do |count|
          polyline_points = transformed_points[start_index, count]

          @svg_builder.add_polyline(
            polyline_points,
            pen: use_stroke? ? current_pen : nil,
            transform: current_transform,
          )

          start_index += count
        end
      end

      def process_polypolygon(record)
        poly_counts = record[:data][:poly_counts]
        points = record[:data][:points]

        return unless poly_counts && points

        # Transform all points
        transformed_points = transform_points(points)

        # Draw each polygon
        start_index = 0
        poly_counts.each do |count|
          polygon_points = transformed_points[start_index, count]

          @svg_builder.add_polygon(
            polygon_points,
            pen: use_stroke? ? current_pen : nil,
            brush: use_fill? ? current_brush : nil,
            transform: current_transform,
          )

          start_index += count
        end
      end

      def create_arc_path(box, start_point, end_point, closed:, pie:, from: nil)
        mapped_box = map_rect(box)
        mapped_start = map_coordinates(start_point[:x], start_point[:y])
        mapped_end = map_coordinates(end_point[:x], end_point[:y])

        # Calculate ellipse parameters
        cx = (mapped_box[:left] + mapped_box[:right]) / 2.0
        cy = (mapped_box[:top] + mapped_box[:bottom]) / 2.0
        rx = (mapped_box[:right] - mapped_box[:left]) / 2.0
        ry = (mapped_box[:bottom] - mapped_box[:top]) / 2.0

        # Calculate angles
        start_angle = Math.atan2(mapped_start[:y] - cy, mapped_start[:x] - cx)
        end_angle = Math.atan2(mapped_end[:y] - cy, mapped_end[:x] - cx)

        # Determine sweep direction (always clockwise for EMF)
        sweep = 1
        large_arc = (end_angle - start_angle).abs > Math::PI ? 1 : 0

        # Build path
        path = if from
                 "M #{from[:x]},#{from[:y]} L #{mapped_start[:x]},#{mapped_start[:y]}"
               else
                 "M #{mapped_start[:x]},#{mapped_start[:y]}"
               end

        # Add arc
        path << " A #{rx},#{ry} 0 #{large_arc},#{sweep} #{mapped_end[:x]},#{mapped_end[:y]}"

        # Close path if needed
        if pie
          path << " L #{cx},#{cy} Z"
        elsif closed
          path << " Z"
        end

        path
      end

      def create_bezier_path(points)
        return "" if points.empty?

        # Start at first point
        path = "M #{points[0][:x]},#{points[0][:y]}"

        # Process points in groups of 3 (control1, control2, endpoint)
        i = 1
        while i + 2 < points.length
          cp1 = points[i]
          cp2 = points[i + 1]
          ep = points[i + 2]

          path << " C #{cp1[:x]},#{cp1[:y]} #{cp2[:x]},#{cp2[:y]} #{ep[:x]},#{ep[:y]}"
          i += 3
        end

        path
      end
    end
  end
end

# frozen_string_literal: true

require_relative "base"
require_relative "../constants"

module Emf2svg
  module Records
    # Handler for EMF path records
    class Path < Base
      # Process path record
      def process(record)
        case record[:type]
        when :EMR_BEGINPATH
          process_begin_path(record)
        when :EMR_ENDPATH
          process_end_path(record)
        when :EMR_CLOSEFIGURE
          process_close_figure(record)
        when :EMR_FILLPATH
          process_fill_path(record)
        when :EMR_STROKEPATH
          process_stroke_path(record)
        when :EMR_STROKEANDFILLPATH
          process_stroke_and_fill_path(record)
        when :EMR_SELECTCLIPPATH
          process_select_clip_path(record)
        end
      end

      private

      def process_begin_path(_record)
        @context.begin_path
      end

      def process_end_path(_record)
        @context.end_path
      end

      def process_close_figure(_record)
        @context.add_path_command({ type: :close })
      end

      def process_fill_path(_record)
        return unless @context.in_path?

        # Get path commands and create SVG path
        commands = @context.path_commands
        path_data = build_path_data(commands)

        # Add filled path to SVG
        @svg_builder.add_path(
          path_data,
          brush: use_fill? ? current_brush : nil,
          transform: current_transform,
        )

        # End path
        @context.end_path
      end

      def process_stroke_path(_record)
        return unless @context.in_path?

        # Get path commands and create SVG path
        commands = @context.path_commands
        path_data = build_path_data(commands)

        # Add stroked path to SVG
        @svg_builder.add_path(
          path_data,
          pen: use_stroke? ? current_pen : nil,
          transform: current_transform,
        )

        # End path
        @context.end_path
      end

      def process_stroke_and_fill_path(_record)
        return unless @context.in_path?

        # Get path commands and create SVG path
        commands = @context.path_commands
        path_data = build_path_data(commands)

        # Add path with both stroke and fill to SVG
        @svg_builder.add_path(
          path_data,
          pen: use_stroke? ? current_pen : nil,
          brush: use_fill? ? current_brush : nil,
          transform: current_transform,
        )

        # End path
        @context.end_path
      end

      def process_select_clip_path(_record)
        # TODO: Implement clipping path support
        # For now, just end the current path
        @context.end_path
      end

      def build_path_data(commands)
        path = ""

        commands.each do |cmd|
          case cmd[:type]
          when :move
            path << " M #{cmd[:x]},#{cmd[:y]}"
          when :line
            path << " L #{cmd[:x]},#{cmd[:y]}"
          when :bezier
            path << " C #{cmd[:cp1_x]},#{cmd[:cp1_y]} #{cmd[:cp2_x]},#{cmd[:cp2_y]} #{cmd[:x]},#{cmd[:y]}"
          when :close
            path << " Z"
          end
        end

        path.strip
      end
    end
  end
end

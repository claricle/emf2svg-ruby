# frozen_string_literal: true

require_relative "base"
require_relative "../constants"

module Emf2svg
  module Records
    # Handler for EMF state management records
    class State < Base
      # Process state record
      def process(record)
        case record[:type]
        when :EMR_SAVEDC
          process_save_dc(record)
        when :EMR_RESTOREDC
          process_restore_dc(record)
        when :EMR_SETMAPMODE
          process_set_map_mode(record)
        when :EMR_SETBKMODE
          process_set_background_mode(record)
        when :EMR_SETPOLYFILLMODE
          process_set_poly_fill_mode(record)
        when :EMR_SETTEXTCOLOR
          process_set_text_color(record)
        when :EMR_SETBKCOLOR
          process_set_background_color(record)
        when :EMR_SETWINDOWORGEX
          process_set_window_org(record)
        when :EMR_SETWINDOWEXTEX
          process_set_window_ext(record)
        when :EMR_SETVIEWPORTORGEX
          process_set_viewport_org(record)
        when :EMR_SETVIEWPORTEXTEX
          process_set_viewport_ext(record)
        when :EMR_SETWORLDTRANSFORM
          process_set_world_transform(record)
        when :EMR_MODIFYWORLDTRANSFORM
          process_modify_world_transform(record)
        end
      end

      private

      def process_save_dc(_record)
        @context.save_dc
      end

      def process_restore_dc(record)
        saved_dc = record[:data][:saved_dc]
        @context.restore_dc(saved_dc)
      end

      def process_set_map_mode(record)
        mode = record[:data][:map_mode]
        @context.set_map_mode(mode)
      end

      def process_set_background_mode(record)
        mode = record[:data][:bk_mode]
        @context.set_background_mode(mode)
      end

      def process_set_poly_fill_mode(record)
        mode = record[:data][:poly_fill_mode]
        @context.set_poly_fill_mode(mode)
      end

      def process_set_text_color(record)
        color = record[:data][:color]
        @context.set_text_color(color)
      end

      def process_set_background_color(record)
        color = record[:data][:color]
        @context.set_background_color(color)
      end

      def process_set_window_org(record)
        origin = record[:data][:origin]
        @context.set_window_org(origin[:x], origin[:y])
      end

      def process_set_window_ext(record)
        extent = record[:data][:extent]
        @context.set_window_ext(extent[:cx], extent[:cy])
      end

      def process_set_viewport_org(record)
        origin = record[:data][:origin]
        @context.set_viewport_org(origin[:x], origin[:y])
      end

      def process_set_viewport_ext(record)
        extent = record[:data][:extent]
        @context.set_viewport_ext(extent[:cx], extent[:cy])
      end

      def process_set_world_transform(record)
        xform = record[:data][:xform]
        @context.set_world_transform(xform)
      end

      def process_modify_world_transform(record)
        xform = record[:data][:xform]
        mode = record[:data][:mode]
        @context.modify_world_transform(xform, mode)
      end
    end
  end
end

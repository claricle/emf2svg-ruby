# frozen_string_literal: true

require_relative "transform"
require_relative "constants"

module Emf2svg
  # GDI context manages graphics state during EMF record processing
  class GdiContext
    attr_reader :objects, :selected_pen, :selected_brush, :selected_font,
                :transform, :background_mode, :poly_fill_mode, :map_mode, :text_color, :background_color, :window_org, :window_ext, :viewport_org, :viewport_ext, :current_position, :text_align, :current_font

    def initialize
      @objects = {}
      @dc_stack = []

      # Default pen (black, 1px wide, solid)
      @selected_pen = default_pen
      @selected_brush = default_brush
      @selected_font = default_font

      # Transforms
      @transform = Transform.identity
      @window_org = { x: 0, y: 0 }
      @window_ext = { cx: 0, cy: 0 }
      @viewport_org = { x: 0, y: 0 }
      @viewport_ext = { cx: 0, cy: 0 }

      # Drawing state
      @current_position = { x: 0, y: 0 }
      @background_mode = BK_MODES[:TRANSPARENT]
      @poly_fill_mode = POLY_FILL_MODES[:ALTERNATE]
      @map_mode = MAP_MODES[:MM_TEXT]
      @text_color = { r: 0, g: 0, b: 0 }
      @background_color = { r: 255, g: 255, b: 255 }

      # Text state
      @text_align = 0 # TA_LEFT | TA_TOP
      @current_font = default_font

      # Path state
      @in_path = false
      @path_commands = []

      # Clipping state
      @clip_region = nil
      @clip_regions = []
    end

    # Save current DC state to stack
    def save_dc
      state = {
        selected_pen: @selected_pen.dup,
        selected_brush: @selected_brush.dup,
        selected_font: @selected_font.dup,
        transform: @transform,
        window_org: @window_org.dup,
        window_ext: @window_ext.dup,
        viewport_org: @viewport_org.dup,
        viewport_ext: @viewport_ext.dup,
        current_position: @current_position.dup,
        background_mode: @background_mode,
        poly_fill_mode: @poly_fill_mode,
        map_mode: @map_mode,
        text_color: @text_color.dup,
        background_color: @background_color.dup,
        in_path: @in_path,
        path_commands: @path_commands.dup,
      }
      @dc_stack.push(state)
      @dc_stack.length
    end

    # Restore DC state from stack
    def restore_dc(saved_dc = -1)
      return false if @dc_stack.empty?

      state = if saved_dc == -1
                @dc_stack.pop
              else
                @dc_stack.delete_at(saved_dc - 1)
              end

      return false unless state

      @selected_pen = state[:selected_pen]
      @selected_brush = state[:selected_brush]
      @selected_font = state[:selected_font]
      @transform = state[:transform]
      @window_org = state[:window_org]
      @window_ext = state[:window_ext]
      @viewport_org = state[:viewport_org]
      @viewport_ext = state[:viewport_ext]
      @current_position = state[:current_position]
      @background_mode = state[:background_mode]
      @poly_fill_mode = state[:poly_fill_mode]
      @map_mode = state[:map_mode]
      @text_color = state[:text_color]
      @background_color = state[:background_color]
      @in_path = state[:in_path]
      @path_commands = state[:path_commands]

      true
    end

    # Object table management
    def create_object(index, object)
      @objects[index] = object
    end

    def select_object(index)
      object = @objects[index] || stock_object(index)
      return unless object

      case object[:type]
      when :pen
        @selected_pen = object
      when :brush
        @selected_brush = object
      when :font
        @selected_font = object
      end
    end

    def delete_object(index)
      @objects.delete(index)
    end

    # Transform operations
    def set_world_transform(xform)
      @transform = Transform.from_hash(xform)
    end

    def modify_world_transform(xform, mode)
      new_transform = Transform.from_hash(xform)

      @transform = case mode
                   when MODIFY_WORLD_TRANSFORM_MODES[:MWT_IDENTITY]
                     Transform.identity
                   when MODIFY_WORLD_TRANSFORM_MODES[:MWT_LEFTMULTIPLY]
                     new_transform.multiply(@transform)
                   when MODIFY_WORLD_TRANSFORM_MODES[:MWT_RIGHTMULTIPLY]
                     @transform.multiply(new_transform)
                   else
                     @transform
                   end
    end

    # Viewport/Window mapping
    def set_window_org(x, y)
      @window_org = { x: x, y: y }
    end

    def set_window_ext(cx, cy)
      @window_ext = { cx: cx, cy: cy }
    end

    def set_viewport_org(x, y)
      @viewport_org = { x: x, y: y }
    end

    def set_viewport_ext(cx, cy)
      @viewport_ext = { cx: cx, cy: cy }
    end

    # Drawing state
    def move_to(x, y)
      @current_position = { x: x, y: y }
    end

    def set_background_mode(mode)
      @background_mode = mode
    end

    def set_poly_fill_mode(mode)
      @poly_fill_mode = mode
    end

    def set_map_mode(mode)
      @map_mode = mode
    end

    def set_text_color(color)
      @text_color = color
    end

    def set_background_color(color)
      @background_color = color
    end

    # Text operations
    def set_text_align(align)
      @text_align = align
    end

    def set_text_justification(extra, break_count)
      # Store text justification settings
      # This affects character spacing in justified text
      @text_justification = { extra: extra, break_count: break_count }
    end

    # Path operations
    def begin_path
      @in_path = true
      @path_commands = []
    end

    def end_path
      @in_path = false
    end

    def in_path?
      @in_path
    end

    def add_path_command(command)
      @path_commands << command if @in_path
    end

    def path_commands
      @path_commands.dup
    end

    def current_path
      return nil unless @in_path
      return nil if @path_commands.empty?

      @path_commands.join(" ")
    end

    # Clipping operations
    def set_clip_region(clip_id)
      @clip_region = clip_id
    end

    def intersect_clip_region(clip_id)
      @clip_regions << { type: :intersect, id: clip_id }
      @clip_region = clip_id
    end

    def exclude_clip_region(clip_id)
      @clip_regions << { type: :exclude, id: clip_id }
    end

    def offset_clip_region(dx, dy)
      @clip_offset = { dx: dx, dy: dy } if @clip_region
    end

    def clip_region
      @clip_region
    end

    def clip_regions
      @clip_regions.dup
    end

    private

    def default_pen
      {
        type: :pen,
        style: PEN_STYLES[:PS_SOLID],
        width: 1,
        color: { r: 0, g: 0, b: 0 },
      }
    end

    def default_brush
      {
        type: :brush,
        style: BRUSH_STYLES[:BS_NULL],
        color: { r: 255, g: 255, b: 255 },
        hatch: 0,
      }
    end

    def default_font
      {
        type: :font,
        height: 12,
        weight: FONT_WEIGHTS[:FW_NORMAL],
        italic: false,
        underline: false,
        strikeout: false,
        charset: 0,
        facename: "Arial",
      }
    end

    def stock_object(index)
      # Stock object indices
      case index
      when 0x80000000 # WHITE_BRUSH
        { type: :brush, style: BRUSH_STYLES[:BS_SOLID],
          color: { r: 255, g: 255, b: 255 }, hatch: 0 }
      when 0x80000001 # LTGRAY_BRUSH
        { type: :brush, style: BRUSH_STYLES[:BS_SOLID],
          color: { r: 192, g: 192, b: 192 }, hatch: 0 }
      when 0x80000002 # GRAY_BRUSH
        { type: :brush, style: BRUSH_STYLES[:BS_SOLID],
          color: { r: 128, g: 128, b: 128 }, hatch: 0 }
      when 0x80000003 # DKGRAY_BRUSH
        { type: :brush, style: BRUSH_STYLES[:BS_SOLID],
          color: { r: 64, g: 64, b: 64 }, hatch: 0 }
      when 0x80000004 # BLACK_BRUSH
        { type: :brush, style: BRUSH_STYLES[:BS_SOLID],
          color: { r: 0, g: 0, b: 0 }, hatch: 0 }
      when 0x80000005 # NULL_BRUSH
        { type: :brush, style: BRUSH_STYLES[:BS_NULL],
          color: { r: 0, g: 0, b: 0 }, hatch: 0 }
      when 0x80000006 # WHITE_PEN
        { type: :pen, style: PEN_STYLES[:PS_SOLID], width: 1,
          color: { r: 255, g: 255, b: 255 } }
      when 0x80000007 # BLACK_PEN
        { type: :pen, style: PEN_STYLES[:PS_SOLID], width: 1,
          color: { r: 0, g: 0, b: 0 } }
      when 0x80000008 # NULL_PEN
        { type: :pen, style: PEN_STYLES[:PS_NULL], width: 0,
          color: { r: 0, g: 0, b: 0 } }
      end
    end
  end
end

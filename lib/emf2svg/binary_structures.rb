# frozen_string_literal: true

require "bindata"

module Emf2svg
  module BinaryStructures
    # Base class for EMF binary structures
    class EmfBase < BinData::Record
      endian :little
    end

    # Point structure (POINTL in Windows API)
    class Point < EmfBase
      int32 :x
      int32 :y
    end

    # Rectangle structure (RECTL in Windows API)
    class Rect < EmfBase
      int32 :left
      int32 :top
      int32 :right
      int32 :bottom
    end

    # Size structure (SIZEL in Windows API)
    class Size < EmfBase
      int32 :cx
      int32 :cy
    end

    # Color structure (COLORREF in Windows API)
    class ColorRef < EmfBase
      uint8 :red
      uint8 :green
      uint8 :blue
      uint8 :reserved
    end

    # EMF Header structure
    class EmfHeader < EmfBase
      uint32 :record_type   # Must be 0x00000001 (EMR_HEADER)
      uint32 :record_size   # Size of this record in bytes
      rect   :bounds        # Inclusive-inclusive bounds in device units
      rect   :frame         # Inclusive-inclusive picture frame in 0.01mm units
      uint32 :signature     # Must be 0x464D4520 (" EMF")
      uint32 :version       # Version number of the metafile
      uint32 :bytes         # Size of the metafile in bytes
      uint32 :records       # Number of records in the metafile
      uint16 :handles       # Number of handles in handle table
      uint16 :reserved      # Reserved, must be 0
      uint32 :n_description # Number of chars in description
      uint32 :off_description # Offset to description string
      uint32 :n_pal_entries # Number of palette entries
      size   :device        # Size of reference device in pixels
      size   :millimeters   # Size of reference device in millimeters
    end

    # Base EMF record structure
    class EmfRecord < EmfBase
      uint32 :record_type
      uint32 :record_size
      string :data, read_length: -> { record_size - 8 }
    end

    # Point16 structure for 16-bit coordinates (defined before EmrPoly16)
    class Point16 < EmfBase
      int16 :x
      int16 :y
    end

    # EMR_POLYGON and EMR_POLYLINE structure
    class EmrPoly < EmfBase
      uint32 :record_type
      uint32 :record_size
      rect   :bounds
      uint32 :num_points
      array  :points, type: :point, initial_length: :num_points
    end

    # EMR_POLYGON16 and EMR_POLYLINE16 structure
    class EmrPoly16 < EmfBase
      uint32 :record_type
      uint32 :record_size
      rect   :bounds
      uint32 :num_points
      array  :points, type: :point16, initial_length: :num_points
    end

    # EMR_POLYPOLYGON structure
    class EmrPolyPolygon < EmfBase
      uint32 :record_type
      uint32 :record_size
      rect   :bounds
      uint32 :num_polys
      uint32 :total_points
      array  :poly_counts, type: :uint32, initial_length: :num_polys
      array  :points, type: :point, initial_length: :total_points
    end

    # EMR_POLYPOLYGON16 structure
    class EmrPolyPolygon16 < EmfBase
      uint32 :record_type
      uint32 :record_size
      rect   :bounds
      uint32 :num_polys
      uint32 :total_points
      array  :poly_counts, type: :uint32, initial_length: :num_polys
      array  :points, type: :point16, initial_length: :total_points
    end

    # EMR_RECTANGLE structure
    class EmrRectangle < EmfBase
      uint32 :record_type
      uint32 :record_size
      rect   :box
    end

    # EMR_ELLIPSE structure
    class EmrEllipse < EmfBase
      uint32 :record_type
      uint32 :record_size
      rect   :box
    end

    # EMR_SETWINDOWEXTEX, EMR_SETVIEWPORTEXTEX structure
    class EmrSetExtEx < EmfBase
      uint32 :record_type
      uint32 :record_size
      size   :extent
    end

    # EMR_SETWINDOWORGEX, EMR_SETVIEWPORTORGEX structure
    class EmrSetOrgEx < EmfBase
      uint32 :record_type
      uint32 :record_size
      point  :origin
    end

    # EMR_SAVEDC structure
    class EmrSaveDc < EmfBase
      uint32 :record_type
      uint32 :record_size
    end

    # EMR_RESTOREDC structure
    class EmrRestoreDc < EmfBase
      uint32 :record_type
      uint32 :record_size
      int32  :saved_dc
    end

    # EMR_SELECTOBJECT structure
    class EmrSelectObject < EmfBase
      uint32 :record_type
      uint32 :record_size
      uint32 :ih_object
    end

    # EMR_DELETEOBJECT structure
    class EmrDeleteObject < EmfBase
      uint32 :record_type
      uint32 :record_size
      uint32 :ih_object
    end

    # EMR_CREATEPEN structure
    class EmrCreatePen < EmfBase
      uint32    :record_type
      uint32    :record_size
      uint32    :ih_pen
      uint32    :style
      point     :width
      color_ref :color
    end

    # EMR_CREATEBRUSHINDIRECT structure
    class EmrCreateBrushIndirect < EmfBase
      uint32    :record_type
      uint32    :record_size
      uint32    :ih_brush
      uint32    :style
      color_ref :color
      uint32    :hatch
    end

    # EMR_SETTEXTCOLOR structure
    class EmrSetTextColor < EmfBase
      uint32    :record_type
      uint32    :record_size
      color_ref :color
    end

    # EMR_SETBKCOLOR structure
    class EmrSetBkColor < EmfBase
      uint32    :record_type
      uint32    :record_size
      color_ref :color
    end

    # EMR_SETBKMODE structure
    class EmrSetBkMode < EmfBase
      uint32 :record_type
      uint32 :record_size
      uint32 :bk_mode
    end

    # EMR_SETPOLYFILLMODE structure
    class EmrSetPolyFillMode < EmfBase
      uint32 :record_type
      uint32 :record_size
      uint32 :poly_fill_mode
    end

    # EMR_SETMAPMODE structure
    class EmrSetMapMode < EmfBase
      uint32 :record_type
      uint32 :record_size
      uint32 :map_mode
    end

    # XFORM structure for world transformation
    class XForm < EmfBase
      float :m11  # Horizontal scaling
      float :m12  # Horizontal shearing
      float :m21  # Vertical shearing
      float :m22  # Vertical scaling
      float :dx   # Horizontal translation
      float :dy   # Vertical translation
    end

    # EMR_SETWORLDTRANSFORM structure
    class EmrSetWorldTransform < EmfBase
      uint32 :record_type
      uint32 :record_size
      x_form :xform
    end

    # EMR_MODIFYWORLDTRANSFORM structure
    class EmrModifyWorldTransform < EmfBase
      uint32 :record_type
      uint32 :record_size
      x_form :xform
      uint32 :mode
    end

    # EMR_BEGINPATH structure
    class EmrBeginPath < EmfBase
      uint32 :record_type
      uint32 :record_size
    end

    # EMR_ENDPATH structure
    class EmrEndPath < EmfBase
      uint32 :record_type
      uint32 :record_size
    end

    # EMR_CLOSEFIGURE structure
    class EmrCloseFigure < EmfBase
      uint32 :record_type
      uint32 :record_size
    end

    # EMR_FILLPATH structure
    class EmrFillPath < EmfBase
      uint32 :record_type
      uint32 :record_size
      rect   :bounds
    end

    # EMR_STROKEPATH structure
    class EmrStrokePath < EmfBase
      uint32 :record_type
      uint32 :record_size
      rect   :bounds
    end

    # EMR_STROKEANDFILLPATH structure
    class EmrStrokeAndFillPath < EmfBase
      uint32 :record_type
      uint32 :record_size
      rect   :bounds
    end

    # EMR_SELECTCLIPPATH structure
    class EmrSelectClipPath < EmfBase
      uint32 :record_type
      uint32 :record_size
      uint32 :rgn_mode
    end

    # EMR_MOVETOEX structure
    class EmrMoveToEx < EmfBase
      uint32 :record_type
      uint32 :record_size
      point  :offset
    end

    # EMR_LINETO structure
    class EmrLineTo < EmfBase
      uint32 :record_type
      uint32 :record_size
      point  :point
    end

    # EMR_EOF structure
    class EmrEof < EmfBase
      uint32 :record_type
      uint32 :record_size
      uint32 :n_pal_entries
      uint32 :off_pal_entries
      uint32 :size_last
    end

    # LOGFONTEXW structure
    class LogFontExW < EmfBase
      int32  :height
      int32  :width
      int32  :escapement
      int32  :orientation
      int32  :weight
      uint8  :italic
      uint8  :underline
      uint8  :strike_out
      uint8  :char_set
      uint8  :out_precision
      uint8  :clip_precision
      uint8  :quality
      uint8  :pitch_and_family
      string :face_name, length: 64 # UTF-16LE, 32 characters
    end

    # EMR_EXTCREATEFONTINDIRECTW structure
    class EmrExtCreateFontIndirectW < EmfBase
      uint32       :record_type
      uint32       :record_size
      uint32       :ih_font
      log_font_ex_w :elfw
    end

    # EMRTEXT structure for text output
    class EmrText < EmfBase
      point  :reference
      uint32 :chars
      uint32 :off_string
      uint32 :options
      rect   :rectangle
      uint32 :off_dx
    end

    # EMR_EXTTEXTOUTW structure
    class EmrExtTextOutW < EmfBase
      uint32   :record_type
      uint32   :record_size
      rect     :bounds
      uint32   :i_graphics_mode
      float    :ex_scale
      float    :ey_scale
      emr_text :w_emr_text
      # Variable-length data follows
    end

    # Helper method to create appropriate record structure based on type
    def self.create_record(type, io)
      case Emf2svg::EMF_RECORD_TYPES[type]
      when :EMR_HEADER
        EmfHeader.read(io)
      when :EMR_POLYGON, :EMR_POLYLINE, :EMR_POLYBEZIER
        EmrPoly.read(io)
      when :EMR_POLYGON16, :EMR_POLYLINE16, :EMR_POLYBEZIER16
        EmrPoly16.read(io)
      when :EMR_RECTANGLE
        EmrRectangle.read(io)
      when :EMR_ELLIPSE
        EmrEllipse.read(io)
      when :EMR_SAVEDC
        EmrSaveDc.read(io)
      when :EMR_RESTOREDC
        EmrRestoreDc.read(io)
      when :EMR_SELECTOBJECT
        EmrSelectObject.read(io)
      when :EMR_DELETEOBJECT
        EmrDeleteObject.read(io)
      when :EMR_CREATEPEN
        EmrCreatePen.read(io)
      when :EMR_CREATEBRUSHINDIRECT
        EmrCreateBrushIndirect.read(io)
      when :EMR_SETTEXTCOLOR
        EmrSetTextColor.read(io)
      when :EMR_SETBKCOLOR
        EmrSetBkColor.read(io)
      when :EMR_SETBKMODE
        EmrSetBkMode.read(io)
      when :EMR_SETPOLYFILLMODE
        EmrSetPolyFillMode.read(io)
      when :EMR_SETMAPMODE
        EmrSetMapMode.read(io)
      when :EMR_SETWORLDTRANSFORM
        EmrSetWorldTransform.read(io)
      when :EMR_MODIFYWORLDTRANSFORM
        EmrModifyWorldTransform.read(io)
      when :EMR_BEGINPATH
        EmrBeginPath.read(io)
      when :EMR_ENDPATH
        EmrEndPath.read(io)
      when :EMR_CLOSEFIGURE
        EmrCloseFigure.read(io)
      when :EMR_FILLPATH
        EmrFillPath.read(io)
      when :EMR_STROKEPATH
        EmrStrokePath.read(io)
      when :EMR_STROKEANDFILLPATH
        EmrStrokeAndFillPath.read(io)
      when :EMR_SELECTCLIPPATH
        EmrSelectClipPath.read(io)
      when :EMR_MOVETOEX
        EmrMoveToEx.read(io)
      when :EMR_LINETO
        EmrLineTo.read(io)
      when :EMR_SETWINDOWEXTEX, :EMR_SETVIEWPORTEXTEX
        EmrSetExtEx.read(io)
      when :EMR_SETWINDOWORGEX, :EMR_SETVIEWPORTORGEX
        EmrSetOrgEx.read(io)
      when :EMR_EXTCREATEFONTINDIRECTW
        EmrExtCreateFontIndirectW.read(io)
      when :EMR_EXTTEXTOUTW
        EmrExtTextOutW.read(io)
      when :EMR_EOF
        EmrEof.read(io)
      else
        # Generic record for unknown types
        EmfRecord.read(io)
      end
    end
  end
end

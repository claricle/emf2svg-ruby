# frozen_string_literal: true

require "chunky_png"
require "base64"

module Emf2svg
  module Records
    # Handler for bitmap-related EMF records
    class Bitmap < Base
      # Process bitmap record
      def process(record)
        case record[:type]
        when :EMR_BITBLT
          handle_bitblt(record)
        when :EMR_STRETCHBLT
          handle_stretchblt(record)
        when :EMR_STRETCHDIBITS
          handle_stretchdibits(record)
        end
      end

      # Handle EMR_BITBLT
      # Transfers a block of pixels from source to destination
      def handle_bitblt(record)
        # BitBlt parameters
        bounds = record[:bounds]
        dest_x = record[:x_dest]
        dest_y = record[:y_dest]
        width = record[:cx_dest]
        height = record[:cy_dest]

        # ROP (Raster Operation) code
        record[:rop]

        # Source bitmap data (if present)
        bitmap_data = record[:bitmap_data]

        return unless bitmap_data && bounds

        # Convert DIB to PNG
        png_data = dib_to_png(bitmap_data, width, height)
        return unless png_data

        # Transform destination coordinates
        dest_point = transform_point(dest_x, dest_y)

        # Embed bitmap in SVG as data URI
        data_uri = "data:image/png;base64,#{Base64.strict_encode64(png_data)}"

        # Create image element
        add_image(
          dest_point[:x],
          dest_point[:y],
          width,
          height,
          data_uri,
        )
      end

      # Handle EMR_STRETCHBLT
      # Transfers a block of pixels with stretching/compression
      def handle_stretchblt(record)
        # StretchBlt parameters
        bounds = record[:bounds]
        dest_x = record[:x_dest]
        dest_y = record[:y_dest]
        dest_width = record[:cx_dest]
        dest_height = record[:cy_dest]

        record[:x_src] || 0
        record[:y_src] || 0
        src_width = record[:cx_src] || dest_width
        src_height = record[:cy_src] || dest_height

        # ROP code
        record[:rop]

        # Source bitmap data
        bitmap_data = record[:bitmap_data]

        return unless bitmap_data && bounds

        # Convert DIB to PNG
        png_data = dib_to_png(bitmap_data, src_width, src_height)
        return unless png_data

        # Transform destination coordinates
        dest_point = transform_point(dest_x, dest_y)

        # Embed bitmap in SVG as data URI
        data_uri = "data:image/png;base64,#{Base64.strict_encode64(png_data)}"

        # Create image element with destination dimensions
        add_image(
          dest_point[:x],
          dest_point[:y],
          dest_width,
          dest_height,
          data_uri,
        )
      end

      # Handle EMR_STRETCHDIBITS
      # Copies a DIB to destination rectangle
      def handle_stretchdibits(record)
        bounds = record[:bounds]
        dest_x = record[:x_dest]
        dest_y = record[:y_dest]
        dest_width = record[:cx_dest]
        dest_height = record[:cy_dest]

        record[:x_src] || 0
        record[:y_src] || 0
        src_width = record[:cx_src] || dest_width
        src_height = record[:cy_src] || dest_height

        dib_data = record[:dib_data]

        return unless dib_data && bounds

        # Convert DIB to PNG
        png_data = dib_to_png(dib_data, src_width, src_height)
        return unless png_data

        # Transform destination coordinates
        dest_point = transform_point(dest_x, dest_y)

        # Embed bitmap in SVG
        data_uri = "data:image/png;base64,#{Base64.strict_encode64(png_data)}"

        add_image(
          dest_point[:x],
          dest_point[:y],
          dest_width,
          dest_height,
          data_uri,
        )
      end

      private

      # Convert DIB (Device Independent Bitmap) to PNG
      def dib_to_png(dib_data, _width, _height)
        return nil if dib_data.nil? || dib_data.empty?

        begin
          # Parse BITMAPINFOHEADER
          header = parse_bitmap_info_header(dib_data)
          return nil unless header

          # Calculate offsets
          header_size = header[:size]
          color_table_size = calculate_color_table_size(header)
          pixel_data_offset = header_size + color_table_size

          # Parse color table if present
          color_table = nil
          if color_table_size.positive?
            color_table = parse_color_table(dib_data, header_size,
                                            header[:colors_used] || (1 << header[:bit_count]))
          end

          # Extract pixel data
          pixel_data = dib_data[pixel_data_offset..]
          return nil unless pixel_data

          # Create image from pixel data
          image = create_image_from_pixels(
            pixel_data,
            header[:width],
            header[:height].abs,
            header[:bit_count],
            header[:compression],
            color_table,
          )

          # Convert to PNG
          image&.to_blob
        rescue StandardError => e
          warn "Failed to convert DIB to PNG: #{e.message}" if ENV["EMF2SVG_DEBUG"]
          warn e.backtrace.join("\n") if ENV["EMF2SVG_DEBUG"]
          nil
        end
      end

      # Parse BITMAPINFOHEADER structure
      def parse_bitmap_info_header(data)
        return nil if data.length < 40

        header = {}
        header[:size] = data[0, 4].unpack1("L<")
        header[:width] = data[4, 4].unpack1("l<")
        header[:height] = data[8, 4].unpack1("l<")
        header[:planes] = data[12, 2].unpack1("S<")
        header[:bit_count] = data[14, 2].unpack1("S<")
        header[:compression] = data[16, 4].unpack1("L<")
        header[:size_image] = data[20, 4].unpack1("L<")
        header[:x_pels_per_meter] = data[24, 4].unpack1("l<")
        header[:y_pels_per_meter] = data[28, 4].unpack1("l<")
        header[:colors_used] = data[32, 4].unpack1("L<")
        header[:colors_important] = data[36, 4].unpack1("L<")

        header
      end

      # Calculate color table size in bytes
      def calculate_color_table_size(header)
        # Color table only present for <= 8 bit images
        return 0 if header[:bit_count] > 8

        # Number of colors
        num_colors = header[:colors_used]
        num_colors = (1 << header[:bit_count]) if num_colors.zero?

        # Each color entry is 4 bytes (RGBQUAD: blue, green, red, reserved)
        num_colors * 4
      end

      # Parse color table (palette)
      def parse_color_table(data, offset, num_colors)
        colors = []
        num_colors.times do |i|
          pos = offset + (i * 4)
          break if pos + 3 >= data.length

          # RGBQUAD: blue, green, red, reserved
          b = data[pos].ord
          g = data[pos + 1].ord
          r = data[pos + 2].ord

          colors << ChunkyPNG::Color.rgb(r, g, b)
        end
        colors
      end

      # Create ChunkyPNG image from pixel data
      def create_image_from_pixels(pixel_data, width, height, bit_count,
_compression, color_table)
        # Handle bottom-up bitmap (height is negative for top-down)
        bottom_up = height.positive?
        height = height.abs

        image = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::TRANSPARENT)

        # Calculate row size (must be multiple of 4 bytes)
        row_size = ((width * bit_count + 31) / 32) * 4

        case bit_count
        when 1
          decode_1bit_pixels(image, pixel_data, width, height, row_size,
                             color_table, bottom_up)
        when 4
          decode_4bit_pixels(image, pixel_data, width, height, row_size,
                             color_table, bottom_up)
        when 8
          decode_8bit_pixels(image, pixel_data, width, height, row_size,
                             color_table, bottom_up)
        when 24
          decode_24bit_pixels(image, pixel_data, width, height, row_size,
                              bottom_up)
        when 32
          decode_32bit_pixels(image, pixel_data, width, height, row_size,
                              bottom_up)
        else
          warn "Unsupported bit depth: #{bit_count}" if ENV["EMF2SVG_DEBUG"]
          return nil
        end

        image
      end

      # Decode 1-bit pixels
      def decode_1bit_pixels(image, data, width, height, row_size, color_table,
bottom_up)
        height.times do |y|
          row_offset = y * row_size
          actual_y = bottom_up ? (height - 1 - y) : y

          width.times do |x|
            byte_index = row_offset + (x / 8)
            bit_index = 7 - (x % 8)

            break if byte_index >= data.length

            pixel_value = (data[byte_index].ord >> bit_index) & 1
            color = if color_table
                      color_table[pixel_value]
                    else
                      (pixel_value.zero? ? ChunkyPNG::Color::BLACK : ChunkyPNG::Color::WHITE)
                    end

            image[x, actual_y] = color
          end
        end
      end

      # Decode 4-bit pixels
      def decode_4bit_pixels(image, data, width, height, row_size, color_table,
bottom_up)
        height.times do |y|
          row_offset = y * row_size
          actual_y = bottom_up ? (height - 1 - y) : y

          width.times do |x|
            byte_index = row_offset + (x / 2)
            break if byte_index >= data.length

            byte = data[byte_index].ord
            pixel_value = (x.even? ? (byte >> 4) : byte) & 0x0F

            color = color_table ? color_table[pixel_value] : ChunkyPNG::Color::grayscale(pixel_value * 17)
            image[x, actual_y] = color
          end
        end
      end

      # Decode 8-bit pixels
      def decode_8bit_pixels(image, data, width, height, row_size, color_table,
bottom_up)
        height.times do |y|
          row_offset = y * row_size
          actual_y = bottom_up ? (height - 1 - y) : y

          width.times do |x|
            index = row_offset + x
            break if index >= data.length

            pixel_value = data[index].ord
            color = color_table ? color_table[pixel_value] : ChunkyPNG::Color::grayscale(pixel_value)

            image[x, actual_y] = color
          end
        end
      end

      # Decode 24-bit pixels
      def decode_24bit_pixels(image, data, width, height, row_size, bottom_up)
        height.times do |y|
          row_offset = y * row_size
          actual_y = bottom_up ? (height - 1 - y) : y

          width.times do |x|
            pixel_offset = row_offset + (x * 3)
            break if pixel_offset + 2 >= data.length

            # BGR format
            b = data[pixel_offset].ord
            g = data[pixel_offset + 1].ord
            r = data[pixel_offset + 2].ord

            image[x, actual_y] = ChunkyPNG::Color.rgb(r, g, b)
          end
        end
      end

      # Decode 32-bit pixels
      def decode_32bit_pixels(image, data, width, height, row_size, bottom_up)
        height.times do |y|
          row_offset = y * row_size
          actual_y = bottom_up ? (height - 1 - y) : y

          width.times do |x|
            pixel_offset = row_offset + (x * 4)
            break if pixel_offset + 3 >= data.length

            # BGRA format
            b = data[pixel_offset].ord
            g = data[pixel_offset + 1].ord
            r = data[pixel_offset + 2].ord
            a = data[pixel_offset + 3].ord

            image[x, actual_y] = ChunkyPNG::Color.rgba(r, g, b, a)
          end
        end
      end

      # Add image element to SVG
      def add_image(x, y, width, height, href)
        # Get current transform
        transform_str = @context.transform.to_svg_matrix

        @svg_builder.add_image(
          x,
          y,
          width,
          height,
          href,
          transform: transform_str,
        )
      end
    end
  end
end

# frozen_string_literal: true

module Emf2svg
  # 2D transformation matrix for coordinate transformations
  # Represents a 3x3 matrix in the form:
  # | m11  m12  0 |
  # | m21  m22  0 |
  # | dx   dy   1 |
  class Transform
    attr_reader :m11, :m12, :m21, :m22, :dx, :dy

    # Create identity transform
    def self.identity
      new(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
    end

    # Create translation transform
    def self.translate(dx, dy)
      new(1.0, 0.0, 0.0, 1.0, dx, dy)
    end

    # Create scaling transform
    def self.scale(sx, sy)
      new(sx, 0.0, 0.0, sy, 0.0, 0.0)
    end

    # Create rotation transform (angle in radians)
    def self.rotate(angle)
      cos_a = Math.cos(angle)
      sin_a = Math.sin(angle)
      new(cos_a, sin_a, -sin_a, cos_a, 0.0, 0.0)
    end

    def initialize(m11, m12, m21, m22, dx, dy)
      @m11 = m11.to_f
      @m12 = m12.to_f
      @m21 = m21.to_f
      @m22 = m22.to_f
      @dx = dx.to_f
      @dy = dy.to_f
    end

    # Multiply this transform by another (self * other)
    def multiply(other)
      Transform.new(
        @m11 * other.m11 + @m12 * other.m21,
        @m11 * other.m12 + @m12 * other.m22,
        @m21 * other.m11 + @m22 * other.m21,
        @m21 * other.m12 + @m22 * other.m22,
        @dx * other.m11 + @dy * other.m21 + other.dx,
        @dx * other.m12 + @dy * other.m22 + other.dy,
      )
    end

    # Transform a point
    def transform_point(x, y)
      {
        x: @m11 * x + @m21 * y + @dx,
        y: @m12 * x + @m22 * y + @dy,
      }
    end

    # Transform multiple points
    def transform_points(points)
      points.map { |p| transform_point(p[:x], p[:y]) }
    end

    # Calculate determinant
    def determinant
      @m11 * @m22 - @m12 * @m21
    end

    # Invert the transform
    def invert
      det = determinant
      raise Error, "Transform is not invertible" if det.abs < 1e-10

      inv_det = 1.0 / det
      Transform.new(
        @m22 * inv_det,
        -@m12 * inv_det,
        -@m21 * inv_det,
        @m11 * inv_det,
        (@m21 * @dy - @m22 * @dx) * inv_det,
        (@m12 * @dx - @m11 * @dy) * inv_det,
      )
    end

    # Check if transform is identity
    def identity?
      (@m11 - 1.0).abs < 1e-10 &&
        @m12.abs < 1e-10 &&
        @m21.abs < 1e-10 &&
        (@m22 - 1.0).abs < 1e-10 &&
        @dx.abs < 1e-10 &&
        @dy.abs < 1e-10
    end

    # Convert to SVG matrix transform string
    def to_svg
      return nil if identity?

      "matrix(#{@m11},#{@m12},#{@m21},#{@m22},#{@dx},#{@dy})"
    end

    # Create transform from hash
    def self.from_hash(hash)
      new(
        hash[:m11] || 1.0,
        hash[:m12] || 0.0,
        hash[:m21] || 0.0,
        hash[:m22] || 1.0,
        hash[:dx] || 0.0,
        hash[:dy] || 0.0,
      )
    end

    def to_s
      "Transform(m11=#{@m11}, m12=#{@m12}, m21=#{@m21}, m22=#{@m22}, dx=#{@dx}, dy=#{@dy})"
    end
  end
end

# EMF2SVG Pure Ruby Implementation Plan

## Overview

Port emf2svg to **pure Ruby** without C extensions - using Ruby gems for binary parsing.

## Why Pure Ruby?

### Advantages
✅ **No compilation needed** - works on any Ruby platform
✅ **Easier debugging** - can use standard Ruby debugging tools
✅ **Simpler maintenance** - all code in one language
✅ **More portable** - no platform-specific builds
✅ **Easier testing** - can mock/stub binary structures
✅ **Better for JRuby/TruffleRuby** - no C dependency issues

### Trade-offs
⚠️ **Performance**: ~40-60% of C speed (acceptable for most use cases)
⚠️ **Memory**: Slightly higher memory usage
✅ **Mitigation**: Profile and optimize hot paths, consider caching

## Architecture

```
┌─────────────────────────────────────────────────┐
│         Pure Ruby Implementation                │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│   API Layer                                     │
│   Emf2svg.from_file / .from_binary_string       │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   Binary Parser (BinData gem)                   │
│   • EMF header parsing                          │
│   • Record extraction                           │
│   • Structure definitions                       │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   Record Handlers (Pure Ruby)                   │
│   • Drawing, Text, Path, Bitmap, etc.           │
│   • Each record type has handler class          │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   GDI Context & Transform (Pure Ruby)           │
│   • State management                            │
│   • Coordinate transformations                  │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│   SVG Builder (Pure Ruby)                       │
│   • SVG DOM construction                        │
│   • Output generation                           │
└─────────────────────────────────────────────────┘
```

## Dependencies

```ruby
# Gemspec
spec.add_dependency "bindata", "~> 2.5"      # Binary structure parsing
spec.add_dependency "oily_png", "~> 1.2"     # PNG manipulation (has C, but pure Ruby fallback)
# OR
spec.add_dependency "chunky_png", "~> 1.4"   # Pure Ruby PNG (slower but works everywhere)
```

## Binary Parsing with BinData

### EMF Record Structures

```ruby
require 'bindata'

module Emf2svg
  module BinaryStructures
    # Base EMF record
    class EmfRecord < BinData::Record
      endian :little

      uint32 :type        # EMR_* type
      uint32 :size        # Record size in bytes
      string :data, read_length: -> { size - 8 }
    end

    # EMF Header
    class EmfHeader < BinData::Record
      endian :little

      uint32 :type        # Must be 0x00000001 (EMR_HEADER)
      uint32 :size
      int32  :bounds_left
      int32  :bounds_top
      int32  :bounds_right
      int32  :bounds_bottom
      int32  :frame_left
      int32  :frame_top
      int32  :frame_right
      int32  :frame_bottom
      uint32 :signature   # Must be 0x464D4520 (" EMF")
      uint32 :version
      uint32 :bytes       # Size of file in bytes
      uint32 :records     # Number of records
      uint16 :handles     # Number of handles
      uint16 :reserved
      uint32 :n_description
      uint32 :off_description
      uint32 :n_pal_entries
      int32  :device_cx
      int32  :device_cy
      int32  :millimeters_cx
      int32  :millimeters_cy
    end

    # Point structure
    class Point < BinData::Record
      endian :little
      int32 :x
      int32 :y
    end

    # Rectangle structure
    class Rect < BinData::Record
      endian :little
      int32 :left
      int32 :top
      int32 :right
      int32 :bottom
    end

    # Polygon record
    class EmrPolygon < BinData::Record
      endian :little

      uint32 :type
      uint32 :size
      rect   :bounds
      uint32 :count
      array  :points, type: :point, initial_length: :count
    end

    # Add more structures for each EMF record type...
  end
end
```

### Parser Implementation

```ruby
module Emf2svg
  class Parser
    def initialize(binary_data)
      @data = binary_data
      @io = StringIO.new(binary_data)
      @records = []
    end

    def parse
      # Read header
      @header = BinaryStructures::EmfHeader.read(@io)
      validate_header!

      # Read all records
      while @io.pos < @data.bytesize
        record = parse_next_record
        break if record.nil? || record[:type] == :EMR_EOF
        @records << record
      end

      @records
    end

    def header_info
      {
        width: @header.bounds_right - @header.bounds_left,
        height: @header.bounds_bottom - @header.bounds_top,
        dpi_x: (@header.device_cx * 25.4) / @header.millimeters_cx,
        dpi_y: (@header.device_cy * 25.4) / @header.millimeters_cy,
        bounds: {
          left: @header.bounds_left,
          top: @header.bounds_top,
          right: @header.bounds_right,
          bottom: @header.bounds_bottom
        }
      }
    end

    private

    def parse_next_record
      start_pos = @io.pos

      # Read record type and size
      type_num = @io.read(4).unpack1('L<')
      size = @io.read(4).unpack1('L<')

      # Rewind to read full record
      @io.seek(start_pos)

      # Parse based on type
      record_type = EMF_RECORD_TYPES[type_num]

      case record_type
      when :EMR_POLYGON
        parse_polygon
      when :EMR_POLYLINE
        parse_polyline
      when :EMR_RECTANGLE
        parse_rectangle
      # ... handle all record types
      else
        parse_generic_record(type_num, size)
      end
    end

    def parse_polygon
      record = BinaryStructures::EmrPolygon.read(@io)
      {
        type: :EMR_POLYGON,
        bounds: rect_to_hash(record.bounds),
        points: record.points.map { |p| {x: p.x, y: p.y} }
      }
    end

    def validate_header!
      raise "Invalid EMF signature" unless @header.signature == 0x464D4520
      raise "Invalid EMF type" unless @header.type == 0x00000001
    end
  end
end
```

## Record Type Definitions

```ruby
module Emf2svg
  # EMF Record Type Constants (from MS-EMF spec)
  EMF_RECORD_TYPES = {
    0x00000001 => :EMR_HEADER,
    0x00000002 => :EMR_POLYBEZIER,
    0x00000003 => :EMR_POLYGON,
    0x00000004 => :EMR_POLYLINE,
    0x00000005 => :EMR_POLYBEZIERTO,
    0x00000006 => :EMR_POLYLINETO,
    0x00000007 => :EMR_POLYPOLYLINE,
    0x00000008 => :EMR_POLYPOLYGON,
    0x00000009 => :EMR_SETWINDOWEXTEX,
    0x0000000A => :EMR_SETWINDOWORGEX,
    0x0000000B => :EMR_SETVIEWPORTEXTEX,
    0x0000000C => :EMR_SETVIEWPORTORGEX,
    0x0000000D => :EMR_SETBRUSHORGEX,
    0x0000000E => :EMR_EOF,
    # ... (all 105+ record types)
  }.freeze
end
```

## Performance Optimizations

### 1. Lazy Parsing
```ruby
class Parser
  def parse_lazy
    # Don't parse all records upfront
    # Parse on-demand as needed
    RecordIterator.new(@io)
  end
end

class RecordIterator
  include Enumerable

  def each
    while @io.pos < @io.size
      yield parse_next_record
    end
  end
end
```

### 2. String Building Optimization
```ruby
class SvgBuilder
  def initialize
    @parts = []  # Array for fast concatenation
  end

  def add_element(tag, attrs)
    @parts << "<#{tag}"
    attrs.each { |k, v| @parts << " #{k}=\"#{v}\"" }
    @parts << ">"
  end

  def to_svg
    @parts.join  # Single join at end
  end
end
```

### 3. Caching
```ruby
class Transform
  def initialize(m11, m12, m21, m22, dx, dy)
    @matrix = [m11, m12, m21, m22, dx, dy]
    @inverse = nil  # Cache inverse calculation
  end

  def invert
    @inverse ||= calculate_inverse
  end
end
```

## File Organization

```
lib/
├── emf2svg.rb                    # Main entry point
└── emf2svg/
    ├── version.rb
    ├── parser.rb                 # Binary parser using BinData
    ├── binary_structures.rb      # BinData structure definitions
    ├── constants.rb              # EMF constants and enums
    ├── options.rb
    ├── gdi_context.rb
    ├── transform.rb
    ├── svg_builder.rb
    ├── color.rb
    └── records/
        ├── base.rb
        ├── drawing.rb            # Polygon, Polyline, etc.
        ├── text.rb               # ExtTextOut, etc.
        ├── path.rb               # BeginPath, EndPath, etc.
        ├── bitmap.rb             # BitBlt, StretchBlt, etc.
        ├── transform.rb          # SetWorldTransform, etc.
        ├── state.rb              # SaveDC, RestoreDC, etc.
        ├── clipping.rb           # SelectClipPath, etc.
        ├── object.rb             # CreatePen, CreateBrush, etc.
        └── control.rb            # SetMapMode, etc.
```

## Implementation Phases

### Phase 1: Core Parser (Week 1)

1. Set up BinData structures for common record types
2. Implement basic parser
3. Test header parsing
4. Test record extraction

**Deliverable**: Can parse EMF and extract records as Ruby hashes

### Phase 2: Record Handlers (Week 2-3)

1. Implement Base record handler
2. Add drawing records (polygon, polyline, rectangle)
3. Add text records
4. Add path records
5. Add state management

**Deliverable**: Can convert simple EMF files to SVG

### Phase 3: Advanced Features (Week 4)

1. Bitmap handling (using chunky_png or oily_png)
2. Clipping regions
3. Complex transformations
4. All remaining record types

**Deliverable**: Full feature parity

### Phase 4: Optimization & Testing (Week 5-6)

1. Profile and optimize hot paths
2. Add caching where appropriate
3. Test against all 228 test files
4. Performance benchmarking

**Deliverable**: Production-ready gem

## Example Usage

```ruby
# Simple usage
svg = Emf2svg.from_file("diagram.emf")
File.write("diagram.svg", svg)

# With options
svg = Emf2svg.from_binary_string(emf_data,
  verbose: true,
  emfplus: true,
  svg_delimiter: true,
  img_width: 800,
  img_height: 600
)

# Check for EMF+ records
if Emf2svg.emfplus?(emf_data)
  puts "This file contains EMF+ records"
end
```

## Performance Comparison

Expected performance vs C implementation:

| Operation | C Version | Pure Ruby | Ratio |
|-----------|-----------|-----------|-------|
| Parsing | 100% | ~60% | 0.6x |
| SVG Generation | 100% | ~70% | 0.7x |
| Overall | 100% | ~50-60% | 0.5-0.6x |

**Mitigation strategies:**
- Use oily_png (has C extension) for bitmaps if available
- Cache frequently calculated values
- Use lazy evaluation
- Optimize string concatenation
- Profile and optimize hot paths

**When is this acceptable?**
- Most EMF files are small (<1MB)
- Conversion is not done in tight loops
- Sub-second conversion time is acceptable
- Portability > raw speed

## Testing Strategy

```ruby
# Unit tests for parser
describe Emf2svg::Parser do
  it "parses EMF header" do
    parser = Emf2svg::Parser.new(emf_data)
    header = parser.header_info
    expect(header[:width]).to eq(100)
    expect(header[:height]).to eq(200)
  end

  it "extracts polygon records" do
    parser = Emf2svg::Parser.new(emf_with_polygon)
    records = parser.parse
    polygon = records.find { |r| r[:type] == :EMR_POLYGON }
    expect(polygon[:points].length).to eq(5)
  end
end

# Integration tests
describe "Full conversion" do
  Dir.glob("spec/fixtures/**/*.emf").each do |emf_file|
    it "converts #{File.basename(emf_file)}" do
      svg = Emf2svg.from_file(emf_file)
      expect(svg).to include('<svg')
      expect(svg).to include('</svg>')
    end
  end
end

# Performance tests
describe "Performance" do
  it "converts within acceptable time" do
    large_emf = File.read("spec/fixtures/large.emf", mode: "rb")

    time = Benchmark.realtime do
      Emf2svg.from_binary_string(large_emf)
    end

    expect(time).to be < 1.0  # Under 1 second
  end
end
```

## Migration from Current Implementation

### Gradual Migration
```ruby
module Emf2svg
  def self.from_binary_string(content, options = {})
    if ENV['EMF2SVG_PURE_RUBY'] || !c_extension_available?
      # Pure Ruby implementation
      Parser.new(content).to_svg(options)
    else
      # Original FFI implementation (fallback)
      from_binary_string_ffi(content, options)
    end
  end

  private

  def self.c_extension_available?
    defined?(FFI) && File.exist?(lib_path)
  end
end
```

## Advantages Summary

1. **Portability**: Works on JRuby, TruffleRuby, Windows, ARM, etc.
2. **Debugging**: Standard Ruby debugging tools work
3. **Maintenance**: Single language, easier to modify
4. **Dependencies**: Only pure Ruby gems needed
5. **Installation**: No compilation step, faster gem install
6. **Testing**: Easier to mock binary structures
7. **Development**: Faster iteration (no recompile)

## Next Steps

1. ✅ Analyze requirements
2. ⬜ Set up BinData structures
3. ⬜ Implement core parser
4. ⬜ Add basic record handlers
5. ⬜ Test with simple EMF files
6. ⬜ Expand record coverage
7. ⬜ Optimize performance
8. ⬜ Full test suite
9. ⬜ Documentation
10. ⬜ Release pure Ruby version

## Conclusion

**Recommendation**: Start with pure Ruby implementation

**Benefits outweigh the performance trade-off for most use cases:**
- Easier to develop and maintain
- More portable across Ruby implementations
- Good enough performance for typical EMF files
- Can always add C extension later if needed (as optional optimization)

The pure Ruby approach aligns better with Ruby philosophy: optimize for developer happiness first, performance second.

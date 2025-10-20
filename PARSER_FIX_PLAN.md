# Parser Record Coverage Fix Plan

## Problem
The parser only explicitly handles ~20 record types. When unhandled records are encountered, they fall through to `parse_generic_record` which returns `{raw_data: ...}` instead of structured data that handlers expect, causing `NoMethodError` exceptions.

## Current Status
- **23/186 files passing (12.4%)**
- **163/194 tests failing**

## Failure Analysis

### Top 3 Failure Causes (covering ~150+ failures):

1. **EMR_EXTCREATEFONTINDIRECTW** - ~100+ failures
   - Error: `undefined method '[]' for nil` at `object.rb:69`
   - Needs: Parser for font creation records

2. **EMR_POLYPOLYGON** - ~20+ failures
   - Error: `undefined method 'map' for nil` at `drawing.rb:325`
   - Needs: Parser for polypolygon records

3. **EMR_EXTTEXTOUTW/EMR_EXTTEXTOUTA** - ~10+ failures
   - Error: `undefined method '>=' for nil` at `text.rb:43`
   - Needs: Parser for text output records

### Other Issues:
4. Missing `require 'benchmark'` in integration spec
5. `ParseError` instantiation errors (wrong number of args)

## Implementation Plan

### Phase 1: Fix Top 3 Missing Parsers (High Priority)
- [ ] Add `EMR_EXTCREATEFONTINDIRECTW` parser
- [ ] Add `EMR_POLYPOLYGON` parser
- [ ] Add `EMR_EXTTEXTOUTW` parser
- [ ] Add `EMR_EXTTEXTOUTA` parser

### Phase 2: Add Binary Structures
- [ ] Add `EmrExtCreateFontIndirectW` BinData structure
- [ ] Add `EmrPolyPolygon` BinData structure
- [ ] Add `EmrExtTextOutW` BinData structure
- [ ] Add `EmrExtTextOutA` BinData structure
- [ ] Add `LogFont` BinData structure (for font records)

### Phase 3: Fix Minor Issues
- [ ] Add `require 'benchmark'` to integration spec
- [ ] Fix `ParseError.new` to accept message argument
- [ ] Add nil guards in handlers for defensive programming

### Phase 4: Comprehensive Record Coverage
- [ ] Audit all 105+ EMF record types
- [ ] Identify which are actually used in test files
- [ ] Add parsers for commonly used records
- [ ] Target 80%+ test pass rate

## Expected Outcomes

After Phase 1-2:
- Should fix ~130+ test failures
- Target: 60-70% pass rate (110-130/186 files)

After Phase 3:
- All known issues fixed
- Target: 70-80% pass rate

After Phase 4:
- Comprehensive record coverage
- Target: 80%+ pass rate (150+/186 files)

## MS-EMF Specification References

Key record types to implement:
- EMR_EXTCREATEFONTINDIRECTW (0x00000052 / 82)
- EMR_POLYPOLYGON (0x00000008 / 8)
- EMR_POLYPOLYGON16 (0x0000005B / 91)
- EMR_EXTTEXTOUTW (0x00000054 / 84)
- EMR_EXTTEXTOUTA (0x00000053 / 83)

## Notes

The MS-EMF specification defines:
- LogFont structure for font data
- PolyPolygon structure with array of polygons
- EmrText structure for text output with positioning

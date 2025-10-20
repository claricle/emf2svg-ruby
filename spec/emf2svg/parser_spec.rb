# frozen_string_literal: true

require "spec_helper"
require "emf2svg/parser"

RSpec.describe Emf2svg::Parser do
  let(:test_emf_file) { File.expand_path("../../examples/image1.emf", __dir__) }
  let(:binary_data) { File.read(test_emf_file, mode: "rb") }
  let(:parser) { described_class.new(binary_data) }

  describe "#initialize" do
    it "creates a parser with binary data" do
      expect(parser).to be_a(described_class)
      expect(parser.header).to be_nil
      expect(parser.records).to eq([])
    end
  end

  describe "#parse" do
    before { parser.parse }

    it "parses the EMF header" do
      expect(parser.header).not_to be_nil
      expect(parser.header.record_type).to eq(0x00000001)
      expect(parser.header.signature).to eq(0x464D4520)
    end

    it "extracts records from the EMF file" do
      expect(parser.records).to be_an(Array)
      expect(parser.records).not_to be_empty
    end

    it "includes record types" do
      record_types = parser.records.map { |r| r[:type] }
      expect(record_types).to include(:EMR_EOF)
    end
  end

  describe "#header_info" do
    before { parser.parse }

    it "returns header information" do
      info = parser.header_info
      expect(info).to be_a(Hash)
      expect(info).to have_key(:width)
      expect(info).to have_key(:height)
      expect(info).to have_key(:dpi_x)
      expect(info).to have_key(:dpi_y)
      expect(info).to have_key(:bounds)
    end

    it "calculates width and height from bounds" do
      info = parser.header_info
      expect(info[:width]).to be > 0
      expect(info[:height]).to be > 0
    end

    it "includes bounds information" do
      info = parser.header_info
      bounds = info[:bounds]
      expect(bounds).to have_key(:left)
      expect(bounds).to have_key(:top)
      expect(bounds).to have_key(:right)
      expect(bounds).to have_key(:bottom)
    end
  end

  describe "error handling" do
    context "with invalid EMF signature" do
      let(:invalid_data) { "INVALID EMF DATA" }
      let(:parser) { described_class.new(invalid_data) }

      it "raises ParseError" do
        expect { parser.parse }.to raise_error(Emf2svg::ParseError)
      end
    end
  end
end

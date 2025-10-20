require "spec_helper"
require "emf2svg/converter"

RSpec.describe Emf2svg::Converter do
  let(:emf_file) { File.join(__dir__, "../../examples/image1.emf") }
  let(:emf_content) { File.binread(emf_file) }

  describe "#initialize" do
    it "initializes with EMF binary content" do
      expect { described_class.new(emf_content) }.not_to raise_error
    end

    it "raises ArgumentError for empty content" do
      expect { described_class.new("") }.to raise_error(ArgumentError, /empty/)
    end
  end

  describe "#convert" do
    subject(:converter) { described_class.new(emf_content) }

    it "returns an SVG string" do
      svg = converter.convert
      expect(svg).to be_a(String)
      expect(svg).not_to be_empty
    end

    it "generates valid SVG with proper namespace" do
      svg = converter.convert
      expect(svg).to include('xmlns="http://www.w3.org/2000/svg"')
    end

    it "includes SVG root element" do
      svg = converter.convert
      expect(svg).to match(/<svg[^>]*>/)
      expect(svg).to include("</svg>")
    end

    it "sets viewBox from EMF bounds" do
      svg = converter.convert
      expect(svg).to match(/viewBox="[^"]*"/)
    end

    it "processes multiple records" do
      svg = converter.convert
      # The test EMF has 54 records, should produce some SVG elements
      # At minimum, it should have the root svg element
      expect(svg.scan(/<[^\/][^>]*>/).count).to be > 1
    end
  end

  describe "integration" do
    it "successfully converts a real EMF file" do
      converter = described_class.new(emf_content)
      svg = converter.convert

      # Basic structural checks
      expect(svg).to start_with("<?xml")
      expect(svg).to include("<svg")
      expect(svg).to include("</svg>")

      # Should have some content
      expect(svg.length).to be > 200
    end

    it "handles EMF with various record types" do
      converter = described_class.new(emf_content)

      # Should not raise any errors
      expect { converter.convert }.not_to raise_error
    end
  end
end

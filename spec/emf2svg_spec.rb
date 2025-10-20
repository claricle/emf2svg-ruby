# frozen_string_literal: true

RSpec.describe Emf2svg do
  it "has a version number" do
    expect(Emf2svg::VERSION).not_to be nil
  end

  let(:example_file) { File.expand_path("examples/image1.emf", __dir__) }

  it "converts from file" do
    svg = described_class.from_file(example_file)
    expect(svg).to be_a(String)
    expect(svg).to include('<?xml version="1.0" encoding="UTF-8"?>')
    expect(svg).to include("<svg")
    expect(svg).to include('xmlns="http://www.w3.org/2000/svg"')
    expect(svg).to include("</svg>")
  end

  it "converts from string" do
    string = File.read(example_file, mode: "rb")
    svg = described_class.from_binary_string(string)
    expect(svg).to be_a(String)
    expect(svg).to include('<?xml version="1.0" encoding="UTF-8"?>')
    expect(svg).to include("<svg")
    expect(svg).to include('xmlns="http://www.w3.org/2000/svg"')
    expect(svg).to include("</svg>")
  end
end

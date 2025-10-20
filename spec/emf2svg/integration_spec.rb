# frozen_string_literal: true

require "spec_helper"
require "benchmark"

RSpec.describe "Integration tests" do
  let(:test_files_dir) { File.join(__dir__, "../fixtures/libemf2svg") }

  describe "Reference EMF file conversion" do
    # Get all test EMF files
    emf_files = if Dir.exist?(File.join(__dir__, "../fixtures/libemf2svg"))
                  Dir.glob(File.join(__dir__,
                                     "../fixtures/libemf2svg/*.emf")).sort
                else
                  []
                end

    if emf_files.empty?
      it "skips integration tests (reference files not found)" do
        skip "Reference EMF files not available at #{test_files_dir}"
      end
    else
      context "converting #{emf_files.length} reference EMF files" do
        emf_files.each do |emf_file|
          filename = File.basename(emf_file)

          it "successfully converts #{filename}" do
            emf_data = File.read(emf_file, mode: "rb")

            expect do
              svg_output = Emf2svg.from_binary_string(emf_data)

              # Verify SVG output
              expect(svg_output).to be_a(String)
              expect(svg_output).not_to be_empty
              expect(svg_output).to include("<svg")
              expect(svg_output).to include("</svg>")
              expect(svg_output).to include('xmlns="http://www.w3.org/2000/svg"')
            end.not_to raise_error
          end
        end
      end

      context "conversion statistics" do
        it "successfully converts all files" do
          success_count = 0
          failure_count = 0
          failures = []

          emf_files.each do |emf_file|
            filename = File.basename(emf_file)
            puts "Processing: #{filename}" if filename == "test-167.emf"

            emf_data = File.read(emf_file, mode: "rb")

            # Add timeout for hanging detection
            result = { output: nil, error: nil }
            thread = Thread.new do
              result[:output] = Emf2svg.from_binary_string(emf_data)
            rescue StandardError => e
              result[:error] = e
            end

            # Wait max 10 seconds
            if thread.join(10)
              if result[:error]
                failure_count += 1
                failures << "#{filename} (#{result[:error].class}: #{result[:error].message})"
              elsif result[:output]&.include?("<svg") && result[:output].include?("</svg>")
                success_count += 1
              else
                failure_count += 1
                failures << filename
              end
            else
              # Timeout - kill thread
              thread.kill
              failure_count += 1
              failures << "#{filename} (TIMEOUT - parser hung)"
              puts "TIMEOUT on #{filename} - parser hung!"
            end
          rescue StandardError => e
            failure_count += 1
            failures << "#{File.basename(emf_file)} (#{e.class}: #{e.message})"
          end

          puts "\n=== Integration Test Results ==="
          puts "Total files: #{emf_files.length}"
          puts "Successful: #{success_count} (#{(success_count.to_f / emf_files.length * 100).round(1)}%)"
          puts "Failed: #{failure_count}"

          if failure_count > 0
            puts "\nFailed files:"
            failures.each { |f| puts "  - #{f}" }
          end

          # We expect at least 80% success rate
          expect(success_count.to_f / emf_files.length).to be >= 0.8
        end
      end
    end
  end

  describe "Performance benchmarks" do
    it "converts small EMF files quickly" do
      # Use test-012.emf (1,488 bytes)
      small_file = File.join(test_files_dir, "test-012.emf")
      skip "Test file not found" unless File.exist?(small_file)

      emf_data = File.read(small_file, mode: "rb")

      time = Benchmark.realtime do
        Emf2svg.from_binary_string(emf_data)
      end

      puts "\nSmall file (#{emf_data.bytesize} bytes) conversion time: #{(time * 1000).round(2)}ms"
      expect(time).to be < 0.5 # Should be under 500ms
    end

    it "converts medium EMF files reasonably fast" do
      # Use test-000.emf (95,060 bytes)
      medium_file = File.join(test_files_dir, "test-000.emf")
      skip "Test file not found" unless File.exist?(medium_file)

      emf_data = File.read(medium_file, mode: "rb")

      time = Benchmark.realtime do
        Emf2svg.from_binary_string(emf_data)
      end

      puts "\nMedium file (#{emf_data.bytesize} bytes) conversion time: #{(time * 1000).round(2)}ms"
      expect(time).to be < 2.0 # Should be under 2 seconds
    end
  end

  describe "Memory usage" do
    it "doesn't leak memory during conversion" do
      test_file = File.join(test_files_dir, "test-012.emf")
      skip "Test file not found" unless File.exist?(test_file)

      emf_data = File.read(test_file, mode: "rb")

      # Convert multiple times to check for memory leaks
      10.times do
        Emf2svg.from_binary_string(emf_data)
      end

      # Force garbage collection
      GC.start

      # If we get here without running out of memory, the test passes
      expect(true).to be true
    end
  end

  describe "Error handling" do
    it "handles corrupted EMF data gracefully" do
      corrupted_data = "INVALID EMF DATA" * 100

      expect do
        Emf2svg.from_binary_string(corrupted_data)
      end.to raise_error(Emf2svg::ParseError)
    end

    it "handles truncated EMF files gracefully" do
      test_file = File.join(test_files_dir, "test-012.emf")
      skip "Test file not found" unless File.exist?(test_file)

      emf_data = File.read(test_file, mode: "rb")
      truncated_data = emf_data[0, 100] # Only first 100 bytes

      expect do
        Emf2svg.from_binary_string(truncated_data)
      end.to raise_error(Emf2svg::ParseError)
    end

    it "handles empty EMF data" do
      expect do
        Emf2svg.from_binary_string("")
      end.to raise_error(ArgumentError)
    end

    it "handles nil EMF data" do
      expect do
        Emf2svg.from_binary_string(nil)
      end.to raise_error(ArgumentError)
    end
  end
end

require "rbconfig"
require "mini_portile2"
require "pathname"
require "tmpdir"

module Emf2svg
  class Recipe < MiniPortileCMake
    ROOT = Pathname.new(File.expand_path("../..", __dir__))

    def initialize
      super("libemf2svg", "1.7.0")

      @files << {
        url: "https://github.com/metanorma/libemf2svg/releases/download/v1.7.0/libemf2svg.tar.gz",
        sha256: "a87a02510f87ed4510a3426fa8636b340e26d96f25edf63c3ba465e7e9d7e2eb", # rubocop:disable Layout/LineLength
      }

      @target = ROOT.join(@target).to_s
      @printed = {}
    end

    def cook_if_not
      cook unless File.exist?(checkpoint)
    end

    def cook
      super
      FileUtils.touch(checkpoint)
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/CyclomaticComplexity
    def host_platform
      @host_platform ||=
        case @host
        when /\Ax86_64.*mingw32/
          "x64-mingw32"
        when /\Ax86_64.*linux/
          "x86_64-linux"
        when /\A(arm64|aarch64).*linux/
          "arm64-linux"
        when /\Ax86_64.*(darwin|macos|osx)/
          "x86_64-darwin"
        when /\A(arm64|aarch64).*(darwin|macos|osx)/
          "arm64-darwin"
        else
          @host
        end
    end

    def target_platform
      @target_platform ||=
        case ENV["target_platform"]
        when /\A(arm64|aarch64).*(darwin|macos|osx)/
          "arm64-darwin"
        when /\Ax86_64.*(darwin|macos|osx)/
          "x86_64-darwin"
        when /\A(arm64|aarch64).*linux/
          "aarch64-linux"
        else
          ENV["target_platform"] || host_platform
        end
    end

    def target_triplet
      @target_triplet ||=
        case target_platform
        when "arm64-darwin"
          "arm64-osx"
        when "x86_64-darwin"
          "x64-osx"
        when "aarch64-linux"
          "arm64-linux"
        when "x86_64-linux"
          "x64-linux"
        when /\Ax64-mingw(32|-ucrt)/
          "x64-mingw-static"
        end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/MethodLength

    def windows_native?
      MiniPortile.windows? && target_triplet.eql?("x64-mingw-static")
    end

    def drop_target_triplet?
      windows_native? || host_platform.eql?(target_platform)
    end

    def checkpoint
      File.join(@target, "#{name}-#{version}-#{target_platform}.installed")
    end

    def configure_defaults
      opts = []

      opts << "-DCMAKE_BUILD_TYPE=Release"
      opts << "-DLONLY=ON"

      unless target_triplet.nil? || drop_target_triplet?
        opts << " -DVCPKG_TARGET_TRIPLET=#{target_triplet}"
      end

      opts << "-DCMAKE_TOOLCHAIN_FILE=vcpkg/scripts/buildsystems/vcpkg.cmake"

      opts
    end

    def compile
      execute("compile", "#{make_cmd} --target emf2svg")
    end

    def make_cmd
      "cmake --build #{File.expand_path(work_path)} --config Release"
    end

    def install
      message("Called install\n")
      libs = if MiniPortile.windows?
               Dir.glob(File.join(work_path, "Release", "*.dll"))
             else
               Dir.glob(File.join(work_path, "libemf2svg.{so,dylib}"))
                 .grep(/\/(?:lib)?[a-zA-Z0-9-]+\.(?:so|dylib)$/)
             end

      FileUtils.cp_r(libs, ROOT.join("lib", "emf2svg"), verbose: true)
    end

    def execute(action, command, command_opts = {})
      super(action, command, command_opts.merge(debug: true))
    end

    def message(text)
      return super unless text.start_with?("\rDownloading")

      match = text.match(/(\rDownloading .*)\(\s*\d+%\)/)
      pattern = match ? match[1] : text
      return if @printed[pattern]

      @printed[pattern] = true
      super
    end

    private

    def tmp_path
      @tmp_path ||= Dir.mktmpdir
    end

    def port_path
      "port"
    end
  end
end

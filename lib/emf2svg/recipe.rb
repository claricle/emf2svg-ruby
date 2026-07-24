require "rbconfig"
require "mini_portile2"
require "pathname"
require "tmpdir"
require "open3"
require_relative "version"

module Emf2svg
  class Recipe < MiniPortileCMake
    # Pinned vcpkg commit. Matches the SHA claricle/libemf2svg CI uses;
    # bump deliberately to refresh the ports tree.
    VCPKG_REF = "4f95fba7a7d1101bb8acdeb51e4609686449701e"
    ROOT = Pathname.new(File.expand_path("../..", __dir__))

    def initialize
      super("libemf2svg", LIBEMF2SVG_VERSION)

      @files << {
        url: "https://github.com/claricle/libemf2svg/releases/download/v#{LIBEMF2SVG_VERSION}/libemf2svg.tar.gz",
        sha256: "3782453987b477f2d8657c727e30f1e7a509188edfe6de2f7423443635aefd6d", # rubocop:disable Layout/LineLength
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

    # Since libemf2svg v1.8.2 the source tarball no longer bundles the
    # vcpkg tool (it moved too fast to ship as a snapshot). We bootstrap
    # vcpkg into the work path before CMake configure runs.
    def configure
      bootstrap_vcpkg
      super
    end

    def bootstrap_vcpkg
      vcpkg_root = File.join(work_path, "vcpkg")
      vcpkg_exe = MiniPortile.windows? ? "vcpkg.exe" : "vcpkg"
      return if File.executable?(File.join(vcpkg_root, vcpkg_exe))

      message("Bootstrapping vcpkg@#{VCPKG_REF} into #{vcpkg_root}\n")
      FileUtils.rm_rf(vcpkg_root)
      execute("clone-vcpkg", "git clone --quiet https://github.com/microsoft/vcpkg.git #{vcpkg_root}")
      execute("checkout-vcpkg", "git checkout --quiet #{VCPKG_REF}", cd: vcpkg_root)
      if MiniPortile.windows?
        execute("bootstrap-vcpkg", "bootstrap-vcpkg.bat -disableMetrics", cd: vcpkg_root)
      else
        execute("bootstrap-vcpkg", "./bootstrap-vcpkg.sh -disableMetrics", cd: vcpkg_root)
      end
    end

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
        opts << "-DVCPKG_TARGET_TRIPLET=#{target_triplet}"
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

    def lb_to_verify
      pt = if MiniPortile.windows?
             "emf2svg.dll"
           else
             "libemf2svg.{so,dylib}"
           end
      @lb_to_verify ||= Dir.glob(ROOT.join("lib", "emf2svg", pt))
    end

    def verify_libs
      lb_to_verify.each do |l|
        out, st = Open3.capture2("file #{l}")
        raise "Failed to query file #{l}: #{out}" unless st.exitstatus.zero?

        if out.include?(target_format)
          message("Verifying #{l} ... OK\n")
        else
          raise "Invalid file format '#{out}', '#{@target_format}' expected"
        end
      end
    end

    def install
      libs = if MiniPortile.windows?
               Dir.glob(File.join(work_path, "Release", "*.dll"))
             else
               Dir.glob(File.join(work_path, "libemf2svg.{so,dylib}"))
                 .grep(/\/(?:lib)?[a-zA-Z0-9-]+\.(?:so|dylib)$/)
             end
      FileUtils.cp_r(libs, ROOT.join("lib", "emf2svg"), verbose: true)

      verify_libs unless target_format.eql?("skip")
    end

    def execute(action, command, command_opts = {})
      super(action, command, command_opts.merge(debug: false))
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
        case ENV.fetch("target_platform", nil)
        when /\A(arm64|aarch64).*(darwin|macos|osx)/
          "arm64-darwin"
        when /\Ax86_64.*(darwin|macos|osx)/
          "x86_64-darwin"
        when /\A(arm64|aarch64).*linux/
          "aarch64-linux"
        else
          ENV.fetch("target_platform", host_platform)
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

    def target_format
      @target_format ||=
        case target_platform
        when "arm64-darwin"
          "Mach-O 64-bit dynamically linked shared library arm64"
        when "x86_64-darwin"
          "Mach-O 64-bit dynamically linked shared library x86_64"
        when "aarch64-linux"
          "ELF 64-bit LSB shared object, ARM aarch64"
        when "x86_64-linux"
          "ELF 64-bit LSB shared object, x86-64"
        when /\Ax64-mingw(32|-ucrt)/
          "PE32+ executable (DLL) (console) x86-64, for MS Windows"
        else
          "skip"
        end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/MethodLength
  end
end

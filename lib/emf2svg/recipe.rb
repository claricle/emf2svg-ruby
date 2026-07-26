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
    VCPKG_REF = "4f95fba7a7d1101bb8acdeb51e4609686449701e".freeze
    VCPKG_URL = "https://github.com/microsoft/vcpkg.git".freeze
    ROOT = Pathname.new(File.expand_path("../..", __dir__))

    def initialize
      super("libemf2svg", LIBEMF2SVG_VERSION)

      @files << {
        # rubocop:disable Layout/LineLength
        url: "https://github.com/claricle/libemf2svg/releases/download/v#{LIBEMF2SVG_VERSION}/libemf2svg.tar.gz",
        sha256: "3782453987b477f2d8657c727e30f1e7a509188edfe6de2f7423443635aefd6d",
        # rubocop:enable Layout/LineLength
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
    # vcpkg into the work path before CMake configure runs -- unless
    # we're targeting musl, in which case vcpkg has no public binary
    # cache for arm64-linux-musl / x64-linux-musl and would compile
    # every dependency from source (hours). For musl we use the
    # distribution's own -dev packages (freetype, fontconfig, etc.)
    # via pkg-config instead.
    def configure
      bootstrap_vcpkg unless use_system_libs?
      export_toolchain_to_env
      super
    end

    # Downstream consumers (e.g. metanorma) sometimes patch RbConfig at
    # runtime to point Ruby's toolchain at a known-good compiler, but
    # those overrides live in the Ruby process and don't reach the raw
    # cmake subprocess that mini_portile2 spawns. The result is
    # "CMAKE_C_COMPILER not set" when the deploy environment has a
    # stripped PATH. Mirror the resolved RbConfig toolchain into ENV so
    # the subprocess sees the same compiler the running Ruby was built
    # with.
    def export_toolchain_to_env
      %w[CC CXX LDFLAGS].each do |var|
        val = RbConfig::CONFIG[var]
        next if val.nil? || val.empty?

        ENV[var] = val
      end
    end

    def bootstrap_vcpkg
      vcpkg_root = File.join(work_path, "vcpkg")
      return if vcpkg_bootstrapped?(vcpkg_root)

      message("Bootstrapping vcpkg@#{VCPKG_REF} into #{vcpkg_root}\n")
      FileUtils.rm_rf(vcpkg_root)
      execute("clone-vcpkg", "git clone --quiet #{VCPKG_URL} #{vcpkg_root}")
      execute("checkout-vcpkg",
              "git checkout --quiet #{VCPKG_REF}", cd: vcpkg_root)
      execute("bootstrap-vcpkg", bootstrap_cmd, cd: vcpkg_root)
    end

    def vcpkg_bootstrapped?(vcpkg_root)
      exe = MiniPortile.windows? ? "vcpkg.exe" : "vcpkg"
      File.executable?(File.join(vcpkg_root, exe))
    end

    def bootstrap_cmd
      if MiniPortile.windows?
        "bootstrap-vcpkg.bat -disableMetrics"
      else
        "./bootstrap-vcpkg.sh -disableMetrics"
      end
    end

    def windows_native?
      MiniPortile.windows? && target_triplet.eql?("x64-mingw-static")
    end

    def drop_target_triplet?
      # Windows ARM64 builds against MSVC with static linking. vcpkg's
      # auto-detection would pick arm64-windows (dynamic) instead of
      # arm64-windows-static, so always pass the triplet explicitly.
      return false if target_platform == "aarch64-mingw-ucrt"

      windows_native? || host_platform.eql?(target_platform)
    end

    def checkpoint
      File.join(@target, "#{name}-#{version}-#{target_platform}.installed")
    end

    def configure_defaults
      opts = []

      opts << "-DCMAKE_BUILD_TYPE=Release"
      opts << "-DLONLY=ON"

      unless use_system_libs?
        unless target_triplet.nil? || drop_target_triplet?
          opts << "-DVCPKG_TARGET_TRIPLET=#{target_triplet}"
        end
        opts << "-DCMAKE_TOOLCHAIN_FILE=vcpkg/scripts/buildsystems/vcpkg.cmake"
      end

      opts
    end

    # Musl builds link against the distro's own -dev packages
    # (freetype, fontconfig, libxml2, libpng) via pkg-config. This
    # sidesteps vcpkg's lack of a public binary cache for musl
    # triplets, which otherwise forces from-source compiles that
    # exceed CI timeouts.
    def use_system_libs?
      target_platform.end_with?("-linux-musl")
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

        if target_format.match?(out)
          message("Verifying #{l} ... OK\n")
        else
          fmt = target_format.source
          raise "Invalid file format '#{out}', /#{fmt}/ expected"
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
        when /\A(aarch64|arm64).*mingw.*ucrt/
          "aarch64-mingw-ucrt"
        when /\Ax86_64.*linux-musl/
          "x86_64-linux-musl"
        when /\A(arm64|aarch64).*linux-musl/
          "aarch64-linux-musl"
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
        when /\A(arm64|aarch64).*linux-musl/
          "aarch64-linux-musl"
        when /\Ax86_64.*linux-musl/
          "x86_64-linux-musl"
        when /\A(arm64|aarch64).*linux/
          "aarch64-linux"
        when /\Aaarch64-mingw-ucrt/, /\A(arm64|aarch64).*mingw.*ucrt/
          "aarch64-mingw-ucrt"
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
        when "aarch64-linux-musl"
          "arm64-linux-musl"
        when "x86_64-linux"
          "x64-linux"
        when "x86_64-linux-musl"
          "x64-linux-musl"
        when "aarch64-mingw-ucrt"
          "arm64-windows-static"
        when /\Ax64-mingw(32|-ucrt)/
          "x64-mingw-static"
        end
    end

    def target_format
      @target_format ||=
        case target_platform
        when "arm64-darwin"
          /Mach-O 64-bit dynamically linked shared library arm64/
        when "x86_64-darwin"
          /Mach-O 64-bit dynamically linked shared library x86_64/
        when "aarch64-linux", "aarch64-linux-musl"
          /ELF 64-bit LSB shared object, ARM aarch64/
        when "x86_64-linux", "x86_64-linux-musl"
          /ELF 64-bit LSB shared object, x86-64/
        when "aarch64-mingw-ucrt"
          # `file` prints "PE32+ executable for MS Windows 6.02 (DLL),
          # ARM64, 6 sections". Note: ARM64 (not AArch64), and (DLL)
          # may appear before or after the arch token.
          /PE32\+ executable.*ARM64/i
        when /\Ax64-mingw(32|-ucrt)/
          /PE32\+ executable.*\(DLL\).*x86-64/
        else
          "skip"
        end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/MethodLength
  end
end

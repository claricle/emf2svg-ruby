# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

task :compile do
  require_relative "ext/extconf"
end

task spec: :compile

desc "Build install-compilation gem"
task "gem:native:any" do
  sh "rake platform:any gem"
end

require "rubygems/package_task"

desc "Define the gem task to build on any platform (compile on install)"
task "platform:any" do
  spec = Gem::Specification::load("emf2svg.gemspec").dup
  task = Gem::PackageTask.new(spec)
  task.define
end

platforms = [
  "x64-mingw32",
  "x64-mingw-ucrt",
  "aarch64-mingw-ucrt",
  "x86_64-linux",
  "x86_64-linux-musl",
  "aarch64-linux",
  "x86_64-darwin",
  "arm64-darwin",
]

platforms.each do |platform|
  desc "Build pre-compiled gem for the #{platform} platform"
  task "gem:native:#{platform}" do
    sh "rake compile platform:#{platform} gem target_platform=#{platform}"
  end

  desc "Define the gem task to build on the #{platform} platform (binary gem)"
  task "platform:#{platform}" do
    spec = Gem::Specification::load("emf2svg.gemspec").dup
    spec.platform = Gem::Platform.new(platform)
    spec.files += Dir.glob("lib/emf2svg/*.{dll,so,dylib}")
    spec.extensions = []
    spec.dependencies.reject! { |d| d.name == "mini_portile2" }

    task = Gem::PackageTask.new(spec)
    task.define
  end
end

require "rake/clean"

CLOBBER.include("pkg")
CLEAN.include("ports",
              "tmp",
              "lib/emf2svg/*.dll",
              "lib/emf2svg/*.dylib",
              "lib/emf2svg/*.so")

# frozen_string_literal: true

require 'bundler'
require 'fileutils'
require 'rake/clean'

CLOBBER.include('pkg')

# Pattern 1 staged build (see JRUBY.md): copy lib/shared/ and lib/<impl>/
# into a temporary pkg/stage-<impl>/lib/ so the published gem has a flat
# lib/ tree. The same gemspec is used; STAGED_BUILD switches it to the
# flat-lib branch, GEM_TARGET picks the platform.
def stage_and_build(impl)
  raise ArgumentError, "impl must be 'mri' or 'jruby', got #{impl.inspect}" \
    unless %w[mri jruby].include?(impl)

  root = __dir__
  pkg = File.join(root, 'pkg')
  stage = File.join(pkg, "stage-#{impl}")

  FileUtils.rm_rf(stage)
  FileUtils.mkdir_p(File.join(stage, 'lib'))
  FileUtils.cp_r(File.join(root, 'lib/shared/.'), File.join(stage, 'lib'))
  FileUtils.cp_r(File.join(root, "lib/#{impl}/."), File.join(stage, 'lib'))
  %w[neo4j-driver.gemspec README.md LICENSE].each do |f|
    src = File.join(root, f)
    FileUtils.cp(src, stage) if File.exist?(src)
  end

  # Run `gem build` outside Bundler. If we leave Bundler env in place,
  # the subprocess re-resolves the project Gemfile with STAGED_BUILD set
  # and GEM_TARGET=jruby flips spec.platform to 'java', which breaks
  # resolution on a non-Java host. with_unbundled_env strips BUNDLE_*
  # and friends so `gem build` only sees this stage's gemspec.
  Dir.chdir(stage) do
    Bundler.with_unbundled_env do
      system({ 'STAGED_BUILD' => '1', 'GEM_TARGET' => impl },
             'gem', 'build', 'neo4j-driver.gemspec') \
        or raise "gem build failed for #{impl}"
    end
  end

  built = Dir[File.join(stage, '*.gem')].first or
    raise "no .gem produced in #{stage}"
  FileUtils.mkdir_p(pkg)
  dest = File.join(pkg, File.basename(built))
  FileUtils.mv(built, dest)
  puts "Built: #{dest}"
end

namespace :build do
  desc 'Build the MRI gem (flat lib/, ruby platform)'
  task(:mri) { stage_and_build('mri') }

  desc 'Build the JRuby gem (flat lib/, java platform)'
  task(:jruby) { stage_and_build('jruby') }

  desc 'Build both MRI and JRuby gems'
  task all: %i[mri jruby]
end

desc 'Build both MRI and JRuby gems'
task build: 'build:all'

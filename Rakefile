# frozen_string_literal: true

require 'bundler'
require 'fileutils'
require 'rake/clean'

CLOBBER.include('pkg')

# JRuby only: resolve the Java-driver jars from Maven, vendor them into
# lib/jruby (maven-repo layout), write Jars.lock, and regenerate the require
# manifest from that lock. Maven runs at BUILD time only — the published gem
# declares no jar `requirements` (see neo4j-ruby-driver-java.gemspec), so
# `gem install` does zero Maven. Deterministic: starts from a clean vendor tree
# so a fresh checkout yields the same result regardless of prior `bundle install`.
def regenerate_jruby_jars(root)
  vendor = File.join(root, 'lib/jruby')
  # Start clean so stale versions can't accumulate; the manifest is generated
  # from the lock below, so it can never drift from what is vendored.
  FileUtils.rm_rf(File.join(vendor, 'org'))
  FileUtils.rm_f(File.join(root, 'Jars.lock'))
  # lock_jars reads the jar requirements off the (dev-tree) gemspec, downloads
  # the dependency tree, copies the jars under vendor/, and writes Jars.lock.
  Dir.chdir(root) { sh 'lock_jars', '--vendor-dir', vendor }
  write_jars_manifest(root, vendor)
end

# Generate lib/jruby/neo4j-ruby-driver_jars.rb from Jars.lock so the runtime
# require manifest can never pin a version other than what is vendored.
def write_jars_manifest(root, vendor)
  entries = File.readlines(File.join(root, 'Jars.lock'))
                .map(&:strip).reject(&:empty?).map { it.split(':')[0, 3] }
  lines = ['# frozen_string_literal: true',
           '# GENERATED from Jars.lock by `rake build:jruby` — do not edit. Loads the',
           '# vendored jars via require_jar (no Maven / network at install or runtime).',
           'begin', "  require 'jar_dependencies'", 'rescue LoadError']
  lines += entries.map { |g, a, v| "  require '#{g.tr('.', '/')}/#{a}/#{v}/#{a}-#{v}.jar'" }
  lines += ['end', '', 'if defined? Jars']
  lines += entries.map { |g, a, v| "  require_jar '#{g}', '#{a}', '#{v}'" }
  lines << 'end'
  File.write(File.join(vendor, 'neo4j-ruby-driver_jars.rb'), "#{lines.join("\n")}\n")
end

# Pattern 1 staged build (see JRUBY.md): copy lib/shared/ and lib/<impl>/
# into a temporary pkg/stage-<impl>/lib/ so the published gem has a flat
# lib/ tree. Each impl has its own gemspec (neo4j-ruby-driver.gemspec for
# MRI, neo4j-ruby-driver-java.gemspec for JRuby); both go through
# STAGED_BUILD=1 to flip from dev-tree files/require_paths to the flat ones.
def stage_and_build(impl)
  raise ArgumentError, "impl must be 'mri' or 'jruby', got #{impl.inspect}" \
    unless %w[mri jruby].include?(impl)

  root = __dir__
  pkg = File.join(root, 'pkg')
  stage = File.join(pkg, "stage-#{impl}")
  gemspec_file = impl == 'jruby' ? 'neo4j-ruby-driver-java.gemspec' : 'neo4j-ruby-driver.gemspec'

  FileUtils.rm_rf(stage)
  FileUtils.mkdir_p(File.join(stage, 'lib'))
  FileUtils.cp_r(File.join(root, 'lib/shared/.'), File.join(stage, 'lib'))
  # JRuby: resolve + vendor the Java-driver jars, and regenerate Jars.lock and
  # the require manifest, so the staged copy below is deterministic on a clean
  # checkout rather than a side effect of a prior `bundle install`.
  regenerate_jruby_jars(root) if impl == 'jruby'
  FileUtils.cp_r(File.join(root, "lib/#{impl}/."), File.join(stage, 'lib'))
  FileUtils.mkdir_p(File.join(stage, 'build'))
  FileUtils.cp(File.join(root, 'build/gemspec_common.rb'), File.join(stage, 'build'))
  [gemspec_file, 'README.md', 'LICENSE.txt'].each do |f|
    src = File.join(root, f)
    FileUtils.cp(src, stage) if File.exist?(src)
  end
  # JRuby: ship Jars.lock alongside the vendored jars so the published gem pins
  # exact versions and needs no Maven at install time.
  if impl == 'jruby' && File.exist?(File.join(root, 'Jars.lock'))
    FileUtils.cp(File.join(root, 'Jars.lock'), stage)
  end

  # Run `gem build` outside Bundler. If we leave Bundler env in place, the
  # subprocess re-resolves the project Gemfile under STAGED_BUILD=1 (the
  # gemspec then expects the flat staged lib/, which doesn't exist at the
  # project root). with_unbundled_env strips BUNDLE_* so `gem build` only
  # sees this stage's gemspec.
  Dir.chdir(stage) do
    Bundler.with_unbundled_env do
      system({ 'STAGED_BUILD' => '1' }, 'gem', 'build', gemspec_file) \
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

# Regenerate CHANGELOG.md from the commit history with git-cliff
# (https://git-cliff.org; `brew install git-cliff`). Run after merging PRs to
# refresh [Unreleased]; pass the release tag to finalize a version section:
#   rake "changelog[v6.2.1.beta.1]"
desc 'Regenerate CHANGELOG.md from commits (git-cliff)'
task :changelog, [:tag] do |_task, args|
  cmd = %w[git cliff]
  if (tag = args[:tag])
    tag.match?(/\Av\d[\w.-]*\z/) or raise "Invalid tag #{tag.inspect} (expected e.g. v6.2.1.beta.1)"
    cmd += ['--tag', tag]
  end
  # Pass args to sh as an array — no shell, so the tag can't inject commands.
  sh(*cmd, '-o', 'CHANGELOG.md')
end

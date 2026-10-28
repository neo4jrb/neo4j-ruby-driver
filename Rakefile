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
  # Start clean so stale jars can't accumulate. Vendored jars land under maven
  # group dirs (org/, com/, io/, …) and the manifest is a generated file, so
  # remove everything under lib/jruby except the Ruby sources (neo4j/).
  Dir.glob(File.join(vendor, '*')).each do |path|
    FileUtils.rm_rf(path) unless File.basename(path) == 'neo4j'
  end
  FileUtils.rm_f(File.join(root, 'Jars.lock'))
  # lock_jars reads the jar requirements off the (dev-tree) gemspec, downloads
  # the dependency tree, copies the jars under vendor/, and writes Jars.lock.
  Dir.chdir(root) { sh 'lock_jars', '--vendor-dir', vendor }
  write_jars_manifest(root, vendor)
end

# Generate lib/jruby/neo4j-ruby-driver_jars.rb from Jars.lock so the runtime
# require manifest can never pin a version other than what is vendored. Uses
# Jars::Lock#process(:runtime), which drops `provided`/`test` entries (only
# runtime jars are vendored — requiring the others would raise JarLoadError),
# and `gacv` so classifier coordinates round-trip.
def write_jars_manifest(root, vendor)
  require 'jars/lock'
  jars = []
  Jars::Lock.new(File.join(root, 'Jars.lock')).process(:runtime) { |jar| jars << jar }
  lines = ['# frozen_string_literal: true',
           '# GENERATED from Jars.lock by `rake build:jruby` — do not edit. Loads the',
           '# vendored jars via require_jar (no Maven / network at install or runtime).',
           'begin', "  require 'jar_dependencies'", 'rescue LoadError']
  lines += jars.map { |j| "  require '#{jar_require_path(j)}'" }
  lines += ['end', '', 'if defined? Jars']
  lines += jars.map { |j| "  require_jar #{j.gacv.map { |c| "'#{c}'" }.join(', ')}" }
  lines << 'end'
  File.write(File.join(vendor, 'neo4j-ruby-driver_jars.rb'), "#{lines.join("\n")}\n")
end

# Load-path-relative require target for a vendored jar. Mirrors
# Jars::JarDetails#path (whose own path is absolute, under Jars.home) but keeps
# it relative to lib/, since the plain-require fallback loads off $LOAD_PATH.
def jar_require_path(jar)
  File.join(jar.group_id.tr('.', '/'), jar.artifact_id, jar.version,
            "#{jar.gacv[1..].join('-')}.jar")
end

# JRuby only (no-op otherwise): regenerate the vendored jars + Jars.lock, then
# stage Jars.lock into the gem root so the published gem pins exact versions.
def prepare_jruby_jars(impl, root, stage)
  return unless impl == 'jruby'

  regenerate_jruby_jars(root)
  FileUtils.cp(File.join(root, 'Jars.lock'), stage)
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
  # JRuby only (no-op for MRI): (re)generate + stage the vendored jars before
  # the lib/jruby copy, so the staged tree is deterministic on a clean checkout
  # rather than a side effect of a prior `bundle install`.
  prepare_jruby_jars(impl, root, stage)
  FileUtils.cp_r(File.join(root, "lib/#{impl}/."), File.join(stage, 'lib'))
  FileUtils.mkdir_p(File.join(stage, 'build'))
  FileUtils.cp(File.join(root, 'build/gemspec_common.rb'), File.join(stage, 'build'))
  [gemspec_file, 'README.md', 'LICENSE.txt'].each do |f|
    src = File.join(root, f)
    FileUtils.cp(src, stage) if File.exist?(src)
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
namespace :coverage do
  # Fail if any line added/modified since BASE (default origin/main) under lib/
  # is executable, was loaded by the test run, and went uncovered. Reads every
  # coverage/<flavour>/.resultset.json produced by `COVERAGE=1 rspec` (run each
  # flavour first, or supply both resultsets in CI) and unions them.
  desc 'Enforce 100% coverage on lines changed vs BASE (default origin/main)'
  task :enforce, [:base] do |_task, args|
    require_relative 'tasks/diff_coverage'
    root = __dir__
    base = args[:base] || ENV['COVERAGE_BASE'] || 'origin/main'
    # Recursive so it finds both local runs (coverage/mri, coverage/jruby) and
    # CI artifacts downloaded under coverage/<artifact-name>/coverage/<flavour>.
    resultsets = Dir[File.join(root, 'coverage/**/.resultset.json')]
    raise 'No coverage resultsets found — run `COVERAGE=1 bundle exec rspec` first.' if resultsets.empty?

    changed = DiffCoverage.changed_lines(base: base, root: root)
    violations = DiffCoverage.new(root: root, resultset_paths: resultsets, changed_lines: changed).violations
    changed_count = changed.values.sum(&:size)

    if violations.empty?
      puts "Diff coverage OK — #{changed_count} changed line(s) across #{changed.size} file(s), " \
           "all covered (base #{base}, #{resultsets.size} resultset(s))."
    else
      warn "Uncovered changed lines (#{violations.size} of #{changed_count} changed):"
      violations.each { |v| warn "  #{v.path}:#{v.line}" }
      abort 'Diff coverage failed: every new or changed line must be covered by a test.'
    end
  end
end

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

VERSION_FILE = 'lib/shared/neo4j/driver/version.rb'
JAVA_GEMSPEC = 'neo4j-ruby-driver-java.gemspec'

# Cut a release in one step. The gem version lives in version.rb (single source
# of truth — the release workflow refuses a tag that disagrees with it), so:
#
#   rake release            # release the version already in version.rb
#   rake "release[6.3.1]"   # bump version.rb to 6.3.1 first, then release
#
# It finalizes the CHANGELOG for the version, commits version.rb + CHANGELOG on
# main and pushes straight to main (sanctioned by the admin `always` bypass on
# the branch ruleset — a changelog/version commit is paths-ignored by CI and the
# changelog is machine-generated, so a PR would add process without protection),
# then — after a y/N gate, since this publishes to RubyGems and can't be undone —
# tags `v<version>` and pushes the tag, which triggers .github/workflows/release.yml.
#
# Set RELEASE_YES=1 to skip the confirmation (e.g. from an automated caller).
def cut_release(version_arg)
  # Mutating commands abort loudly on failure; array form means no shell, so
  # nothing here can be shell-injected. `probe` is for boolean probes.
  run = ->(*cmd) { system(*cmd) or abort("✗ command failed: #{cmd.join(' ')}") }
  probe = ->(*cmd) { system(*cmd, out: File::NULL, err: File::NULL) }

  # --- preflight (before touching anything) --------------------------------
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  abort "✗ not on main (on #{branch}). Releases are cut from main." unless branch == 'main'
  probe.call('git', 'cliff', '--version') or abort '✗ git-cliff not found — `brew install git-cliff`.'
  probe.call('gh', 'auth', 'status') or abort '✗ gh not authenticated — run `gh auth login`.'
  abort '✗ working tree is dirty — commit or stash first.' unless `git status --porcelain`.empty?

  run.call('git', 'fetch', '--quiet', 'origin', 'main', '--tags')
  if `git rev-parse HEAD`.strip != `git rev-parse origin/main`.strip
    abort '✗ local main differs from origin/main — `git pull` (or push your commits) first.'
  end

  # --- resolve + validate the target version (no writes yet) ---------------
  # Decide the version from the arg (a bump) or version.rb, and run every check
  # that can reject the release BEFORE touching version.rb — otherwise a rejected
  # release (e.g. an already-tagged version) would leave the tree dirty and block
  # a clean re-run.
  version = version_arg&.delete_prefix('v') || File.read(VERSION_FILE)[/VERSION = '([^']*)'/, 1] or
    abort "✗ no VERSION in #{VERSION_FILE}."
  version.match?(/\A\d+\.\d+\.\d+(\.[A-Za-z0-9]+)*\z/) or
    abort "✗ invalid version #{version.inspect} (expected e.g. 6.3.1 or 6.3.1.beta.1)."
  tag = "v#{version}"

  # A released version can never be reused on RubyGems, so refuse a taken tag.
  abort "✗ tag #{tag} already exists locally." if probe.call('git', 'rev-parse', '-q', '--verify', "refs/tags/#{tag}")
  abort "✗ #{tag} is already released (tag on origin) — bump the version." \
    unless `git ls-remote --tags origin "refs/tags/#{tag}"`.empty?

  # The gem version tracks the neo4j-java-driver version (see RELEASING.md), so
  # the JRuby gemspec's jar pins must match version.rb's base version (ignoring
  # any pre-release token). Otherwise a `release[X]` that bumped only version.rb
  # would publish a gem vendoring the wrong Java driver.
  java_pin = File.read(JAVA_GEMSPEC)[/neo4j-java-driver-all,\s*([\d.]+)/, 1]
  unless java_pin == version[/\A\d+\.\d+\.\d+/]
    abort "✗ version.rb targets #{version} but #{JAVA_GEMSPEC} pins the Java driver at #{java_pin} — " \
          'align the jar requirements (both track the same neo4j-java-driver version).'
  end

  # Checks passed — now it's safe to bump version.rb (only when a version was given).
  if version_arg
    src = File.read(VERSION_FILE)
    File.write(VERSION_FILE, src.sub(/VERSION = '[^']*'/, "VERSION = '#{version}'"))
  end

  # --- finalize changelog + land the commit on main ------------------------
  Rake::Task[:changelog].invoke(tag)
  run.call('git', 'add', VERSION_FILE, 'CHANGELOG.md')
  if probe.call('git', 'diff', '--cached', '--quiet')
    puts "• No version/changelog change to commit — main already holds #{tag}'s content."
  else
    # chore(release) is dropped by the changelog's notable-only filter, so the
    # release commit never shows up in its own CHANGELOG.
    run.call('git', 'commit', '--quiet', '-m', "chore(release): #{tag}")
    run.call('git', 'push', '--quiet', 'origin', 'main')
    puts "• Pushed #{tag}'s changelog commit to main."
  end

  # --- gate the irreversible publish, then tag -----------------------------
  unless ENV['RELEASE_YES'] == '1'
    print "\nAbout to tag #{tag} and push it — this publishes #{tag} to RubyGems " \
          "and cannot be undone.\nContinue? [y/N] "
    answer = $stdin.gets
    unless answer&.strip&.match?(/\A(y|yes)\z/i)
      abort 'Aborted before tagging. main already has the changelog commit; re-run `rake release` when ready.'
    end
  end

  run.call('git', 'tag', tag)
  run.call('git', 'push', 'origin', tag)
  puts "\n✓ Pushed #{tag}. Release workflow:\n  " \
       'https://github.com/neo4jrb/neo4j-ruby-driver/actions/workflows/release.yml'
end

desc 'Cut a release: finalize CHANGELOG, push main, tag, and trigger publish ' \
     '(version from version.rb; pass one to bump first, e.g. rake "release[6.3.1]")'
task(:release, [:version]) { |_task, args| cut_release(args[:version]) }

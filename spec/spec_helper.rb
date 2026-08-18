# frozen_string_literal: true

impl = RUBY_PLATFORM == 'java' ? 'jruby' : 'mri'
$LOAD_PATH.unshift File.expand_path('shared', __dir__),
                   File.expand_path(impl, __dir__)

require 'async'
# require 'async/rspec' unless RUBY_PLATFORM == 'java'
# require 'async/rspec/reactor'
require 'neo4j/driver'
require 'active_support/core_ext/object'
require 'active_support/core_ext/numeric/time'
require 'bigdecimal'
require 'ffaker'
require 'logger'
require 'rspec/its'
require 'support/driver_helper'
require 'support/neo4j_cleaner'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include DriverHelper::Helper
  include DriverHelper::Helper
  include Neo4jCleaner

  config.define_derived_metadata do |metadata|
    metadata[:timeout] = 9999
  end
  config.before(:suite, &:clean)
  config.after(:suite) { driver.close }
  config.threadsafe = false
  config.around { |example| cleaning(&example.method(:run)) }

  config.filter_run_excluding auth: :none
  config.filter_run_excluding version: method(:not_version?)
  # LOAD CSV with a file:// URL reads from the *server's* import directory, so
  # it only runs when one is reachable — TEST_NEO4J_IMPORT_DIR points at a
  # directory the running Neo4j serves as its import dir (mounted there). Absent
  # that (e.g. a service-container CI with no shared volume) the test is skipped,
  # not failed. Passes on both flavors when the import dir is provided. Require a
  # usable directory (present, non-empty, exists, writable) so a blank or stale
  # value skips the spec rather than running it into a Tempfile error.
  import_dir = ENV.fetch('TEST_NEO4J_IMPORT_DIR', nil)
  usable_import_dir = import_dir && !import_dir.empty? && Dir.exist?(import_dir) && File.writable?(import_dir)
  config.filter_run_excluding csv: true unless usable_import_dir
  # When targeting Memgraph, skip specs marked `memgraph: false` — Neo4j-only
  # features (routing, bookmarks, multi-database admin, APOC, auth management,
  # byte params, month-durations, server-version assertions). The rest of the
  # shared suite runs unchanged. See docs/memgraph.md.
  config.filter_run_excluding memgraph: false if memgraph?
  config.exclude_pattern = "#{Neo4j::Driver::Loader.jruby? ? 'mri' : 'jruby'}/**/*_spec.rb"
  Neo4j::Driver::Internal::Deprecator.deprecator.behavior = :silence
end

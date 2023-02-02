# frozen_string_literal: true

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', RUBY_PLATFORM == 'java' ? 'jruby' : 'ruby')

require 'async'
# require 'async/rspec' unless RUBY_PLATFORM == 'java'
# require 'async/rspec/reactor'
require 'active_support/logger'
require 'ffaker'
require 'neo4j/driver'
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
  config.filter_run_excluding concurrency: true unless RUBY_PLATFORM == 'java'
  config.exclude_pattern = 'spec/ruby/**/*_spec.rb' if RUBY_PLATFORM == 'java'
end

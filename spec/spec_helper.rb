# frozen_string_literal: true

$LOAD_PATH.unshift File.join(
  File.dirname(__FILE__),
  '..',
  case ENV['driver']
  when 'java'
    'jruby'
  when 'ruby'
    'ruby'
  else
    'ffi'
  end
)

require 'active_support/logger'
require 'ffaker'
require 'neo4j_ruby_driver'
require 'parallel'
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
  # config.include Neo4jCleaner
  include DriverHelper::Helper
  include Neo4jCleaner
  config.before(:suite, &:clean)
  config.after(:suite) { driver.close }
  config.around { |example| cleaning(&example.method(:run)) }

  config.filter_run_excluding auth: :none
  config.filter_run_excluding version: method(:not_version?)
  config.filter_run_excluding concurrency: true unless RUBY_PLATFORM == 'java'
end

# frozen_string_literal: true

# Testkit backend for the Neo4j Ruby driver.
#
# Testkit (https://github.com/neo4j-drivers/testkit) is the shared
# integration/conformance test suite for Neo4j drivers. Its Python test
# runner talks to a language-specific "backend" process over a TCP
# socket using a framed JSON protocol. This is the entry point for
# the Ruby backend.
#
# Run it standalone for local development:
#   bundle exec ruby testkit-backend/backend.rb [PORT]
#
# Then from a testkit clone:
#   export TEST_DRIVER_NAME=ruby
#   python3 -m unittest tests.stub.basic_query.test_basic_query

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'active_support/all'
require 'json'
require 'neo4j/driver'
require 'nio'
require 'ostruct'
require 'socket'
require_relative 'loader'

TestkitBackend::Loader.load

if $PROGRAM_NAME == __FILE__
  port = Integer(ARGV[0] || ENV.fetch('TEST_BACKEND_PORT', 9876))
  TestkitBackend::Runner.new(port).run
end

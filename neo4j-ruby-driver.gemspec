# frozen_string_literal: true

require_relative 'build/gemspec_common'

Gem::Specification.new do |spec|
  spec.platform = Gem::Platform::RUBY
  common_gemspec(spec, 'mri')
  spec.add_dependency 'connection_pool', '~> 3.0'
  # Pipeline-first Bolt::Connection: the driver runs all connection IO
  # (read + write) as fibers on an Async reactor, so reads and writes are
  # fully independent (HELLO+LOGON pipelining, recv-timeout liveness,
  # pipelined RESET). See docs/pipelined-connection.md.
  spec.add_dependency 'async', '~> 2.0'
end

# frozen_string_literal: true

require 'connection_pool'
require 'set'
require 'socket'
require 'stringio'
require 'time'
require 'tzinfo'
require 'uri'
require 'zeitwerk'

module Neo4j
  module Driver
    def self.implementation = (RUBY_PLATFORM == 'java') ? :jruby : :mri
  end
end

# `__dir__` resolves to:
#   dev:           lib/shared/neo4j  → shared_root = lib/shared
#   installed gem: lib/neo4j         → shared_root = lib (the impl dir is
#                                       merged in by the staged build, so
#                                       impl_root below is missing and the
#                                       conditional push is skipped)
shared_root = File.expand_path('..', __dir__)
impl_root = File.expand_path("../#{Neo4j::Driver.implementation}", shared_root)

loader = Zeitwerk::Loader.new
loader.inflector = Zeitwerk::GemInflector.new(__FILE__)
loader.inflector.inflect('packstream' => 'PackStream')
loader.push_dir(shared_root)
loader.push_dir(impl_root) if File.directory?(impl_root)
loader.ignore(__FILE__)
loader.setup
loader.eager_load

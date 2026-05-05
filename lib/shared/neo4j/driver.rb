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
    # Picked by the gemspec Bundler/RubyGems actually selected, via
    # spec.metadata['impl']. This stays correct under
    # `bundle config force_ruby_platform true` (JRuby user opting into
    # the MRI flavor), where RUBY_PLATFORM and the loaded gem disagree.
    # Falls back to RUBY_PLATFORM when the spec isn't visible (e.g. running
    # straight against the source tree without RubyGems activation).
    def self.implementation
      declared = Gem.loaded_specs['neo4j-ruby-driver2']&.metadata&.fetch('impl', nil)
      return declared.to_sym if declared
      (RUBY_PLATFORM == 'java') ? :jruby : :mri
    end
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

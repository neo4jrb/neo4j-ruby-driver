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
    # Picked from the gemspec Bundler/RubyGems actually selected, via
    # spec.metadata['impl']. Stays correct when the user opts into the
    # MRI flavor on JRuby (e.g. `gem 'neo4j-ruby-driver',
    # force_ruby_platform: true` in their Gemfile), where the host Ruby
    # and the loaded gem disagree.
    #
    # No RUBY_PLATFORM fallback: the cross-flavor mode makes
    # RUBY_PLATFORM == 'java' a misleading proxy for "JRuby flavor"
    # (it tells you the host, not the gem). When the spec metadata
    # isn't visible (raw source-tree without RubyGems activation),
    # default to :mri — that's the established flavor; consumers
    # wanting the JRuby flavor without Bundler need to load the gem
    # through Bundler/RubyGems so the metadata bridge works.
    def self.implementation
      declared = Gem.loaded_specs['neo4j-ruby-driver']&.metadata&.fetch('impl', nil)
      declared&.to_sym || :mri
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

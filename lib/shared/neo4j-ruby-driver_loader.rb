# frozen_string_literal: true

require 'date'
require 'forwardable'
require 'time'
require 'uri'
require 'zeitwerk'

module Neo4j
  module Driver
    class Loader
      class << self
        # `__dir__` resolves to:
        #   dev:           lib/shared  → shared_root = lib/shared
        #   installed gem: lib         → shared_root = lib (the impl dir is
        #                                       merged in by the staged build, so
        #                                       impl_root below is missing and the
        #                                       conditional push is skipped)
        def load(impl)
          @impl = impl
          shared_root = File.expand_path(__dir__)
          impl_root = File.expand_path("../#{impl}", shared_root)

          loader = Zeitwerk::Loader.new
          loader.tag = 'neo4j-ruby-driver'
          loader.inflector = Zeitwerk::GemInflector.new(File.expand_path('neo4j/driver', __dir__))
          loader.inflector.inflect('packstream' => 'PackStream')
          loader.push_dir(shared_root)
          loader.push_dir(impl_root) if File.directory?(impl_root)
          yield loader if block_given?
          # ignore the Bundler.require-friendly entry files (neo4j-ruby-driver.rb, neo4j-ruby-driver_loader.rb,
          # neo4j_ruby_driver.rb) since Zeitwerk would otherwise try to
          # autoload them as constants with the wrong names.
          loader.ignore(File.expand_path(__FILE__))
          loader.ignore(File.expand_path('neo4j-ruby-driver.rb', __dir__))
          loader.ignore(File.expand_path('neo4j_ruby_driver.rb', __dir__))
          loader.setup
          loader.eager_load
        end

        def jruby? = @impl == :jruby

        def mri? = @impl == :mri
      end
    end
  end
end

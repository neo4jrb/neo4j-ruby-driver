# frozen_string_literal: true

require 'date'
require 'uri'
require 'zeitwerk'

module Neo4j
  module Driver
    class Loader
      # `__dir__` resolves to:
      #   dev:           lib/shared  → shared_root = lib/shared
      #   installed gem: lib         → shared_root = lib (the impl dir is
      #                                       merged in by the staged build, so
      #                                       impl_root below is missing and the
      #                                       conditional push is skipped)
      def self.load(impl)
        shared_root = File.expand_path(__dir__)
        impl_root = File.expand_path("../#{impl}", shared_root)

        loader = Zeitwerk::Loader.new
        loader.tag = 'neo4j-ruby-driver'
        loader.inflector = Zeitwerk::GemInflector.new( File.expand_path('neo4j/driver', __dir__))
        loader.inflector.inflect('packstream' => 'PackStream')
        loader.push_dir(shared_root)
        loader.push_dir(impl_root) if File.directory?(impl_root)
        yield loader if block_given?
        loader.ignore(File.expand_path('neo4j*ruby*driver*.rb', __dir__))
        loader.setup
        loader.eager_load
      end
    end
  end
end

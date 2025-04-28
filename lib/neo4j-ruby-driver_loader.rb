# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/isolated_execution_state' if Gem::Requirement.create('>= 7').satisfied_by?(Gem.loaded_specs["activesupport"].version) # TODO: this should not be necessary https://github.com/rails/rails/issues/43851
require 'active_support/deprecator' if Gem::Requirement.create('>= 7.1').satisfied_by?(Gem.loaded_specs["activesupport"].version)
require 'active_support/deprecation'
require 'active_support/core_ext/numeric/time'
require 'active_support/duration'
require 'active_support/time'
require 'date'
require 'uri'
require 'zeitwerk'

module Neo4j
  module Driver
    class Loader
      def self.load
        loader = Zeitwerk::Loader.new
        loader.tag = 'neo4j-ruby-driver'
        loader.push_dir(File.expand_path(__dir__))
        driver_specific_dir = File.dirname(File.dirname(caller_locations(1..1).first.path))
        loader.push_dir(driver_specific_dir)
        yield loader if block_given?
        loader.ignore(File.expand_path('neo4j*ruby*driver*.rb', __dir__))
        loader.ignore(File.expand_path('org', __dir__))
        loader.inflector = Zeitwerk::GemInflector.new(File.expand_path('neo4j/driver', driver_specific_dir))
        loader.setup
        loader.eager_load
      end
    end
  end
end

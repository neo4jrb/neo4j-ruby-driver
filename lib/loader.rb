# frozen_string_literal: true

require 'zeitwerk'

class Loader
  def self.load
    loader = Zeitwerk::Loader.new
    loader.tag = 'neo4j-ruby-driver'
    loader.push_dir(File.expand_path(__dir__))
    driver_specific_dir = File.dirname(File.dirname(caller_locations(1..1).first.path))
    loader.push_dir(driver_specific_dir)
    yield loader if block_given?
    loader.ignore(File.expand_path('neo4j*ruby*driver*.rb', __dir__))
    loader.ignore(File.expand_path('shared.rb', __dir__))
    loader.ignore(File.expand_path('org', __dir__))
    loader.inflector = Zeitwerk::GemInflector.new(File.expand_path('neo4j/driver', driver_specific_dir))
    loader.setup
    loader.eager_load
  end
end

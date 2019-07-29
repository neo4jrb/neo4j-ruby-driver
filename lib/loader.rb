# frozen_string_literal: true

require 'zeitwerk'

class Loader
  def self.load
    loader = Zeitwerk::Loader.new
    loader.tag = 'neo4j-ruby-driver'
    loader.push_dir(File.expand_path(__dir__))
    loader.push_dir(File.dirname(File.dirname(caller_locations(1..1).first.path)))
    loader.ignore(File.expand_path('neo4j-ruby-driver_jars.rb', __dir__))
    loader.ignore(File.expand_path('neo4j_ruby_driver.rb', __dir__))
    loader.ignore(File.expand_path('org', __dir__))
    loader.inflector = Zeitwerk::GemInflector.new(File.expand_path('neo4j/driver', __dir__))
    loader.setup
    loader.eager_load
  end
end

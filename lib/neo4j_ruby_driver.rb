# frozen_string_literal: true

require 'active_support/duration'
require 'active_support/time'
require 'neo4j/driver'

require 'zeitwerk'
require 'zeitwerk/neo4j_ruby_driver_inflector'

loader = Zeitwerk::Loader.new
loader.tag = "neo4j-ruby-driver"
lib_dir_path = File.expand_path File.dirname(__FILE__)
loader.push_dir(lib_dir_path)
loader.ignore("#{lib_dir_path}/neo4j-ruby-driver_jars.rb")

if ENV['SEABOLT_LIB']&.length&.positive?
  loader.push_dir(lib_dir_path.sub('lib', 'ffi'))
else
  loader.push_dir(lib_dir_path.sub('lib', 'jruby'))
end

loader.inflector = Neo4jRubyDriverInflector.new
loader.setup
loader.eager_load
Neo4j::Driver.after_zeitwerk_load_complete

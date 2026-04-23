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
  end
end

loader = Zeitwerk::Loader.new
loader.inflector = Zeitwerk::GemInflector.new(__FILE__)
loader.push_dir(File.expand_path('..', __dir__))
loader.ignore(__FILE__)
loader.inflector.inflect("packstream" => "PackStream")
loader.setup
loader.eager_load

# frozen_string_literal: true

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

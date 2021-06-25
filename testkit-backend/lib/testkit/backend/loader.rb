# frozen_string_literal: true

require 'zeitwerk'

module Testkit
  module Backend
    class Loader
      def self.load
        loader = Zeitwerk::Loader.new
        loader.tag = 'testkit-backend'
        loader.push_dir(File.expand_path('../..', __dir__))
        loader.inflector = Zeitwerk::GemInflector.new(File.expand_path('.', __dir__))
        loader.setup
        loader.eager_load
      end
    end
  end
end

# frozen_string_literal: true

require 'zeitwerk'

module TestkitBackend
  module Loader
    def self.load
      loader = Zeitwerk::Loader.new
      loader.tag = 'testkit-backend'
      loader.push_dir(__dir__, namespace: TestkitBackend)
      # backend.rb is the entry point (it requires this file); loader.rb
      # is this file. Both must stay outside Zeitwerk's purview.
      loader.ignore("#{__dir__}/backend.rb", __FILE__)
      loader.inflector.inflect(
        'check_multi_d_b_support' => 'CheckMultiDBSupport',
        'cypher_date_time' => 'CypherDateTime'
      )
      loader.setup
      loader.eager_load
    end
  end
end

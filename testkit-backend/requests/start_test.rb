# frozen_string_literal: true

module TestkitBackend
  module Requests
    class StartTest < Data.define(:test_name)
      include Request

      def execute
        Response::RunTest.new
      end
    end
  end
end

# frozen_string_literal: true

module TestkitBackend
  module Requests
    class StartSubTest < Data.define(:test_name, :subtest_arguments)
      include Request

      def execute
        Response::RunTest.new
      end
    end
  end
end

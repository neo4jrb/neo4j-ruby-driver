# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < RuntimeError
        attr_reader :code, :suppressed

        def initialize(message = nil, code: nil, suppressed: nil)
          super(message)
          @code = code
          @suppressed = Array(suppressed)
        end

        def add_suppressed(*exceptions)
          @suppressed.concat(exceptions)
        end
      end
    end
  end
end

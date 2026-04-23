# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < StandardError
        attr_reader :code, :suppressed

        def initialize(message = nil, code: nil, suppressed: [])
          super(message)
          @code = code
          @suppressed = suppressed
        end
      end
    end
  end
end

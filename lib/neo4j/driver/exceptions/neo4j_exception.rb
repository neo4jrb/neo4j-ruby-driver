# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < RuntimeError
        attr_reader :code, :cause

        def initialize(code, message, cause = nil)
          super(message)
          @code = code
          @cause = cause
        end
      end
    end
  end
end

# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < RuntimeError
        attr_reader :code, :message, :code
        def initialize(code, message, cause)

        end
      end
    end
  end
end

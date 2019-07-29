# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < RuntimeError
        attr_reader :code, :cause

        def initialize(*args)
          @code = args.shift if args.count > 1
          message = args.shift
          @cause = args.shift
          super(message)
        end
      end
    end
  end
end

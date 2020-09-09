# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < RuntimeError
        attr_reader :code, :suppressed

        def initialize(*args)
          @code = args.shift if args.count > 1
          message = args.shift
          @suppressed = args.shift
          super(message)
        end

        def add_suppressed(exception)
          (@suppressed ||= []) << exception
        end
      end
    end
  end
end

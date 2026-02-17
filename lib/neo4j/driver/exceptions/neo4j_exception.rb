# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < RuntimeError
        attr_reader :code, :suppressed

        def initialize(*args)
          add_suppressed(args.pop) if args.last.is_a?(Exception)
          super(args.pop)
          @code = args.pop
        end

        def add_suppressed(exception)
          (@suppressed ||= []) << exception
        end
      end
    end
  end
end

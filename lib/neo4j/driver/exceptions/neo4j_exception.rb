# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class Neo4jException < RuntimeError
        attr_reader :code, :suppressed

        def initialize(*args)
          args, exceptions = args.partition { |arg| arg.is_a?(String) }
          super(args.pop)
          @code = args.pop
          add_suppressed(*exceptions)
        end

        def add_suppressed(*exceptions)
          (@suppressed ||= []).concat(exceptions) if exceptions.any?
        end
      end
    end
  end
end

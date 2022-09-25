module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class Controller < ConnectionPool
          def initialize(limit: nil, acquisition_timeout: nil, &block)
            super(size: limit, timeout: acquisition_timeout, &block)
            @available = TimedStack.new(@size, &block)
          end

          def acquire(options = {})
            @available.pop(options[:timeout] || @timeout)
          end

          def release(resource)
            @available.push(resource)
            nil
          end

          def close
            @available.shutdown(&:close)
          end

          def busy?
            @available.any_resource_busy?
          end
        end
      end
    end
  end
end

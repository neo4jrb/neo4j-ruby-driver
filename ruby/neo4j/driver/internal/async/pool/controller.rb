module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class Controller < ConnectionPool
          def initialize(limit: nil, acquisition_timeout: nil, &block)
            super(size: limit, timeout: acquisition_timeout, &block)
            @available = TimedStack.new(@size, &block)
          end

          def checkout(options = {})
            @available.pop(options[:timeout] || @timeout)
          end

          def checkin(resource)
            @available.push(resource)
            nil
          end

          def busy?
            @available.any_resource_busy?
          end

          def shutdown
            @available.shutdown { |channel| channel.close }
          end

          alias acquire checkout
          alias release checkin
          alias close shutdown
        end
      end
    end
  end
end

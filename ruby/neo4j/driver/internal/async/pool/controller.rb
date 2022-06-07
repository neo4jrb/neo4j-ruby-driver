module Neo4j::Driver
  module Internal
    module Async
      module Pool
        class Controller < ::Async::Pool::Controller
          def initialize(constructor, limit: nil, concurrency: nil, acquisition_timeout: nil)
            super(constructor, limit: limit, concurrency: concurrency)
            @acquisition_timeout = acquisition_timeout
          end

          def wait_for_resource
            case @acquisition_timeout
            when nil
              super
            when 0
              available_resource or raise ::Async::TimeoutError
            else
              ::Async::Task.current.with_timeout(@acquisition_timeout) { super }
            end
          end
        end
      end
    end
  end
end

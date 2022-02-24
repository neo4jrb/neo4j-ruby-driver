module Neo4j::Driver
  module Internal
    module Async
      class LeakLoggingNetworkSession < NetworkSession
        def initialize(connection_provider, retry_logic, database_name, mode, bookmark_holder, impersonated_user, fetch_size, logger)
          super
          @stack_trace = capture_stack_trace
        end

        def finalize
          log_leak_if_needed
          super
        end

        private

        def log_leak_if_needed
          is_open = Util::Futures.blocking_get(current_connection_is_open)
          if is_open
            @log.error do
              "Neo4j Session object leaked, please ensure that your application fully consumes results in "\
              "Sessions or explicitly calls `close` on Sessions before disposing of the objects.\n"\
              "Session was created at:\n#{@stack_trace}"
            end
          end
        end

        def capture_stack_trace
          Thread.current.backtrace.join("\n")
        end
      end
    end
  end
end

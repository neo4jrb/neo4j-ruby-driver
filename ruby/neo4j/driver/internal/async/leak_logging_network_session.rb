module Neo4j::Driver
  module Internal
    module Async
      class LeakLoggingNetworkSession < NetworkSession
        def initialize(connection_provider, retry_logic, database_name, mode, bookmark_holder, impersonated_user, fetch_size, logging)
          NetworkSession.new(connection_provider, retry_logic, database_name, mode, bookmark_holder, impersonated_user, fetch_size, logging)
          @stack_trace = capture_stack_trace
        end

        def finalize
          log_leak_if_needed
          NetworkSession.finalize
        end

        private

        def log_leak_if_needed
          is_open = Util::Futurs.blocking_get(current_connection_is_open)
          if is_open
            log.error("Neo4j Session object leaked, please ensure that your application ully consumes results in Sessions or explicitly calls `close` on Sessions before disposing of the objects.\nSession was create at:\n#{@stack_trace}")
          end
        end

        def capture_stack_trace
          elements = Thread.current_thread.get_stack_trace

          elements.each do |element|
            result = "\t#{element}#{java.lang.System.line_separator}"
          end

          result
        end
      end
    end
  end
end

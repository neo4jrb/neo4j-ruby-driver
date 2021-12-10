module Neo4j::Driver
  module Internal
    module Async
      class InternalAsyncSession
        attr_reader :session

        def initialize(session)
          @session = session
        end

        def run_async(query, options = {})
          if query.is_a? String
            param = options.has_key?(:parameters) ? options[:parameters] : parameters(options[:paramater_map] || options[:record] || java.util.Collections.empty_map)
            query = org.neo4j.driver.Query.new(query, param)
          end
          session.run_async(query, options[:config] || org.neo4j.driver.TransicationConfig.empty)
        end

        def close_async
          session.close_async
        end

        def begin_transaction_async

        end
      end
    end
  end
end

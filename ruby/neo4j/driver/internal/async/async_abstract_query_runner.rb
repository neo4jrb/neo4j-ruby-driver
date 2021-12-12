module Neo4j::Driver
  module Internal
    module Async
      class AsyncAbstractQueryRunner
        def run_async(query, options = {})
          param = options.has_key?(:parameters) ? options[:parameters] : parameters(options[:paramater_map] || options[:record] || java.util.Collections.empty_map) # options[:record] rakhvi chhe ke nai e joje
          query = Query.new(query, param)
        end
      end
    end
  end
end

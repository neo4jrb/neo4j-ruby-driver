#frozen_string_literal : true

module Neo4j
  module Driver
    module Internal
      module Summary
        class InternalResultSummary
          attr_reader :server, :counters
          def initialize(bolt_connection)
            @server = InternalServerInfo.new(bolt_connection)
            metadata = Neo4j::Driver::Value.to_ruby(Bolt::Connection.metadata(bolt_connection))
            puts "metedata=#{metadata}"
            @counters = InternalSummaryCounters.new(metadata[:stats])
          end
        end
      end
    end
  end
end
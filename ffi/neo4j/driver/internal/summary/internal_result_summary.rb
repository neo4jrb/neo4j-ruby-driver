#frozen_string_literal : true

module Neo4j
  module Driver
    module Internal
      module Summary
        class InternalResultSummary
          attr_reader :server, :counters, :plan, :profile, :statement, :statement_type
          alias has_plan? plan
          alias has_profile? profile

          def initialize(statement, bolt_connection)
            @statement = statement
            @server = InternalServerInfo.new(bolt_connection)
            metadata = Value.to_ruby(Bolt::Connection.metadata(bolt_connection))
            @statement_type = metadata[:type]
            @counters = InternalSummaryCounters.new(metadata[:stats])
          end
        end
      end
    end
  end
end
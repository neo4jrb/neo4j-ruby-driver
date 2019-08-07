# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Summary
        class InternalResultSummary
          attr_reader :server, :counters, :plan, :profile, :statement, :statement_type, :result_available_after,
                      :result_consumed_after
          alias has_plan? plan
          alias has_profile? profile

          def initialize(statement, result_available_after, bolt_connection)
            @statement = statement
            @result_available_after = result_available_after
            @server = InternalServerInfo.new(bolt_connection)
            metadata = Value::ValueAdapter.to_ruby(Bolt::Connection.metadata(bolt_connection))
            @result_consumed_after = metadata[:result_consumed_after] || metadata[:t_last]
            @statement_type = metadata[:type]
            @counters = InternalSummaryCounters.new(metadata[:stats])
          end
        end
      end
    end
  end
end
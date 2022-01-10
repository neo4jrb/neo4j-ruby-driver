module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingProcedureResponse
        attr_reader :procedure, :records, :error

        def initialize(procedure, records = nil, error = nil)
          @procedure = procedure
          @records = records
          @error = error
        end

        def success?
          !records.nil?
        end
      end
    end
  end
end

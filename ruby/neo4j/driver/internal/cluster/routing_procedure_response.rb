module Neo4j::Driver
  module Internal
    module Cluster
      class RoutingProcedureResponse
        attr_reader :procedure

        def initialize(procedure, records: nil, error: nil)
          @procedure = procedure
          @records = records
          @error = error
        end

        def success?
          !@records.nil?
        end

        def records
          if success?
            @records
          else
            raise Exceptions::IllegalStateException, "Can't access records of a failed result #{@error}"
          end
        end

        def error
          if success?
            raise Exceptions::IllegalStateException, "Can't access error of a succeeded result #{@records}"
          else
            @error
          end
        end
      end
    end
  end
end

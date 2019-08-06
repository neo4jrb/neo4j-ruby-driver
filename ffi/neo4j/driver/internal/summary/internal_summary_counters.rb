#frozen_string_literal : true

module Neo4j
  module Driver
    module Internal
      module Summary
        class InternalSummaryCounters < Hash
          # attr_accessor *%i[nodes_created nodesDeleted relationships_created relationshipsDeleted properties_set
          #  labels_added labels_removed indexes_added indexes_removed constraints_added constraints_removed]
          def initialize(stats)
            super(0)
            stats&.each { |key, value| self[key.to_s.split('-').join('_').to_sym] = value }
          end

          def method_missing(method)
            self[method]
          end
        end
      end
    end
  end
end
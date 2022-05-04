# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          module InternalResultSummary
            %i[result_available_after result_consumed_after].each do |method|
              define_method(method) { super(Java::JavaUtilConcurrent::TimeUnit::MILLISECONDS) }
            end

            def query_type
              type = super
              type == Java::OrgNeo4jDriverSummary::QueryType::READ_WRITE ? 'rw' : type.to_s.split('').first.downcase
            end
          end
        end
      end
    end
  end
end

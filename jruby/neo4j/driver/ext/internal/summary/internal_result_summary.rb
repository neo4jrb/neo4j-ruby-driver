# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          module InternalResultSummary
            java_import org.neo4j.driver.summary.QueryType

            %i[result_available_after result_consumed_after].each do |method|
              define_method(method) do
                super(Java::JavaUtilConcurrent::TimeUnit::MILLISECONDS).then { |val| val unless val == -1 }
              end
            end

            def query_type
              case super
              when QueryType::READ_ONLY
                Driver::Summary::QueryType::READ_ONLY
              when QueryType::READ_WRITE
                Driver::Summary::QueryType::READ_WRITE
              when QueryType::WRITE_ONLY
                Driver::Summary::QueryType::WRITE_ONLY
              when QueryType::SCHEMA_WRITE
                Driver::Summary::QueryType::SCHEMA_WRITE
              end
            end
          end
        end
      end
    end
  end
end

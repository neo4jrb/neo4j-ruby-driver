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

            # Wire string ('r'/'w'/'rw'/'s'). Cannot delegate to
            # Driver::Summary::QueryType — on JRuby that constant
            # resolves to the Java QueryType enum (via include_package
            # in driver.rb), shadowing the Ruby module.
            QUERY_TYPE_WIRE = {
              QueryType::READ_ONLY => 'r',
              QueryType::READ_WRITE => 'rw',
              QueryType::WRITE_ONLY => 'w',
              QueryType::SCHEMA_WRITE => 's'
            }.freeze

            def query_type
              QUERY_TYPE_WIRE[super]
            end
          end
        end
      end
    end
  end
end

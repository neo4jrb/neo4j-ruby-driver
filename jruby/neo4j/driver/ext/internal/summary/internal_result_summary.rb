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

            def self.query_type(type)
              case type
              when Neo4j::Driver::Summary::QueryType::READ_ONLY
                'r'
              when Neo4j::Driver::Summary::QueryType::READ_WRITE
                'rw'
              when Neo4j::Driver::Summary::QueryType::WRITE_ONLY
                'w'
              when Neo4j::Driver::Summary::QueryType::SCHEMA_WRITE
                's'
              else
                raise Neo4j::Driver::Exceptions::ClientException, "Unknown query type: #{type}"
              end
            end
          end
        end
      end
    end
  end
end

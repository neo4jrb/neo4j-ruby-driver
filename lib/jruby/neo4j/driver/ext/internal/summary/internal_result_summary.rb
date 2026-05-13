# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          module InternalResultSummary
            %i[result_available_after result_consumed_after].each do |method|
              define_method(method) do
                super(Java::JavaUtilConcurrent::TimeUnit::MILLISECONDS).then { |val| val unless val == -1 }
              end
            end

            # Driver::Summary::QueryType lives in lib/shared/, so Zeitwerk
            # loads our Ruby module before Java's include_package tries to
            # auto-vivify the same constant. The Ruby module wins → both
            # flavors see the same wire-string constants. We still need
            # the Java enum in the case selector — use the fully-qualified
            # name rather than java_import (which would shadow our module).
            def query_type
              case super
              when Java::OrgNeo4jDriverSummary::QueryType::READ_ONLY    then Driver::Summary::QueryType::READ_ONLY
              when Java::OrgNeo4jDriverSummary::QueryType::READ_WRITE   then Driver::Summary::QueryType::READ_WRITE
              when Java::OrgNeo4jDriverSummary::QueryType::WRITE_ONLY   then Driver::Summary::QueryType::WRITE_ONLY
              when Java::OrgNeo4jDriverSummary::QueryType::SCHEMA_WRITE then Driver::Summary::QueryType::SCHEMA_WRITE
              end
            end
          end
        end
      end
    end
  end
end

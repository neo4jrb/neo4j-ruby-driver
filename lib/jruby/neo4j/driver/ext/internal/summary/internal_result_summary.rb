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

            # Use the 6.2 QueryProfile (presence-aware Optional stats) rather
            # than the deprecated ProfiledPlan, so absent profile stats are
            # nil (omitted) instead of a defaulted 0. `plan` stays the plan
            # (no stats).
            def profile
              query_profile.or_else(nil)
            end

            # Driver::Summary::QueryType is a Ruby module in lib/shared/.
            # include_package only fills missing constants on a module via
            # const_missing — Java never overrides Ruby constants that
            # already exist, regardless of load order. So our Ruby module
            # wins on both flavours.
            #
            # The case selector still needs the Java enum. Fully-qualifying
            # Java::OrgNeo4jDriverSummary::QueryType keeps readers from
            # wondering whether `QueryType` here means the Ruby module or
            # the Java enum, and avoids a java_import line whose only job
            # would be to disambiguate this one method.
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

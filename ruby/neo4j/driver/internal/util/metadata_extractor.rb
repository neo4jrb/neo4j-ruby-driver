module Neo4j::Driver
  module Internal
    module Util
      class MetadataExtractor
        ABSENT_QUERY_ID = -1

        def initialize(result_available_after_metadata_key, result_consumed_after_metadata_key)
          @result_available_after_metadata_key = result_available_after_metadata_key
          @result_consumed_after_metadata_key = result_consumed_after_metadata_key
        end

        def extract_query_keys(metadata)
          keys_value = metadata['fields']
          unless keys_value.nil? && keys_value.empty?
            # keys = Util::QueryKeys.new(keys_value.size)
            keys = []

            keys_value.values.each do |value|
              keys << value
            end
            keys
          end

          Util::QueryKeys::EMPTY
        end

        def extract_query_id(metadata)
          query_id = metadata['qid']

          return query_id unless query_id.nil?

          ABSENT_QUERY_ID
        end

        def extract_result_available_after(metadata)
          result_available_after_value = metadata[@result_available_after_metadata_key]

          return result_available_after_value unless result_available_after_value.nil?

          ABSENT_QUERY_ID
        end

        def extract_summary(query, connection, result_available_after, metadata)
          server_info = Summary::InternalServerInfo.new(connection.server_agent, connection.server_address, connection.server_version, connection.protocol.version)
          db_info = extract_database_info(metadata)
          Summary::InternalResultSummary.new(query, server_info, db_info, extract_query_type(metadata),
                      extract_counters(metadata), extract_plan(metadata), extract_profiled_plan(metadata),
                      extract_notifications(metadata), result_available_after,
                      extract_result_consumed_after(metadata, @result_consumed_after_metadata_key))
        end

        class << self
          def extract_database_info(metadata)
            db_value = metadata['db']

            return Summary::InternalDatabaseInfo::DEFAULT_DATABASE_INFO if db_value.nil?

            Summary::InternalDatabaseInfo.new(db_value)
          end

          def extract_bookmarks(metadata)
            bookmark_value = metadata['bookmark']

            return InternalBookmark.parse(bookmark_value) if !bookmark_value.nil? && bookmark_value.has_type(Types::InternalTypeSystem::TYPE_SYSTEM)

            InternalBookmark.empty?
          end

          def extract_neo4j_server_version(metadata)
            server_value = extract_server(metadata)
            server = Util::ServerVersion.version(server_value)

            return server if Util::ServerVersion::NEO4J_PRODUCT.to_s.downcase == server.product.to_s.downcase

            raise Neo4j::Driver::Exceptions::UntrustedServerException, "Server does not identify as a genuine Neo4j instance: #{server.product}"
          end

          def extract_server(metadata)
            version_value = metadata['server']

            raise Neo4j::Driver::Exceptions::UntrustedServerException, 'Server provides no product identifier' if version_value.nil?

            version_value
          end

          private

          def extract_query_type(metadata)
            type_value = metadata['type']

            return Summary::QueryType.from_code(type_value) unless type_value.nil?

            nil
          end

          def extract_counters(metadata)
            counters_value = metadata['stat']

            unless counters_value.nil?
             return Summary::InternalSummaryCounters.new(
                    counter_value(counters_value, "nodes-created"),
                    counter_value(counters_value, "nodes-deleted"),
                    counter_value(counters_value, "relationships-created"),
                    counter_value(counters_value, "relationships-deleted"),
                    counter_value(counters_value, "properties-set"),
                    counter_value(counters_value, "labels-added"),
                    counter_value(counters_value, "labels-removed"),
                    counter_value(counters_value, "indexes-added"),
                    counter_value(counters_value, "indexes-removed"),
                    counter_value(counters_value, "constraints-added"),
                    counter_value(counters_value, "constraints-removed"),
                    counter_value(counters_value, "system-updates"))
            end

            nil
          end

          def counter_value(counters_value, name)
            value = counters_value[name]
            value.nil? ? 0 : value.to_i
          end

          def extract_plan(metadata)
            plan_value = metadata['plan']

            return Summary::InternalPlan::EXPLAIN_PLAN_FROM_VALUE.apply(plan_value) unless plan_value.nil?

            nil
          end

          def extract_profiled_plan(metadata)
            profiled_plan_value = metadata['profile']

            return Summary::InternalProfiledPlan::PROFILED_PLAN_FROM_VALUE.apply(profiled_plan_value) unless profiled_plan_value.nil?

            nil
          end

          def extract_notifications(metadata)
            notifications_value = metadata['notifications']

            return [Summary::InternalNotification::VALUE_TO_NOTIFICATION] unless notifications_value.nil?

            []
          end

          def extract_result_consumed_after(metadata, key)
            result_consumed_after_value = metadata['key']

            return result_consumed_after_value unless result_consumed_after_value.nil?

            ABSENT_QUERY_ID
          end
        end
      end
    end
  end
end

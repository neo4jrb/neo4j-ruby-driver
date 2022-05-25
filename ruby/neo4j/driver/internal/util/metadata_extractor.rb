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
          metadata[:fields]&.map(&:to_sym) || []
        end

        def extract_query_id(metadata)
          metadata[:qid] || ABSENT_QUERY_ID
        end

        def extract_result_available_after(metadata)
          metadata[@result_available_after_metadata_key]
        end

        def extract_summary(query, connection, result_available_after, metadata)
          server_info = Summary::InternalServerInfo.new(connection.server_agent, connection.server_address, connection.server_version, connection.protocol.version)
          db_info = self.class.extract_database_info(metadata)
          Summary::InternalResultSummary.new(
            query, server_info, db_info, self.class.extract_query_type(metadata), self.class.extract_counters(metadata),
            self.class.extract_plan(metadata), self.class.extract_profiled_plan(metadata),
            self.class.extract_notifications(metadata), result_available_after,
            self.class.extract_result_consumed_after(metadata, @result_consumed_after_metadata_key))
        end

        class << self
          def extract_database_info(metadata)
            metadata[:db]&.then(&Summary::InternalDatabaseInfo.method(:new)) ||
              Summary::InternalDatabaseInfo::DEFAULT_DATABASE_INFO
          end

          def extract_bookmarks(metadata)
            bookmark_value = metadata['bookmark']

            return InternalBookmark.parse(bookmark_value) if bookmark_value&.is_a? String

            InternalBookmark.empty
          end

          def extract_neo4j_server_version(metadata)
            server_value = extract_server(metadata)
            server = Util::ServerVersion.version(server_value)
            return server if Util::ServerVersion::NEO4J_PRODUCT.casecmp?(server.product)
            raise Neo4j::Driver::Exceptions::UntrustedServerException, "Server does not identify as a genuine Neo4j instance: #{server.product}"
          end

          def extract_server(metadata)
            metadata[:server].tap do |version_value|
              unless version_value
                raise Neo4j::Driver::Exceptions::UntrustedServerException, 'Server provides no product identifier'
              end
            end
          end

          def extract_query_type(metadata)
            metadata[:type]
          end

          def extract_counters(metadata)
            counters_value = metadata[:stat]

            counters_value &&
              Summary::InternalSummaryCounters.new(
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
                counter_value(counters_value, "system-updates")
              )
          end

          def counter_value(counters_value, name)
            counters_value[name]&.to_i || 0
          end

          def extract_plan(metadata)
            metadata['plan']&.then(Summary::InternalPlan::EXPLAIN_PLAN_FROM_VALUE)
          end

          def extract_profiled_plan(metadata)
            metadata['profile']&.then(Summary::InternalProfiledPlan::PROFILED_PLAN_FROM_VALUE)
          end

          def extract_notifications(metadata)
            metadata['notifications']&.then do |notifications|
              notifications.map(Summary::InternalNotification::VALUE_TO_NOTIFICATION)
            end
          end

          def extract_result_consumed_after(metadata, key)
            metadata[key]&.to_i
          end
        end
      end
    end
  end
end

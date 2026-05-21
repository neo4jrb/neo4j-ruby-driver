module TestkitBackend
  module Requests
    class ExecuteQuery < Request
      def process
        fetch(driver_id).execute_query(cypher, auth_token, query_config, **decode(params)).then do |er|
          named_entity(
            'EagerResult',
            keys: er.keys,
            records: er.records.map { Responses::Record.new(it).data },
            summary: Responses::Summary.new(er.summary).data
          )
        end
      end

      private

      # Translate testkit's QueryConfig (camelCase keys, 'r'/'w' routing,
      # CypherValue tx metadata, ms timeout, bookmark-manager id) into the
      # common Ruby execute_query config — mirroring how NewSession maps
      # 'r'/'w' to AccessMode. Ext::ConfigConverter passes the RoutingControl
      # straight through and maps the bookmark_manager sentinel.
      def query_config
        {
          routing: routing_control,
          database: config[:database],
          impersonated_user: config[:impersonatedUser],
          metadata: config[:txMeta] && decode(config[:txMeta]),
          timeout: timeout_duration(config[:timeout]),
          bookmark_manager: bookmark_manager
        }.compact
      end

      def routing_control
        case config[:routing]
        when 'r' then Neo4j::Driver::RoutingControl::READ
        when 'w' then Neo4j::Driver::RoutingControl::WRITE
        end
      end

      # absent -> driver default; -1 -> disabled (`false`, mapped to
      # withBookmarkManager(null)); otherwise the id of a NewBookmarkManager.
      def bookmark_manager
        id = config[:bookmarkManagerId]
        id == -1 ? false : fetch(id) unless id.nil?
      end
    end
  end
end

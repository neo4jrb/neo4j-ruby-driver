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
        cfg = {
          routing: routing_control,
          database: config[:database],
          impersonated_user: config[:impersonatedUser],
          metadata: config[:txMeta] && decode(config[:txMeta]),
          timeout: timeout_duration(config[:timeout])
        }.compact
        # bookmarkManagerId absent -> driver default (omit the key); -1 ->
        # disabled (nil -> withBookmarkManager(null)); otherwise a NewBookmarkManager.
        config.key?(:bookmarkManagerId) ? cfg.merge(bookmark_manager: bookmark_manager) : cfg
      end

      def routing_control
        case config[:routing]
        when 'r' then Neo4j::Driver::RoutingControl::READ
        when 'w' then Neo4j::Driver::RoutingControl::WRITE
        end
      end

      def bookmark_manager
        id = config[:bookmarkManagerId]
        fetch(id) unless id == -1
      end
    end
  end
end

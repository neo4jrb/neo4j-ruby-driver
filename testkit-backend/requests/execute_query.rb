module TestkitBackend
  module Requests
    class ExecuteQuery < Request
      def process
        fetch(driver_id).execute_query(cypher, decode(params), query_config).then do |er|
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
      # CypherValue tx metadata, ms timeout, bookmark-manager id) into
      # the common Ruby execute_query config hash (3rd positional arg
      # to driver.execute_query) — mirroring how NewSession maps 'r'/'w'
      # to AccessMode. The auth token (Feature:API:Driver.ExecuteQuery:
      # WithAuth) arrives nested as config[:authorizationToken], a testkit
      # AuthorizationToken entity — convert it to a real Neo4j AuthToken
      # like NewSession does. It rides along in config (driver-side: MRI
      # ignores it for now, JRuby pulls it back out before handing the
      # rest to Java's QueryConfig builder).
      def query_config
        cfg = {
          routing: routing_control,
          database: config[:database],
          impersonated_user: config[:impersonatedUser],
          metadata: config[:txMeta] && decode(config[:txMeta]),
          timeout: timeout_duration(config[:timeout]),
          auth_token: config[:authorizationToken] && Request.object_from(config[:authorizationToken])
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

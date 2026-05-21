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

      # bookmarkManagerId: absent -> driver default; -1 -> disabled
      # (translated to `false`, which Ext::ConfigConverter maps to
      # withBookmarkManager(null)); otherwise the id of a NewBookmarkManager.
      def query_config
        return config unless config&.key?(:bookmarkManagerId)

        id = config[:bookmarkManagerId]
        config.except(:bookmarkManagerId).merge(bookmark_manager: id == -1 ? false : fetch(id))
      end
    end
  end
end

module TestkitBackend
  module Requests
    class ExecuteQuery < Request
      def process
        fetch(driver_id).execute_query(cypher, auth_token, config, **decode(params)).then do |er|
          named_entity(
            'EagerResult',
            keys: er.keys,
            records: er.records.map { Responses::Record.new(it).data },
            summary: Responses::Summary.new(er.summary).data
          )
        end
      end
    end
  end
end

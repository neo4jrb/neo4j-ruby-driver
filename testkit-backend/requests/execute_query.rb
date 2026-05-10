# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Driver-level execute_query — runs a query in a managed transaction
    # and returns an EagerResult.
    #
    # Real impl in Driver#execute_query (lib/mri/neo4j/driver/driver.rb).
    # That method honours :database and :routing today; ignores other
    # config keys (impersonatedUser, bookmarkManagerId, txMeta, timeout,
    # authorizationToken) until the corresponding driver features land.
    class ExecuteQuery < Data.define(:driver_id, :cypher, :params, :config)
      include Request

      def execute
        decoded_params = params ? Cypher.decode_value_map(params) : {}
        eager = registry.fetch(driver_id).execute_query(cypher, decoded_params, config_kwargs)
        Response::EagerResult.new(
          keys: eager.keys,
          records: eager.records.map { |r| { 'values' => r.values.map { |v| Cypher.from_ruby(v) } } },
          summary: SummaryPayload.new(summary: eager.summary).to_h
        )
      end

      private

      def config_kwargs
        return {} if config.nil?

        # testkit may send any of: database, routing, impersonatedUser,
        # bookmarkManagerId, txMeta, timeout, authorizationToken.
        config.each_with_object({}) { |(k, v), acc| acc[Casing.underscore(k).to_sym] = v }
      end
    end
  end
end

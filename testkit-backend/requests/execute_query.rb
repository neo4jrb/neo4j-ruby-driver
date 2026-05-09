# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Driver-level execute_query — runs a query in a managed transaction
    # and returns an EagerResult (keys, materialised records, summary).
    # Convenience for "I just want results, don't make me build a session".
    #
    # DRIVER GAP: Neo4j::Driver::Driver doesn't have #execute_query. The
    # Java reference impl lives at org.neo4j.driver.Driver.executableQuery
    # / Session.executeQuery; the cleanest port is:
    #   Driver#execute_query(cypher, params = {}, config = {})
    #   ↳ session(database: config[:database], default_access_mode: …)
    #     ↳ execute_read/write { |tx| tx.run(cypher, params).to_a }
    #   ↳ wrap as EagerResult { keys, records, summary }.
    # Config knobs from testkit: database, routing ('w'/'r'),
    # impersonatedUser, bookmarkManagerId, txMeta, timeout,
    # authorizationToken. Honour what the driver supports; ignore the rest
    # for now.
    #
    # Until landed, stub.
    class ExecuteQuery < Data.define(:driver_id, :cypher, :params, :config)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'ExecuteQuery: Driver#execute_query not yet implemented (see handler comment).'
        )
      end
    end
  end
end

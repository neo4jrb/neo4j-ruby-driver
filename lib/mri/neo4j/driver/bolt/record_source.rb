# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Adapts a Connection to the source interface a Bolt::Pump drives:
      # `next_response` reads the next reply; `pull(n)` requests the next batch.
      # This is the seam between the prefetch pump and a live connection — the
      # pump is the single reader (it calls next_response), so the consumer only
      # ever touches the RecordBuffer, never the socket. The first batch's PULL
      # is sent by the caller (RUN+PULL pipelining); the pump issues the rest.
      class RecordSource
        def initialize(connection)
          @connection = connection
        end

        def next_response = @connection.fetch_response

        # Request the next batch. qid defaults to the latest result (-1), which
        # is correct for a single active stream per connection.
        def pull(n)
          @connection.send_message(@connection.protocol.build_pull(n: n))
          @connection.flush
        end
      end
    end
  end
end

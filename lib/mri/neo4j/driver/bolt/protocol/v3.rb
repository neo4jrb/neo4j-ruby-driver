# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 3.0 protocol handler — the oldest version the driver
        # speaks (matches the Java driver's matrix, which starts at 3.0).
        #
        # Differences from V4 that this class encodes:
        #   * Routing is the `dbms.cluster.routing.getRoutingTable`
        #     procedure (RUN), not a server ROUTE message — but the HELLO
        #     still carries the routing context, matching the Java driver
        #     (and so JRuby): testkit gates `routing` in the 3.0 HELLO on
        #     driver name java/ruby specifically.
        #   * Single-database: no `db` field on RUN / BEGIN. Inherits
        #     supports_multiple_databases? = false from Base, so the
        #     strip_db in build_run / build_begin happens automatically.
        #   * Streaming is all-or-nothing: PULL_ALL (0x3F) and
        #     DISCARD_ALL (0x2F) take no fields, unlike the 4.0+
        #     PULL / DISCARD which carry `{n, qid}`.
        class V3 < Base
          # HELLO is the inherited auth-in-HELLO form. On 3.0, `routing`
          # is the context for a neo4j:// driver and nil for bolt://
          # (compacted away), so a direct 3.0 connection sends no routing
          # key — matching the Java driver, which testkit gates on driver
          # name for the 3.0 HELLO.

          # PULL_ALL: no metadata map. The caller still passes `{n:}` for
          # the 4.0+ path; on 3.0 we discard it and send the bare struct.
          def build_pull(_extra)
            PackStream::Structure.new(Message::PULL, [])
          end

          # DISCARD_ALL: no metadata map.
          def build_discard(_extra)
            PackStream::Structure.new(Message::DISCARD, [])
          end
        end
      end
    end
  end
end

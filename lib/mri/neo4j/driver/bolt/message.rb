# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      # Bolt Protocol Messages
      module Message
        # Request messages (sent from client to server)
        HELLO = 0x01
        GOODBYE = 0x02
        RESET = 0x0F
        RUN = 0x10
        BEGIN_TX = 0x11
        COMMIT = 0x12
        ROLLBACK = 0x13
        PULL = 0x3F
        DISCARD = 0x2F
        ROUTE = 0x66
        LOGON = 0x6A
        LOGOFF = 0x6B
        TELEMETRY = 0x54

        # Response messages (sent from server to client)
        SUCCESS = 0x70
        RECORD = 0x71
        IGNORED = 0x7E
        FAILURE = 0x7F

        class << self
          # Note: HELLO message building is now handled by protocol-specific handlers
          # This method kept for backward compatibility but shouldn't be used directly
          def hello(user_agent:, auth:, routing: nil)
            extra = { user_agent: user_agent }
            extra[:routing] = routing if routing
            # Default to Bolt 5.0+ format (merged auth)
            extra.merge!(auth) if auth
            PackStream::Structure.new(HELLO, [extra])
          end

          def run(query, parameters = {}, extra = {})
            PackStream::Structure.new(RUN, [query, parameters, extra])
          end

          def begin_transaction(extra = {})
            PackStream::Structure.new(BEGIN_TX, [extra])
          end

          def commit
            PackStream::Structure.new(COMMIT, [])
          end

          def rollback
            PackStream::Structure.new(ROLLBACK, [])
          end

          # Caller must specify n explicitly — Java/Python default is 1000
          # records per batch but the call site (Session/Transaction) knows
          # the configured fetch_size and passes it through. Default-here
          # would silently mask "forgot to plumb fetch_size".
          def pull(extra = {})
            PackStream::Structure.new(PULL, [extra])
          end

          def discard(extra = {})
            extra = { n: -1 }.merge(extra)
            PackStream::Structure.new(DISCARD, [extra])
          end

          # Bolt 5.4+ TELEMETRY: reports which driver API opened the coming
          # transaction/query (0 tx-function, 1 unmanaged tx, 2 auto-commit,
          # 3 execute_query). Sent only when the server advertised
          # `telemetry.enabled` and the driver didn't disable it.
          def telemetry(api)
            PackStream::Structure.new(TELEMETRY, [api])
          end

          def reset
            PackStream::Structure.new(RESET, [])
          end

          def goodbye
            PackStream::Structure.new(GOODBYE, [])
          end

          # LOGON (Bolt 5.1+). Carries the auth fields that 5.0 used to
          # send inside HELLO. The server's success here marks the
          # connection authenticated and READY.
          def logon(auth)
            PackStream::Structure.new(LOGON, [auth || {}])
          end

          # LOGOFF (Bolt 5.1+). De-authenticates the connection; the
          # next LOGON re-authenticates with a possibly-different
          # token. Used by per-session auth (`driver.session(auth: …)`)
          # to switch identity on a pooled connection without tearing
          # it down.
          def logoff
            PackStream::Structure.new(LOGOFF, [])
          end

          # ROUTE (Bolt 4.3+) — fetch the cluster's routing table.
          #   routing_context  : map (typically built from the URI query string)
          #   bookmarks        : list of bookmarks (or nil for Bolt 4.3 compat)
          #   extra            : {db: <database or nil>, imp_user: <or nil>}
          def route(routing_context, bookmarks, extra)
            PackStream::Structure.new(ROUTE, [routing_context, bookmarks, extra])
          end
        end
      end
    end
  end
end

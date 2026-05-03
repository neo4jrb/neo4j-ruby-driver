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

          def pull(extra = {})
            # Default to pulling all records (n=-1)
            extra = { n: -1 }.merge(extra)
            PackStream::Structure.new(PULL, [extra])
          end

          def discard(extra = {})
            extra = { n: -1 }.merge(extra)
            PackStream::Structure.new(DISCARD, [extra])
          end

          def reset
            PackStream::Structure.new(RESET, [])
          end

          def goodbye
            PackStream::Structure.new(GOODBYE, [])
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

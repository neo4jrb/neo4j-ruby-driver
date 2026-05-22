# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.1. HELLO no longer carries auth — a separate LOGON
        # (signature 0x6A) follows immediately. This also unlocks
        # re-authentication on a live connection (`LOGOFF` + `LOGON`),
        # which the public driver doesn't expose yet but the protocol
        # supports from here on.
        class V5_1 < V5_0
          def hello_extra(user_agent:, auth:, routing:)
            { user_agent:, routing: }
          end

          def perform_post_hello(auth)
            connection.send_message(Message.logon(auth))
            connection.flush
            connection.fetch_response.assert_success!
          end

          def supports_re_auth? = true
        end
      end
    end
  end
end

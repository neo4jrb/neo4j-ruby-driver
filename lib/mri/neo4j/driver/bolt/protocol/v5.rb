# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.x protocol handler
        class V5 < V4
          # 5.1+ split auth into a separate LOGON message: the HELLO
          # map carries only user_agent + routing (no auth), and a
          # LOGON follows immediately with the auth fields. On 5.0
          # HELLO still carries auth (V4's behaviour), so fall through
          # to super.
          #
          # 5.3+ additionally requires a `bolt_agent` map identifying
          # the driver — product is required, the rest informational.
          def build_hello_message(user_agent:, auth:, routing: nil)
            return super if version < BoltVersion::V5_1

            extra = { user_agent:, routing: }.compact
            extra[:bolt_agent] = bolt_agent if version >= BoltVersion::V5_3
            PackStream::Structure.new(Message::HELLO, [extra])
          end

          def supports_notification_filtering?
            version >= BoltVersion::V5_7
          end

          def supports_re_auth?
            version >= BoltVersion::V5_1
          end

          private

          def bolt_agent
            {
              product: "neo4j-ruby-driver/#{Neo4j::Driver::VERSION}",
              language: "Ruby/#{RUBY_VERSION}",
              platform: RUBY_PLATFORM
            }
          end
        end
      end
    end
  end
end

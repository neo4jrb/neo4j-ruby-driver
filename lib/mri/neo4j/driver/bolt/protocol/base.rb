# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Base of the per-minor protocol class hierarchy. Mirrors Java's
        # BoltProtocolVxY family in `neo4j-bolt-connection-java` — each
        # minor version is its own subclass and only overrides what
        # changed at that version, instead of carrying a swarm of
        # `version >= V5_X` checks inside one big class.
        class Base
          attr_reader :version, :connection

          def initialize(connection, version)
            @connection = connection
            @version = version
          end

          # Top-level HELLO builder. The shape is fixed (one map argument);
          # subclasses override `hello_extra` to change which keys it
          # carries at their version.
          def build_hello_message(user_agent:, auth:, routing: nil)
            PackStream::Structure.new(Message::HELLO,
                                      [hello_extra(user_agent:, auth:, routing:).compact])
          end

          # Subclasses override this to add / remove fields from the
          # HELLO map. The defaults here are deliberately empty; V4 is
          # the first concrete protocol that fills them in.
          def hello_extra(user_agent:, auth:, routing:)
            raise NotImplementedError, "#{self.class} must implement hello_extra"
          end

          # Hook for V5_1+ (HELLO/LOGON split): after HELLO succeeds, the
          # connection calls this to send LOGON and assert its SUCCESS.
          # Older versions authenticated inside HELLO itself, so this is
          # a no-op.
          def perform_post_hello(_auth); end

          # Hook for V5_0+: lets the protocol flip the packer's UTC
          # datetime flag (0x49 / 0x69 vs legacy 0x46 / 0x66).
          def configure_packer(_packer); end

          def supports_re_auth? = false
          def supports_multiple_databases? = false
          def supports_notification_filtering? = false
        end
      end
    end
  end
end

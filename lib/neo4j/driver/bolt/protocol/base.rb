# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Base class for version-specific protocol implementations
        class Base
          attr_reader :version, :connection

          def initialize(connection, version)
            @connection = connection
            @version = version
          end

          # Build HELLO message - overridden by subclasses
          def build_hello_message(user_agent:, auth:, routing: nil)
            raise NotImplementedError, "Subclasses must implement build_hello_message"
          end

          # Whether this version supports re-authentication
          def supports_re_auth?
            false
          end

          # Whether this version supports multiple databases
          def supports_multiple_databases?
            false
          end

          # Whether this version supports notification filtering
          def supports_notification_filtering?
            false
          end
        end
      end
    end
  end
end

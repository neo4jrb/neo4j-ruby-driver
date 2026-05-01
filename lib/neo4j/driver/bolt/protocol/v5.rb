# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.x protocol handler
        class V5 < V4
          def supports_notification_filtering?
            version >= BoltVersion::V5_7
          end

          def supports_re_auth?
            version >= BoltVersion::V5_1
          end
        end
      end
    end
  end
end

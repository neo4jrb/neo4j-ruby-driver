# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.2. Server now honours notification-filtering fields in
        # HELLO (`notifications_minimum_severity`,
        # `notifications_disabled_categories`). We don't plumb a public
        # NotificationsConfig API through the driver yet, so HELLO still
        # ships without those keys — but the capability flag flips on so
        # any caller that does set them gets them through.
        class V5_2 < V5_1
          def supports_notification_filtering? = true
        end
      end
    end
  end
end

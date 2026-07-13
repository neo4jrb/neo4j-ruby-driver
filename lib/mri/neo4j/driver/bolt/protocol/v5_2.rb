# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Protocol
        # Bolt 5.2. Server now honours notification-filtering fields in
        # HELLO (`notifications_minimum_severity`,
        # `notifications_disabled_categories`). The driver's
        # NotificationsConfig (a `{minimum_severity:, disabled_categories:}`
        # hash, or nil) is mapped straight onto those keys here; the outer
        # `build_hello_message.compact` drops an unset severity while keeping
        # an explicit empty `disabled_categories: []` (which the server reads
        # as "re-enable every category").
        class V5_2 < V5_1
          def supports_notification_filtering? = true

          def notification_config_extra(config)
            return {} unless config

            { notifications_minimum_severity: config[:minimum_severity],
              notifications_disabled_categories: config[:disabled_categories] }
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # Exposes the Java notification severity's `type` under the Ruby
        # driver's `name` accessor.
        module InternalNotificationSeverity
          extend Forwardable

          delegate name: :type
        end
      end
    end
  end
end

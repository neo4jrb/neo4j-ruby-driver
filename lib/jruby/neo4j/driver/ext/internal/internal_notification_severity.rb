# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module InternalNotificationSeverity
          extend Forwardable
          delegate name: :type
        end
      end
    end
  end
end

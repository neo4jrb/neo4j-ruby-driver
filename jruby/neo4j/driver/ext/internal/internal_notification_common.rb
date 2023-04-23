module Neo4j
  module Driver
    module Ext
      module Internal
        module InternalNotificationCommon
          def type
            super.to_s
          end
        end
      end
    end
  end
end

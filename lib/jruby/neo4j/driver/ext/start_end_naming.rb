# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Exposes a path or segment's Java start()/end() as start_node/end_node
      # (`end` being a Ruby keyword).
      module StartEndNaming
        def start_node
          java_send(:start)
        end

        def end_node
          java_send(:end)
        end
      end
    end
  end
end

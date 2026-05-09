# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
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

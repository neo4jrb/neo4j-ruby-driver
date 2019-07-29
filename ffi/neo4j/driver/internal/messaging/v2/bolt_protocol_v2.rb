# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Messaging
        module V2
          class BoltProtocolV2 < V1::BoltProtocolV1
            VERSION = 2
            INSTANCE = new
          end
        end
      end
    end
  end
end
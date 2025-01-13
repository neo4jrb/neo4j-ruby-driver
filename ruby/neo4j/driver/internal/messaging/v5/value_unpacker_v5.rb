module Neo4j::Driver
  module Internal
    module Messaging
      module V5
        class ValueUnpackerV5 < Async::Connection::StreamReader
          alias unpack_element_id unpack

          def node_fields = 4

          def relationship_fields = 8

          def unbound_relationship_fields = 4
        end
      end
    end
  end
end

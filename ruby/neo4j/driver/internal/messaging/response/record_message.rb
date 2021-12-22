module Neo4j::Driver
  module Internal
    module Messaging
      module Response
        class RecordMessage
          SIGNATURE = 0x71

          attr_reader :fields

          def initialize(fields)
            @fields = []
            @fields = fields
          end

          def to_s
            "RECORD #{fields.to_s}"
          end

          def equals(object)
            return true if self == object

            return false if object.nil? || self.class != object.class

            fields == object.fields
          end

          def hash_code
            java.util.Arrays.hash_code(fields)
          end
        end
      end
    end
  end
end

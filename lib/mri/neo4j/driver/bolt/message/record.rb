# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Message
        # Record response from Neo4j server containing result data
        class Record
          attr_reader :fields

          def initialize(fields)
            @fields = fields
          end

          def accept(visitor)
            visitor.on_record(self)
          end

          def assert_success!
            raise Exceptions::ClientException, "Unexpected RECORD where SUCCESS was expected"
          end
        end
      end
    end
  end
end

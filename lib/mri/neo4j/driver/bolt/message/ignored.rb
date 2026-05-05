# frozen_string_literal: true

module Neo4j
  module Driver
    module Bolt
      module Message
        # Ignored response from Neo4j server (previous request was ignored)
        class Ignored
          def initialize(metadata = {})
            @metadata = metadata
          end

          def accept(visitor)
            visitor.on_ignored(self)
          end

          def assert_success!
            raise Exceptions::ClientException,
                  'Server IGNORED the request — a previous request in this batch failed'
          end
        end
      end
    end
  end
end

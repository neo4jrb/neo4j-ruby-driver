module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        # RUN request message
        # <p>
        # Sent by clients to start a new Tank job for a given query and
        # parameter set.
        class RunMessage < Struct.new(:query, :parameters)
          SIGNATURE = 0x10

          def signature
            SIGNATURE
          end

          def to_s
            "RUN \"#{query}\" #{parameters}"
          end
        end
      end
    end
  end
end

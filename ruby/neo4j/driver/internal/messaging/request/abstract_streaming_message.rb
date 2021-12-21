module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class AbstractStreamingMessage
          STREAM_LIMIT_UNLIMITED = -1

          attr_reader :metadata

          def initialize(n, id)
            @metadata = {}
            @metadata['n'] = org.neo4j.driver.Values.value(n)
            @metadata['qid'] = org.neo4j.driver.Values.value(id) unless id == -1
          end

          def equals(object)
            return true if self == object

            return false if object.nil? || self.class != object.class

            java.util.Objects.equals(metadata, object.metadata)
          end

          def hash_code
            java.util.Objects.hash(metadata)
          end

          def to_s
            [name, metadata]
          end
        end
      end
    end
  end
end

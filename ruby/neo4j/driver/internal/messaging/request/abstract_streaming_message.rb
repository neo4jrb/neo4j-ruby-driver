module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class AbstractStreamingMessage < Struct.new(:n, :qid)
          STREAM_LIMIT_UNLIMITED = -1

          def metadata
            to_h.compact
          end

          def to_s
            "#{name} #{metadata}"
          end

          protected

          def name
            raise 'Abstract method called'
          end
        end
      end
    end
  end
end

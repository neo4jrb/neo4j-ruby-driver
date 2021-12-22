module Neo4j::Driver
  module Internal
    module Messaging
      module Request
        class AbstractStreamingMessage < Struct.new(:n, :qid)
          STREAM_LIMIT_UNLIMITED = nil
          alias metadata to_h

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

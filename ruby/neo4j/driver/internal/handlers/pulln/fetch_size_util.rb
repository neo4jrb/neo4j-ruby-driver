module Neo4j::Driver
  module Internal
    module Handlers
      module Pulln
        class FetchSizeUtil
          UNLIMITED_FETCH_SIZE = -1
          DEFAULT_FETCH_SIZE = 1000

          def self.assert_valid_fetch_size(size)
            if size <= 0 && size != UNLIMITED_FETCH_SIZE
              raise ArgumentError, "The record fetch size may not be 0 or negative. Illegal record fetch size: #{size}."
            end

            size
          end
        end
      end
    end
  end
end

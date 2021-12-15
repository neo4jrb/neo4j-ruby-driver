module Neo4j::Driver
  module Internal
    module Util
      class MetadataExtractor
        ABSENT_QUERY_ID = -1

        def initialize(result_available_after_metadata_key, result_consumed_after_metadata_key)
          @result_available_after_metadata_key = result_available_after_metadata_key
          @result_consumed_after_metadata_key = result_consumed_after_metadata_key
        end
      end
    end
  end
end

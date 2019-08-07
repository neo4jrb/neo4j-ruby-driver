# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Util
        class MetadataExtractor
          def initialize(result_available_after_metadata_key, result_consumed_after_metadata_key); end

          def extract_bookmarks(metadata); end
        end
      end
    end
  end
end

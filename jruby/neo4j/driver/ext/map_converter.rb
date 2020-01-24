# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module MapConverter
        def to_hash
          as_map(&:itself).to_hash.transform_values!(&:as_ruby_object).symbolize_keys!
        end
      end
    end
  end
end

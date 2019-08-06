# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class InternalRecord
        attr_reader :values
        delegate :first, to: :values

        def initialize(keys, values)
          @keys = keys
          @values = values
        end

        def [](key)
          field_index = key.is_a?(Integer) ? key : @keys.index(key.to_s)
          @values[field_index] if field_index
        end
      end
    end
  end
end

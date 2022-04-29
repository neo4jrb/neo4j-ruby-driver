# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class InternalRecord
        attr_reader :keys, :values
        delegate :first, :size,to: :values
        delegate :key?, to: :keys

        def initialize(keys, values)
          @keys = keys
          @values = values
        end

        def [](key)
          field_index = key.is_a?(Integer) ? key : index(key)
          @values[field_index] if field_index
        end

        def index(key)
          @keys.index(key.to_sym) || (raise StandardError, "Unknown key: #{key}")
        end

        def to_h
          keys.zip(values).to_h
        end
      end
    end
  end
end

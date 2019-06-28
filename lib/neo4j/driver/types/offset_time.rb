# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class OffsetTime < Time
        class << self
          FIELDS = %i[hour min sec nsec utc_offset].freeze

          def significant_fields
            FIELDS
          end
        end

        delegate(*significant_fields, to: :@time)
      end
    end
  end
end

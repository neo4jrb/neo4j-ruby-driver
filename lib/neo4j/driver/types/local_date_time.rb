# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class LocalDateTime < Time
        class << self
          FIELDS = %i[year month day hour min sec nsec].freeze

          def significant_fields
            FIELDS
          end
        end

        delegate(*significant_fields, to: :@time)
        delegate :to_i, to: :@time
      end
    end
  end
end

# frozen_string_literal: true

require 'neo4j/driver/types/time'

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
      end
    end
  end
end

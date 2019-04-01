# frozen_string_literal: true

require 'neo4j/driver/types/time'

module Neo4j
  module Driver
    module Types
      class LocalTime < Time
        class << self
          FIELDS = %i[hour min sec nsec].freeze

          def significant_fields
            FIELDS
          end
        end

        delegate(*significant_fields, to: :@time)
      end
    end
  end
end

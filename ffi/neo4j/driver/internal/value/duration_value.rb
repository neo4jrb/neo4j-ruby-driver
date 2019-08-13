# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Value
        module DurationValue
          CODE = :E
          extend StructureValue

          class << self
            def to_ruby_value(months, days, seconds, nanoseconds)
              ActiveSupport::Duration.months(months) +
                ActiveSupport::Duration.days(days) +
                ActiveSupport::Duration.seconds(seconds) +
                ActiveSupport::Duration.seconds(nanoseconds * BigDecimal('1e-9'))
            end

            def to_neo_values(object)
              DurationNormalizer.normalize(object)
            end
          end
        end
      end
    end
  end
end

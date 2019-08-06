# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module LocalDateTimeValue
        CODE = :d
        extend StructureValue

        class << self
          def to_ruby_value(epoch_second_utc, nsec)
            Types::LocalDateTime.new(Time.at(epoch_second_utc, nsec, :nsec).utc)
          end

          def to_neo_values(local_date_time)
            [local_date_time.to_i, local_date_time.nsec]
          end
        end
      end
    end
  end
end

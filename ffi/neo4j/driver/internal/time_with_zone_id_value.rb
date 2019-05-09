# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module TimeWithZoneIdValue
        CODE = :f
        extend StructureValue

        class << self
          def to_ruby_value(epoch_second_local, nsec, zone_id_string)
            time = Time.at(epoch_second_local, nsec, :nsec).in_time_zone(TZInfo::Timezone.get(zone_id_string))
            time - time.utc_offset
          end

          def to_neo_values(time)
            [time.to_i + time.utc_offset, time.nsec, time.time_zone.tzinfo.identifier]
          end
        end
      end
    end
  end
end

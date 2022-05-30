module Neo4j::Driver
  module Internal
    module Messaging
      module Common
        module CommonValuePacker
          include CommonValue

          def pack(value)
            case value
            when ActiveSupport::Duration
              pack_duration(value)
            when Types::Point
              pack_point(value)
            when Types::OffsetTime
              pack_time(value)
            when Types::LocalTime
              pack_local_time(value)
            when Types::LocalDateTime
              pack_local_date_time(value)
            when ActiveSupport::TimeWithZone
              pack_date_time_with_zone_id(value)
            when Time, DateTime
              pack_date_time_with_zone_offset(value)
            when Date
              pack_date(value)
            else
              super
            end
          end

          private

          def pack_date(local_date)
            pack_struct_header(DATE_STRUCT_SIZE, DATE)
            pack_integer((local_date - EPOCH).to_i)
          end

          def pack_time(offset_time)
            pack_struct_header(TIME_STRUCT_SIZE, TIME)
            pack_nano_of_day(offset_time)
            pack_utc_offset(offset_time)
          end

          def pack_utc_offset(time)
            pack_integer(time.utc_offset)
          end

          def pack_nano_of_day(local_time)
            pack_integer(((local_time.hour * 60 + local_time.min) * 60 + local_time.sec) * NANO_FACTOR + local_time.nsec)
          end

          def pack_local_time(local_time)
            pack_struct_header(LOCAL_TIME_STRUCT_SIZE, LOCAL_TIME)
            pack_nano_of_day(local_time)
          end

          def pack_local_date_time(local_date_time)
            pack_struct_header(LOCAL_DATE_TIME_STRUCT_SIZE, LOCAL_DATE_TIME)
            pack_integer(local_date_time.to_i)
            pack_integer(local_date_time.nsec)
          end

          def pack_date_time_with_zone_id(time)
            pack_struct_header(DATE_TIME_STRUCT_SIZE, DATE_TIME_WITH_ZONE_ID)
            pack_date_time(time)
            pack_string(time.time_zone.tzinfo.identifier)
          end

          def pack_date_time(time)
            pack_integer(time.to_i + time.utc_offset)
            pack_integer(time.nsec)
          end

          def pack_date_time_with_zone_offset(time)
            pack_struct_header(DATE_TIME_STRUCT_SIZE, DATE_TIME_WITH_ZONE_OFFSET)
            pack_date_time(time)
            pack_utc_offset(time)
          end

          def pack_duration(duration)
            pack_struct_header(DURATION_TIME_STRUCT_SIZE, DURATION)
            DurationNormalizer.normalize(duration).each(&method(:pack_integer))
          end

          def pack_point(point)
            case point.coordinates.size
            when 2
              pack_struct_header(POINT_2D_STRUCT_SIZE, POINT_2D_STRUCT_TYPE)
            when 3
              pack_struct_header(POINT_3D_STRUCT_SIZE, POINT_3D_STRUCT_TYPE)
            else
              raise IOError, "Unknown type: type: #{point.class}, value: #{point.to_s}"
            end
            pack_integer(point.srid.to_i)
            point.coordinates.each(&method(:pack_float))
          end
        end
      end
    end
  end
end

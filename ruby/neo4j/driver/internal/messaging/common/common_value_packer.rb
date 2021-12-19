module Neo4j::Driver
  module Internal
    module Messaging
      module Common
        class CommonValuePacker
           DATE = 'D'
           DATE_STRUCT_SIZE = 1
           TIME = 'T'
           TIME_STRUCT_SIZE = 2
           LOCAL_TIME = 't'
           LOCAL_TIME_STRUCT_SIZE = 1
           LOCAL_DATE_TIME = 'd'
           LOCAL_DATE_TIME_STRUCT_SIZE = 2
           DATE_TIME_WITH_ZONE_OFFSET = 'F'
           DATE_TIME_WITH_ZONE_ID = 'f'
           DATE_TIME_STRUCT_SIZE = 3
           DURATION = 'E'
           DURATION_TIME_STRUCT_SIZE = 4
           POINT_2D_STRUCT_TYPE = 'X'
           POINT_2D_STRUCT_SIZE = 3
           POINT_3D_STRUCT_TYPE = 'Y'
           POINT_3D_STRUCT_SIZE = 4

          attr_reader :packer

          delegate :pack_struct_header, to: :packer

          def initialize(output)
            @packer = Packstream::PackStream::Packer.new(output)
          end

          def pack(value)
            case value
            when String
              packer.pack(value)
            when Value
              if value.instance_of? Value::InternalValue
                pack_internal_value(value)
              else
                raise java.lang.IllegalArgumentException, "Unable to pack: #{value}"
              end
            when Hash
              return packer.pack_map_header(0) if value.nil? || value.empty?

              packer.pack_map_header(value.size)

              value.each do |key, value|
                packer.pack(key)
                pack(value)
              end
            end
          end

          def pack_internal_value(value)
            case value.type_constructor
            when DATE
              pack_date(value.as_local_date)
            when TIME
              pack_time(value.as_offset_time)
            when LOCAL_TIME
              pack_local_time(value.as_local_time)
            when LOCAL_DATE_TIME
              pack_local_date_time(value.as_local_date_time)
            when DATE_TIME
              pack_zoned_date_time(value.as_zoned_date_time)
            when DURATION
              pack_duration(value.as_iso_duration)
            when POINT
              pack_point(value.as_point)
            when NilClass
              packer.pack_null
            when BYTES
              packer.pack(value.as_byte_array)
            when STRING
              packer.pack(value.to_s)
            when BOOLEAN
              packer.pack(value.as_boolean)
            when INTEGER
              packer.pack(value.to_i)
            when FLOAT
              packer.pack(value.to_f)
            when HASH
              packer.pack_map_header(value.size)
              value.keys.each do |key|
                packer.pack(key)
                pack(value[key])
              end
            when Array
              packer.pack_list_header(value.size)
              value.values.each(&:pack)
            else
              raise java.io.IOException, "Unknown type: #{value.type.name}"
            end
          end

          private

          def pack_date(local_date)
            packer.pack_struct_header(DATE_STRUCT_SIZE, DATE)
            packer.pack(local_date.to_epoch_day)
          end

          def pack_time(offset_time)
            nano_of_day_local = offset_time.strf('%Q')
            offset_seconds = offset_time.offset.total_seconds

            packer.pack_struct_header(TIME_STRUCT_SIZE, TIME)
            packer.pack(nano_of_day_local)
            packer.pack(offset_seconds)
          end

          def pack_local_time(local_time)
            packer.pack_struct_header(LOCAL_TIME_STRUCT_SIZE, LOCAL_TIME)
            packer.pack(local_time.strf('%Q'))
          end

          def pack_local_date_time(local_date_time)
            epoch_second_utc = local_date_time.to_epoch_second(UTC)
            nano = local_date_time.to_i * (10 ** 9)

            packer.pack_struct_header(LOCAL_DATE_TIME_STRUCT_SIZE, LOCAL_DATE_TIME)
            packer.pack(epoch_second_utc)
            packer.pack(nano)
          end

          def pack_zoned_date_time(zoned_date_time)
            epoch_second_local = zoned_date_time.to_local_date_time.to_epoch_second(UTC)
            nano = zoned_date_time.to_i * (10 ** 9)

            zone = zoned_date_time.zone

            if zone.instance_of? java.time.ZoneOffset
              offset_seconds = zone.total_seconds

              packer.pack_struct_header(DATE_TIME_STRUCT_SIZE, DATE_TIME_WITH_ZONE_OFFSET)
              packer.pack(epoch_second_local)
              packer.pack(nano)
              packer.pack(offset_seconds)
            else
              zone_id = zone.id

              packer.pack_struct_header(DATE_TIME_STRUCT_SIZE, DATE_TIME_WITH_ZONE_ID)
              packer.pack(epoch_second_local)
              packer.pack(nano)
              packer.pack(zone_id)
            end
          end

          def pack_duration(duration)
            packer.pack_struct_header(DURATION_TIME_STRUCT_SIZE, DURATION)
            packer.pack(duration.months)
            packer.pack(duration.days)
            packer.pack(duration.seconds)
            packer.pack(duration.nanoseconds)
          end

          def pack_point(point)
            case point
            when InternalPoint2D
              pack_point2_d(point)
            when InternalPoint3D
              pack_point3_d(point)
            else
              raise java.io.IOException, "Unknown type: type: #{point.class}, value: #{point.to_s}"
            end
          end

          def pack_point2_d(point)
            packer.pack_struct_header(POINT_2D_STRUCT_SIZE, POINT_2D_STRUCT_TYPE)
            packer.pack(point.srid)
            packer.pack(point.x)
            packer.pack(point.y)
          end

          def pack_point2_d(point)
            packer.pack_struct_header(POINT_3D_STRUCT_SIZE, POINT_3D_STRUCT_TYPE)
            packer.pack(point.srid)
            packer.pack(point.x)
            packer.pack(point.y)
            packer.pack(point.z)
          end
        end
      end
    end
  end
end
